-- PROPOSAL ONLY: additive Main-compatible learning assessment workflow.
-- Do not run against Supabase Main without explicit migration approval.
-- Reuses learning_courses, learning_lessons, learning_exercise_questions,
-- existing course authority helpers, and the existing verified-family helper.
begin;

do $$
begin
  if to_regclass('public.learning_courses') is null
    or to_regclass('public.learning_lessons') is null
    or to_regclass('public.learning_exercise_questions') is null then
    raise exception 'Expected the existing shared learning schema';
  end if;
  if to_regprocedure('private.sai_learning_can_manage_course(uuid)') is null
    or to_regprocedure('private.sai_security_can_read_student(uuid)') is null then
    raise exception 'Expected the existing Main learning/security helper layer';
  end if;
  if to_regclass('public.learning_assessments') is not null then
    raise exception 'public.learning_assessments already exists; review before applying';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='learning_exercise_questions'
      and column_name in ('assessment_id','answer_key')
  ) then
    raise exception 'Assessment question columns already exist; review before applying';
  end if;
end $$;

create table public.learning_assessments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.learning_courses(id) on delete cascade,
  lesson_id uuid not null references public.learning_lessons(id) on delete cascade,
  class_id uuid not null references public.classes(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  title text not null check (length(btrim(title)) between 2 and 200),
  instructions text check (instructions is null or length(instructions) <= 4000),
  due_at timestamptz,
  attempt_limit integer not null default 1 check (attempt_limit between 1 and 10),
  status text not null default 'draft' check (status in ('draft','published')),
  published_at timestamptz,
  results_released boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.learning_exercise_questions
  add column assessment_id uuid references public.learning_assessments(id) on delete cascade,
  add column points numeric(7,2) not null default 1 check (points > 0 and points <= 1000),
  add column answer_key jsonb;
alter table public.learning_exercise_questions alter column correct_choice drop not null;
alter table public.learning_exercise_questions
  drop constraint if exists learning_exercise_questions_kind_check,
  drop constraint if exists learning_exercise_questions_check;
alter table public.learning_exercise_questions
  add constraint learning_exercise_questions_kind_check
    check (kind in ('vocabulary','listening','multiple_choice','true_false','matching','fill_blank','written')),
  add constraint learning_exercise_questions_assessment_shape_check
    check (
      (assessment_id is null
        and kind in ('vocabulary','listening')
        and correct_choice is not null
        and jsonb_typeof(choices) = 'array'
        and jsonb_array_length(choices) between 2 and 6)
      or
      (assessment_id is not null
        and kind in ('multiple_choice','true_false','matching','fill_blank','written'))
    );

create table public.learning_assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.learning_assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  attempt_number integer not null check (attempt_number between 1 and 10),
  status text not null default 'in_progress' check (status in ('in_progress','submitted','graded')),
  score numeric(9,2),
  max_score numeric(9,2) not null check (max_score > 0),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  graded_at timestamptz,
  unique (assessment_id, student_id, attempt_number)
);

create table public.learning_assessment_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.learning_assessment_attempts(id) on delete cascade,
  question_id uuid not null references public.learning_exercise_questions(id) on delete cascade,
  answer jsonb,
  is_correct boolean,
  points_awarded numeric(9,2) not null default 0 check (points_awarded >= 0),
  is_graded boolean not null default false,
  feedback text check (feedback is null or length(feedback) <= 2000),
  graded_by uuid references auth.users(id),
  graded_at timestamptz,
  unique (attempt_id, question_id)
);

alter table public.learning_homework
  add column if not exists attachment_path text,
  add column if not exists attachment_file_name text;
alter table public.learning_homework_submissions
  add column if not exists submission_path text,
  add column if not exists submission_file_name text,
  add column if not exists submission_mime_type text;

create function private.sai_learning_homework_submission_guard()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_homework public.learning_homework%rowtype;
  v_student public.students%rowtype;
  v_manager boolean;
begin
  select h.* into v_homework from public.learning_homework h where h.id = new.homework_id;
  if v_homework.id is null then
    raise exception 'Homework does not exist' using errcode = '23503';
  end if;
  v_manager := private.sai_learning_can_manage_course(v_homework.course_id);
  if not v_manager then
    select s.* into v_student from public.students s
      where s.id = new.student_id and s.user_id = (select auth.uid()) and s.status = 'active';
    if v_student.id is null
      or not v_homework.is_published
      or v_homework.due_at < now()
      or new.status <> 'submitted'
      or new.score is not null or new.feedback is not null
      or new.graded_at is not null or new.graded_by is not null
      or (tg_op = 'UPDATE' and (
        new.homework_id is distinct from old.homework_id
        or new.student_id is distinct from old.student_id
        or new.submitted_at is distinct from old.submitted_at
        or old.status not in ('submitted','returned')
      )) then
      raise exception 'Student submission fields are restricted to its own editable response'
        using errcode = '42501';
    end if;
    new.submitted_at := now();
    if new.submission_path is not null and
      new.submission_path !~ ('^' || new.homework_id::text || '/submissions/' || new.student_id::text || '/[^/]+$') then
      raise exception 'Submission file path does not match the student and homework'
        using errcode = '23514';
    end if;
    if (new.submission_path is null) <> (new.submission_file_name is null) then
      raise exception 'Submission file path and name must be supplied together'
        using errcode = '23514';
    end if;
    if (new.content is null or length(btrim(new.content)) = 0)
      and new.submission_path is null then
      raise exception 'Submit text or a file' using errcode = '23514';
    end if;
  else
    if tg_op = 'INSERT' and new.status <> 'submitted' then
      raise exception 'Homework must be submitted before teacher review'
        using errcode = '23514';
    end if;
    if not exists (select 1 from public.learning_courses c
      join public.students s on s.class_id = c.class_id
      where c.id = v_homework.course_id and s.id = new.student_id) then
      raise exception 'Student is outside this homework course' using errcode = '23514';
    end if;
    if new.score is not null and (new.score < 0 or new.score > v_homework.max_score) then
      raise exception 'Grade exceeds the homework score range' using errcode = '23514';
    end if;
    if tg_op = 'UPDATE' and new.status in ('graded','returned')
      and (new.status is distinct from old.status
        or new.score is distinct from old.score
        or new.feedback is distinct from old.feedback) then
      if (select auth.uid()) is null then
        raise exception 'An authenticated teacher must review this submission'
          using errcode = '42501';
      end if;
      new.graded_by := (select auth.uid());
      new.graded_at := now();
    end if;
    if new.status = 'graded' and (new.score is null or new.graded_by is null or new.graded_at is null) then
      raise exception 'Graded submissions require a server-validated grade and reviewer'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger learning_homework_submission_guard
  before insert or update on public.learning_homework_submissions
  for each row execute function private.sai_learning_homework_submission_guard();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('homework-files', 'homework-files', false, 20971520,
  array['application/pdf','text/plain','application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'image/png','image/jpeg'])
on conflict (id) do update
  set public = false,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists homework_files_read on storage.objects;
create policy homework_files_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'homework-files'
    and (
      exists (
        select 1 from public.learning_homework h
        join public.learning_courses c on c.id = h.course_id
        where h.id::text = (storage.foldername(name))[1]
          and (storage.foldername(name))[2] = 'instructions'
          and h.attachment_path = name
          and (private.sai_learning_can_manage_course(c.id)
            or (h.is_published and private.sai_learning_can_read_course(c.id)))
      )
      or exists (
        select 1 from public.learning_homework_submissions s
        join public.learning_homework h on h.id = s.homework_id
        join public.learning_courses c on c.id = h.course_id
        where s.submission_path = name
          and (private.sai_learning_can_manage_course(c.id)
            or private.sai_security_can_read_student(s.student_id))
      )
    )
  );

drop policy if exists homework_files_insert on storage.objects;
create policy homework_files_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'homework-files'
    and (
      (
        (storage.foldername(name))[2] = 'instructions'
        and exists (
          select 1 from public.learning_homework h
          where h.id::text = (storage.foldername(name))[1]
            and private.sai_learning_can_manage_course(h.course_id)
        )
      )
      or
      (
        (storage.foldername(name))[2] = 'submissions'
        and exists (
          select 1 from public.learning_homework h
          join public.learning_courses c on c.id = h.course_id
          join public.students s on s.id::text = (storage.foldername(name))[3]
          where h.id::text = (storage.foldername(name))[1]
            and s.user_id = (select auth.uid())
            and h.is_published and h.due_at >= now()
            and private.sai_security_can_read_class(c.class_id)
        )
      )
    )
  );

drop policy if exists homework_files_update on storage.objects;
create policy homework_files_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'homework-files'
    and (
      ((storage.foldername(name))[2] = 'instructions'
        and exists (select 1 from public.learning_homework h
          where h.id::text = (storage.foldername(name))[1]
            and private.sai_learning_can_manage_course(h.course_id)))
      or
      ((storage.foldername(name))[2] = 'submissions'
        and exists (select 1 from public.learning_homework_submissions s
          join public.learning_homework h on h.id = s.homework_id
          where s.submission_path = name and s.status = 'submitted'
            and h.due_at >= now()
            and private.sai_learning_own_student(s.student_id)))
    )
  )
  with check (
    bucket_id = 'homework-files'
    and (
      ((storage.foldername(name))[2] = 'instructions'
        and exists (select 1 from public.learning_homework h
          where h.id::text = (storage.foldername(name))[1]
            and private.sai_learning_can_manage_course(h.course_id)))
      or
      ((storage.foldername(name))[2] = 'submissions'
        and exists (select 1 from public.learning_homework_submissions s
          join public.learning_homework h on h.id = s.homework_id
          where s.submission_path = name and s.status = 'submitted'
            and h.due_at >= now()
            and private.sai_learning_own_student(s.student_id)))
    )
  );

drop policy if exists homework_files_delete on storage.objects;
create policy homework_files_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'homework-files'
    and (exists (select 1 from public.learning_homework h
      where h.id::text = (storage.foldername(name))[1]
        and private.sai_learning_can_manage_course(h.course_id))
      or exists (select 1 from public.learning_homework_submissions s
        join public.learning_homework h on h.id = s.homework_id
        where s.submission_path = name and s.status = 'submitted'
          and h.due_at >= now()
          and private.sai_learning_own_student(s.student_id)))
  );

revoke all on function private.sai_learning_homework_submission_guard()
  from public, anon, authenticated;

create index learning_assessments_course_idx
  on public.learning_assessments(course_id, status, due_at);
create index learning_assessments_lesson_idx
  on public.learning_assessments(lesson_id, status, created_at desc);
create index learning_assessment_attempts_student_idx
  on public.learning_assessment_attempts(student_id, assessment_id, started_at desc);
create index learning_assessment_answers_attempt_idx
  on public.learning_assessment_answers(attempt_id, question_id);

alter table public.learning_assessments enable row level security;
alter table public.learning_assessment_attempts enable row level security;
alter table public.learning_assessment_answers enable row level security;

revoke all on public.learning_assessments, public.learning_assessment_attempts,
  public.learning_assessment_answers, public.learning_exercise_questions
  from public, anon, authenticated;
grant select on public.learning_assessments to authenticated;
grant insert (id, course_id, lesson_id, title, instructions, due_at, attempt_limit)
  on public.learning_assessments to authenticated;
grant update (title, instructions, due_at, attempt_limit, status, results_released)
  on public.learning_assessments to authenticated;
grant select (id, lesson_id, vocabulary_id, kind, prompt, choices, position,
  is_published, created_at, assessment_id, points)
  on public.learning_exercise_questions to authenticated;
grant insert (id, lesson_id, vocabulary_id, kind, prompt, choices, correct_choice,
  position, is_published, assessment_id, points, answer_key)
  on public.learning_exercise_questions to authenticated;
grant update (vocabulary_id, kind, prompt, choices, correct_choice, position,
  is_published, assessment_id, points, answer_key)
  on public.learning_exercise_questions to authenticated;
grant delete on public.learning_exercise_questions to authenticated;
grant select on public.learning_assessment_attempts,
  public.learning_assessment_answers to authenticated;

create or replace function private.sai_learning_assessment_manage(wanted_assessment uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.learning_assessments a
    where a.id = wanted_assessment
      and private.sai_learning_can_manage_course(a.course_id)
  );
$$;

create or replace function private.sai_learning_assessment_read(wanted_assessment uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.learning_assessments a
    where a.id = wanted_assessment
      and a.status = 'published'
        and (
          private.sai_security_can_read_student(
            (select s.id from public.students s
              where s.class_id = a.class_id and s.user_id = (select auth.uid()) limit 1)
          )
          or private.sai_security_can_read_student(
            (select s.id from public.students s
              join public.parent_student_links l on l.student_id = s.id
              where s.class_id = a.class_id and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null limit 1)
          )
        )
  );
$$;

revoke all on function private.sai_learning_assessment_manage(uuid),
  private.sai_learning_assessment_read(uuid) from public, anon;
grant execute on function private.sai_learning_assessment_manage(uuid),
  private.sai_learning_assessment_read(uuid) to authenticated;

create policy learning_assessments_select on public.learning_assessments
  for select to authenticated
  using (
    private.sai_learning_can_manage_course(course_id)
    or (status = 'published' and private.sai_security_can_read_student(
      (select s.id from public.students s
        where s.class_id = learning_assessments.class_id and s.user_id = (select auth.uid()) limit 1)
    ))
    or (status = 'published' and private.sai_security_can_read_student(
      (select s.id from public.students s
        join public.parent_student_links l on l.student_id = s.id
        where s.class_id = learning_assessments.class_id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null limit 1)
    ))
  );

create policy learning_assessments_write on public.learning_assessments
  for all to authenticated
  using (private.sai_learning_can_manage_course(course_id))
  with check (private.sai_learning_can_manage_course(course_id));

drop policy if exists learning_exercise_questions_select on public.learning_exercise_questions;
create policy learning_exercise_questions_select on public.learning_exercise_questions
  for select to authenticated
  using (
    private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id))
    or (
      assessment_id is null and is_published and exists (
        select 1 from public.learning_lessons l
        join public.learning_courses c on c.id = l.course_id
        join public.students s on s.class_id = c.class_id and s.user_id = (select auth.uid())
        where l.id = lesson_id and l.is_published
      )
    )
    or (
      assessment_id is not null and is_published
      and private.sai_learning_assessment_read(assessment_id)
    )
  );

drop policy if exists learning_exercise_questions_write on public.learning_exercise_questions;
create policy learning_exercise_questions_write on public.learning_exercise_questions
  for all to authenticated
  using (
    private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id))
  )
  with check (
    private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id))
  );

create policy learning_assessment_attempts_results on public.learning_assessment_attempts
  for select to authenticated
  using (
    private.sai_learning_assessment_manage(assessment_id)
    or (private.sai_learning_assessment_read(assessment_id)
      and exists (select 1 from public.learning_assessments x
        where x.id = assessment_id and x.results_released)
      and private.sai_security_can_read_student(student_id))
  );

create policy learning_assessment_answers_results on public.learning_assessment_answers
  for select to authenticated
  using (
    exists (
      select 1 from public.learning_assessment_attempts a
      where a.id = attempt_id
        and (
          private.sai_learning_assessment_manage(a.assessment_id)
          or (private.sai_learning_assessment_read(a.assessment_id)
            and private.sai_security_can_read_student(a.student_id)
            and exists (select 1 from public.learning_assessments x
              where x.id = a.assessment_id and x.results_released))
        )
    )
  );

create function private.sai_learning_assessment_guard()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_course public.learning_courses%rowtype;
  v_lesson_course uuid;
begin
  select c.* into v_course from public.learning_courses c where c.id = new.course_id;
  select l.course_id into v_lesson_course from public.learning_lessons l where l.id = new.lesson_id;
  if v_course.id is null or v_lesson_course is distinct from new.course_id then
    raise exception 'Assessment lesson must belong to its selected course' using errcode = '23514';
  end if;
  new.class_id := v_course.class_id;
  new.academic_session_id := v_course.session_id;
  new.updated_at := now();
  if tg_op = 'UPDATE' and new.status = 'published' and old.status <> 'published' then
    new.published_at := now();
  elsif new.status = 'draft' then
    new.published_at := null;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published'
    and exists (select 1 from public.learning_assessment_attempts a where a.assessment_id = old.id)
    and (new.course_id, new.lesson_id, new.title, new.instructions, new.due_at, new.attempt_limit)
      is distinct from
      (old.course_id, old.lesson_id, old.title, old.instructions, old.due_at, old.attempt_limit) then
    raise exception 'Published assessment with attempts cannot be edited' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and old.status = 'published'
    and new.status <> 'published'
    and exists (select 1 from public.learning_assessment_attempts a where a.assessment_id = old.id) then
    raise exception 'Published assessment with attempts cannot be unpublished' using errcode = '23514';
  end if;
  if new.status = 'published' and tg_op = 'UPDATE' and old.status <> 'published'
    and not exists (select 1 from public.learning_exercise_questions q
      where q.assessment_id = new.id) then
    raise exception 'An assessment needs at least one question before publication' using errcode = '23514';
  end if;
  if new.status = 'published' and not exists (
    select 1 from public.learning_lessons l where l.id = new.lesson_id and l.is_published
  ) then
    raise exception 'Publish the lesson before publishing its assessment' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger learning_assessments_guard
  before insert or update on public.learning_assessments
  for each row execute function private.sai_learning_assessment_guard();

create function private.sai_learning_assessment_questions_sync()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
begin
  if tg_op = 'UPDATE' and old.assessment_id is not null
    and exists (select 1 from public.learning_assessment_attempts a where a.assessment_id = old.assessment_id) then
    raise exception 'Assessment questions cannot be edited after attempts begin' using errcode = '23514';
  end if;
  if new.assessment_id is not null then
    if not exists (select 1 from public.learning_assessments a
      where a.id = new.assessment_id and a.lesson_id = new.lesson_id) then
      raise exception 'Question must belong to the assessment lesson' using errcode = '23514';
    end if;
    if jsonb_typeof(new.choices) is distinct from 'array' then
      raise exception 'Question options must be a JSON array' using errcode = '23514';
    end if;
    new.is_published := exists (select 1 from public.learning_assessments a
      where a.id = new.assessment_id and a.status = 'published');
    if new.kind in ('multiple_choice','true_false') then
      if jsonb_typeof(new.choices) <> 'array'
        or jsonb_array_length(new.choices) < 2 or jsonb_array_length(new.choices) > 6
        or new.correct_choice is null or new.correct_choice < 0
        or new.correct_choice >= jsonb_array_length(new.choices)
        or new.answer_key is not null then
        raise exception 'Choice question answer is invalid' using errcode = '23514';
      end if;
      if new.kind = 'true_false' and jsonb_array_length(new.choices) <> 2 then
        raise exception 'True/false questions need exactly two options' using errcode = '23514';
      end if;
    elsif new.kind = 'matching' then
      if jsonb_typeof(new.answer_key) is distinct from 'object' then
        raise exception 'Matching question needs a matching key' using errcode = '23514';
      end if;
      if jsonb_array_length(new.choices) < 4
        or jsonb_array_length(new.choices) > 12
        or jsonb_array_length(new.choices) % 2 <> 0
        or new.correct_choice is not null
        or (select count(*) from jsonb_object_keys(new.answer_key)) <> jsonb_array_length(new.choices) / 2
        or exists (
          select 1 from jsonb_each_text(new.answer_key) pair
          where not exists (
              select 1 from generate_series(0, jsonb_array_length(new.choices) / 2 - 1) i
              where new.choices ->> i = pair.key
            )
            or not exists (
              select 1 from generate_series(jsonb_array_length(new.choices) / 2,
                jsonb_array_length(new.choices) - 1) i
              where new.choices ->> i = pair.value
            )
        ) then
        raise exception 'Matching question needs pairs and a matching key' using errcode = '23514';
      end if;
    elsif new.kind = 'fill_blank' then
      if jsonb_typeof(new.answer_key) is distinct from 'array'
        or new.correct_choice is not null or jsonb_array_length(new.answer_key) = 0 then
        raise exception 'Fill-in question needs an accepted answer' using errcode = '23514';
      end if;
      if exists (select 1 from jsonb_array_elements(new.answer_key) accepted
        where jsonb_typeof(accepted) <> 'string'
          or length(btrim(accepted #>> '{}')) = 0
          or length(accepted #>> '{}') > 300) then
        raise exception 'Fill-in answers must be short text values' using errcode = '23514';
      end if;
    elsif new.kind = 'written' then
      if new.correct_choice is not null or new.answer_key is not null then
        raise exception 'Written questions cannot contain a correct answer key' using errcode = '23514';
      end if;
    end if;
    if exists (
      select 1 from jsonb_array_elements(new.choices) choice
      where jsonb_typeof(choice) <> 'string'
        or length(btrim(choice #>> '{}')) = 0 or length(choice #>> '{}') > 300
    ) then
      raise exception 'Question options must be short text values' using errcode = '23514';
    end if;
    if jsonb_array_length(new.choices) > 0
      and (select count(*) from jsonb_array_elements_text(new.choices))
        <> (select count(distinct value) from jsonb_array_elements_text(new.choices) value) then
      raise exception 'Duplicate question options are not allowed' using errcode = '23514';
    end if;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger learning_assessment_questions_sync
  before insert or update on public.learning_exercise_questions
  for each row execute function private.sai_learning_assessment_questions_sync();

create function private.sai_learning_assessment_publish_questions()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if new.status is distinct from old.status then
    update public.learning_exercise_questions
      set is_published = (new.status = 'published')
      where assessment_id = new.id;
  end if;
  return new;
end;
$$;

create trigger learning_assessments_publish_questions
  after update of status on public.learning_assessments
  for each row execute function private.sai_learning_assessment_publish_questions();

create function private.sai_learning_assessment_recalculate(wanted_attempt uuid)
returns void language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  update public.learning_assessment_attempts a
    set score = coalesce((select sum(x.points_awarded)
        from public.learning_assessment_answers x where x.attempt_id = a.id), 0),
        status = case when exists (
          select 1 from public.learning_assessment_answers x
          where x.attempt_id = a.id and not x.is_graded
        ) then 'submitted' else 'graded' end,
        graded_at = case when not exists (
          select 1 from public.learning_assessment_answers x
          where x.attempt_id = a.id and not x.is_graded
        ) then now() else null end
    where a.id = wanted_attempt and a.status <> 'in_progress';
end;
$$;

create function public.sai_learning_assessment_start(p_assessment uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_assessment public.learning_assessments%rowtype;
  v_student uuid;
  v_attempt public.learning_assessment_attempts%rowtype;
  v_next integer;
begin
  if (select auth.uid()) is null
    or not private.sai_security_has_role('student') then
    raise exception 'Student authentication required' using errcode = '42501';
  end if;
  select s.id into v_student from public.students s
    where s.user_id = (select auth.uid()) and s.status = 'active';
  if v_student is null then
    raise exception 'No active student record for this account' using errcode = '42501';
  end if;
  select a.* into v_assessment from public.learning_assessments a
    where a.id = p_assessment and a.status = 'published'
      and exists (select 1 from public.learning_courses c
        where c.id = a.course_id and c.class_id = (select class_id from public.students where id = v_student))
    for update;
  if v_assessment.id is null then
    raise exception 'Assessment is not available to this student' using errcode = '42501';
  end if;
  select a.* into v_attempt from public.learning_assessment_attempts a
    where a.assessment_id = p_assessment and a.student_id = v_student
      and a.status = 'in_progress'
    order by a.attempt_number desc limit 1;
  if v_attempt.id is null then
    if v_assessment.due_at is not null and now() > v_assessment.due_at then
      raise exception 'Assessment deadline has passed' using errcode = 'P0001';
    end if;
    select coalesce(max(a.attempt_number), 0) + 1 into v_next
      from public.learning_assessment_attempts a
      where a.assessment_id = p_assessment and a.student_id = v_student;
    if v_next > v_assessment.attempt_limit then
      raise exception 'No attempts remain for this assessment' using errcode = 'P0001';
    end if;
    insert into public.learning_assessment_attempts
      (assessment_id, student_id, attempt_number, max_score)
    select p_assessment, v_student, v_next, sum(q.points)
      from public.learning_exercise_questions q
      where q.assessment_id = p_assessment and q.is_published
    returning * into v_attempt;
  end if;
  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_number', v_attempt.attempt_number,
    'due_at', v_assessment.due_at,
    'questions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', q.id, 'kind', q.kind, 'prompt', q.prompt,
        'choices', q.choices, 'points', q.points, 'position', q.position
      ) order by q.position, q.id)
      from public.learning_exercise_questions q
      where q.assessment_id = p_assessment and q.is_published
    ), '[]'::jsonb),
    'saved_answers', coalesce((
      select jsonb_object_agg(x.question_id::text, x.answer)
      from public.learning_assessment_answers x where x.attempt_id = v_attempt.id
    ), '{}'::jsonb)
  );
end;
$$;

create function public.sai_learning_assessment_save(p_attempt uuid, p_question uuid, p_answer jsonb)
returns void language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_attempt public.learning_assessment_attempts%rowtype;
  v_question public.learning_exercise_questions%rowtype;
begin
  select a.* into v_attempt from public.learning_assessment_attempts a
    join public.students s on s.id = a.student_id
    where a.id = p_attempt and s.user_id = (select auth.uid())
      and a.status = 'in_progress' for update of a;
  if v_attempt.id is null then
    raise exception 'Attempt is not editable by this account' using errcode = '42501';
  end if;
  if exists (select 1 from public.learning_assessments x
    where x.id = v_attempt.assessment_id and x.due_at is not null
      and now() > x.due_at) then
    raise exception 'Assessment deadline has passed' using errcode = 'P0001';
  end if;
  select q.* into v_question from public.learning_exercise_questions q
    where q.id = p_question and q.assessment_id = v_attempt.assessment_id
      and q.is_published;
  if v_question.id is null or p_answer is null then
    raise exception 'Invalid assessment answer' using errcode = '23514';
  end if;
  if v_question.kind in ('multiple_choice','true_false')
    and (jsonb_typeof(p_answer) <> 'number'
      or (p_answer #>> '{}') !~ '^\d+$'
      or (p_answer #>> '{}')::integer >= jsonb_array_length(v_question.choices)) then
    raise exception 'Select a valid option' using errcode = '23514';
  elsif v_question.kind = 'matching' and jsonb_typeof(p_answer) <> 'object' then
    raise exception 'Matching answer must contain pairs' using errcode = '23514';
  elsif v_question.kind in ('fill_blank','written')
    and (jsonb_typeof(p_answer) <> 'string' or length(btrim(p_answer #>> '{}')) > 5000) then
    raise exception 'Text answer is invalid' using errcode = '23514';
  end if;
  insert into public.learning_assessment_answers (attempt_id, question_id, answer)
    values (v_attempt.id, v_question.id, p_answer)
    on conflict (attempt_id, question_id) do update
      set answer = excluded.answer, is_correct = null, points_awarded = 0,
          is_graded = false, feedback = null, graded_by = null, graded_at = null;
end;
$$;

create function public.sai_learning_assessment_submit(p_attempt uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_attempt public.learning_assessment_attempts%rowtype;
  v_question public.learning_exercise_questions%rowtype;
  v_answer jsonb;
  v_correct boolean;
  v_points numeric(9,2);
  v_manual integer := 0;
begin
  select a.* into v_attempt from public.learning_assessment_attempts a
    join public.students s on s.id = a.student_id
    where a.id = p_attempt and s.user_id = (select auth.uid())
      and a.status = 'in_progress' for update of a;
  if v_attempt.id is null then
    raise exception 'Attempt cannot be submitted by this account' using errcode = '42501';
  end if;
  if exists (select 1 from public.learning_assessments x
    where x.id = v_attempt.assessment_id and x.due_at is not null
      and now() > x.due_at) then
    raise exception 'Assessment deadline has passed' using errcode = 'P0001';
  end if;
  for v_question in
    select q.* from public.learning_exercise_questions q
    where q.assessment_id = v_attempt.assessment_id and q.is_published
    order by q.position, q.id
  loop
    select a.answer into v_answer from public.learning_assessment_answers a
      where a.attempt_id = v_attempt.id and a.question_id = v_question.id;
    v_correct := false;
    v_points := 0;
    if v_question.kind in ('multiple_choice','true_false') then
      v_correct := v_answer is not null
        and (v_answer #>> '{}')::integer = v_question.correct_choice;
      v_points := case when v_correct then v_question.points else 0 end;
      insert into public.learning_assessment_answers
        (attempt_id, question_id, answer, is_correct, points_awarded, is_graded)
      values (v_attempt.id, v_question.id, v_answer, v_correct, v_points, true)
      on conflict (attempt_id, question_id) do update
        set is_correct = excluded.is_correct, points_awarded = excluded.points_awarded,
            is_graded = true, feedback = null, graded_by = null, graded_at = null;
    elsif v_question.kind = 'matching' then
      v_correct := v_answer is not null and v_answer = v_question.answer_key;
      v_points := case when v_correct then v_question.points else 0 end;
      insert into public.learning_assessment_answers
        (attempt_id, question_id, answer, is_correct, points_awarded, is_graded)
      values (v_attempt.id, v_question.id, v_answer, v_correct, v_points, true)
      on conflict (attempt_id, question_id) do update
        set is_correct = excluded.is_correct, points_awarded = excluded.points_awarded,
            is_graded = true, feedback = null, graded_by = null, graded_at = null;
    elsif v_question.kind = 'fill_blank' then
      v_correct := v_answer is not null and exists (
        select 1 from jsonb_array_elements_text(v_question.answer_key) accepted
        where lower(btrim(accepted)) = lower(btrim(v_answer #>> '{}'))
      );
      v_points := case when v_correct then v_question.points else 0 end;
      insert into public.learning_assessment_answers
        (attempt_id, question_id, answer, is_correct, points_awarded, is_graded)
      values (v_attempt.id, v_question.id, v_answer, v_correct, v_points, true)
      on conflict (attempt_id, question_id) do update
        set is_correct = excluded.is_correct, points_awarded = excluded.points_awarded,
            is_graded = true, feedback = null, graded_by = null, graded_at = null;
    else
      insert into public.learning_assessment_answers
        (attempt_id, question_id, answer, is_correct, points_awarded, is_graded)
      values (v_attempt.id, v_question.id, v_answer, null, 0,
        (v_answer is null or length(btrim(v_answer #>> '{}')) = 0))
      on conflict (attempt_id, question_id) do update
        set answer = excluded.answer, is_correct = null, points_awarded = 0,
            is_graded = excluded.is_graded, feedback = null, graded_by = null, graded_at = null;
      if v_answer is not null and length(btrim(v_answer #>> '{}')) > 0 then
        v_manual := v_manual + 1;
      end if;
    end if;
  end loop;
  update public.learning_assessment_attempts
    set status = 'submitted', submitted_at = now()
    where id = v_attempt.id;
  perform private.sai_learning_assessment_recalculate(v_attempt.id);
  return jsonb_build_object(
    'status', (select a.status from public.learning_assessment_attempts a where a.id = v_attempt.id),
    'needs_manual_grading', v_manual,
    'message', case when v_manual > 0 then 'تم التسليم وينتظر تصحيح الإجابات الكتابية.'
      else 'تم التسليم والتصحيح الآلي.' end
  );
end;
$$;

create function public.sai_learning_assessment_grade(
  p_answer uuid, p_points numeric, p_feedback text default null
)
returns void language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_assessment uuid;
  v_max numeric(7,2);
begin
  select a.assessment_id, q.points into v_assessment, v_max
    from public.learning_assessment_answers x
    join public.learning_assessment_attempts a on a.id = x.attempt_id
    join public.learning_exercise_questions q on q.id = x.question_id
    where x.id = p_answer and q.kind = 'written' and a.status = 'submitted'
    for update of x, a;
  if v_assessment is null
    or not private.sai_learning_assessment_manage(v_assessment) then
    raise exception 'Written answer is not available for grading' using errcode = '42501';
  end if;
  if p_points is null or p_points < 0 or p_points > v_max
    or (p_feedback is not null and length(p_feedback) > 2000) then
    raise exception 'Grade or feedback is outside allowed limits' using errcode = '23514';
  end if;
  update public.learning_assessment_answers
    set points_awarded = p_points, is_graded = true, feedback = p_feedback,
        graded_by = (select auth.uid()), graded_at = now()
    where id = p_answer;
  perform private.sai_learning_assessment_recalculate(
    (select x.attempt_id from public.learning_assessment_answers x where x.id = p_answer)
  );
end;
$$;

create or replace function public.sai_learning_assessment_questions_admin(p_assessment uuid)
returns table (
  id uuid, lesson_id uuid, kind text, prompt text, choices jsonb,
  correct_choice integer, answer_key jsonb, points numeric,
  "position" integer, is_published boolean
)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select q.id, q.lesson_id, q.kind, q.prompt, q.choices, q.correct_choice,
    q.answer_key, q.points, q.position, q.is_published
  from public.learning_exercise_questions q
  where q.assessment_id = p_assessment
    and private.sai_learning_assessment_manage(p_assessment)
  order by q.position, q.id;
$$;

-- A dedicated read RPC returns no key and only exposes a result after release.
create function public.sai_learning_assessment_results(p_assessment uuid)
returns table (
  attempt_id uuid, student_id uuid, attempt_number integer, status text,
  score numeric, max_score numeric, submitted_at timestamptz,
  answer_id uuid, question_id uuid, answer jsonb, is_correct boolean,
  points_awarded numeric, feedback text, prompt text, kind text
)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select a.id, a.student_id, a.attempt_number, a.status, a.score, a.max_score,
    a.submitted_at, x.id, x.question_id, x.answer, x.is_correct,
    x.points_awarded, x.feedback, q.prompt, q.kind
  from public.learning_assessment_attempts a
  join public.learning_assessments s on s.id = a.assessment_id
  left join public.learning_assessment_answers x on x.attempt_id = a.id
  left join public.learning_exercise_questions q on q.id = x.question_id
  where a.assessment_id = p_assessment
    and (private.sai_learning_assessment_manage(s.id)
      or (s.results_released and private.sai_security_can_read_student(a.student_id)))
  order by a.attempt_number desc, a.started_at desc, q.position, q.id;
$$;

revoke all on function private.sai_learning_assessment_guard(),
  private.sai_learning_assessment_questions_sync(),
  private.sai_learning_assessment_publish_questions(),
  private.sai_learning_assessment_recalculate(uuid) from public, anon, authenticated;
revoke all on function public.sai_learning_assessment_start(uuid),
  public.sai_learning_assessment_save(uuid, uuid, jsonb),
  public.sai_learning_assessment_submit(uuid),
  public.sai_learning_assessment_grade(uuid, numeric, text),
  public.sai_learning_assessment_questions_admin(uuid),
  public.sai_learning_assessment_results(uuid) from public, anon, authenticated;
grant execute on function public.sai_learning_assessment_start(uuid),
  public.sai_learning_assessment_save(uuid, uuid, jsonb),
  public.sai_learning_assessment_submit(uuid),
  public.sai_learning_assessment_grade(uuid, numeric, text),
  public.sai_learning_assessment_questions_admin(uuid),
  public.sai_learning_assessment_results(uuid) to authenticated;

commit;
