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
  starts_at timestamptz,
  due_at timestamptz,
  time_limit_minutes integer check (time_limit_minutes is null or time_limit_minutes between 1 and 300),
  attempt_limit integer not null default 1 check (attempt_limit between 1 and 10),
  passing_score numeric(5,2) not null default 70 check (passing_score between 0 and 100),
  randomize_questions boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','closed','archived')),
  published_at timestamptz,
  results_released boolean not null default false,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.learning_exercise_questions
  add column assessment_id uuid references public.learning_assessments(id) on delete cascade,
  add column points numeric(7,2) not null default 1 check (points > 0 and points <= 1000),
  add column answer_key jsonb,
  add column bank_category text
    check (bank_category is null or length(btrim(bank_category)) between 1 and 80);
alter table public.learning_exercise_questions alter column correct_choice drop not null;
alter table public.learning_exercise_questions
  drop constraint if exists learning_exercise_questions_kind_check,
  drop constraint if exists learning_exercise_questions_check;
alter table public.learning_exercise_questions
  add constraint learning_exercise_questions_kind_check
    check (kind in ('vocabulary','listening','multiple_choice','multiple_select',
      'ordering','true_false','matching','fill_blank','written')),
  add constraint learning_exercise_questions_assessment_shape_check
    check (
      (assessment_id is null
        and bank_category is null
        and kind in ('vocabulary','listening')
        and correct_choice is not null
        and jsonb_typeof(choices) = 'array'
        and jsonb_array_length(choices) between 2 and 6)
      or
      (assessment_id is null
        and bank_category is not null
        and kind in ('multiple_choice','multiple_select','ordering','true_false','matching','fill_blank','written'))
      or
      (assessment_id is not null
        and kind in ('multiple_choice','multiple_select','ordering','true_false','matching','fill_blank','written'))
    );

create table public.learning_assessment_attempts (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.learning_assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  attempt_number integer not null check (attempt_number between 1 and 10),
  status text not null default 'in_progress' check (status in ('in_progress','submitted','graded')),
  score numeric(9,2),
  max_score numeric(9,2) not null check (max_score > 0),
  question_order uuid[] not null default '{}'::uuid[],
  started_at timestamptz not null default now(),
  expires_at timestamptz,
  submitted_at timestamptz,
  graded_at timestamptz,
  unique (assessment_id, student_id, attempt_number)
);

create table public.learning_assessment_assignments (
  assessment_id uuid not null references public.learning_assessments(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  assigned_by uuid not null default auth.uid() references auth.users(id),
  assigned_at timestamptz not null default now(),
  primary key (assessment_id, student_id)
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
create index learning_assessment_assignments_student_idx
  on public.learning_assessment_assignments(student_id, assessment_id);
create index learning_assessment_attempts_student_idx
  on public.learning_assessment_attempts(student_id, assessment_id, started_at desc);
create index learning_assessment_answers_attempt_idx
  on public.learning_assessment_answers(attempt_id, question_id);

alter table public.learning_assessments enable row level security;
alter table public.learning_assessment_attempts enable row level security;
alter table public.learning_assessment_answers enable row level security;
alter table public.learning_assessment_assignments enable row level security;

revoke all on public.learning_assessments, public.learning_assessment_attempts,
  public.learning_assessment_answers, public.learning_assessment_assignments,
  public.learning_exercise_questions
  from public, anon, authenticated;
grant select on public.learning_assessments to authenticated;
grant insert (id, course_id, lesson_id, title, instructions, starts_at, due_at,
  time_limit_minutes, attempt_limit, passing_score, randomize_questions)
  on public.learning_assessments to authenticated;
grant update (title, instructions, starts_at, due_at, time_limit_minutes,
  attempt_limit, passing_score, randomize_questions, status, results_released)
  on public.learning_assessments to authenticated;
grant select (id, lesson_id, vocabulary_id, kind, prompt, choices, position,
  is_published, created_at, assessment_id, points, bank_category)
  on public.learning_exercise_questions to authenticated;
grant insert (id, lesson_id, vocabulary_id, kind, prompt, choices, correct_choice,
  position, is_published, assessment_id, points, answer_key, bank_category)
  on public.learning_exercise_questions to authenticated;
grant update (vocabulary_id, kind, prompt, choices, correct_choice, position,
  is_published, assessment_id, points, answer_key, bank_category)
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

create or replace function private.sai_learning_assessment_eligible(
  wanted_assessment uuid, wanted_student uuid
)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.learning_assessments a
    join public.students s on s.id = wanted_student
      and s.class_id = a.class_id and s.status = 'active'
    where a.id = wanted_assessment
      and (
        not exists (
          select 1 from public.learning_assessment_assignments x
          where x.assessment_id = a.id
        )
        or exists (
          select 1 from public.learning_assessment_assignments x
          where x.assessment_id = a.id and x.student_id = s.id
        )
      )
  );
$$;

create or replace function private.sai_learning_assessment_read(wanted_assessment uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.learning_assessments a
    where a.id = wanted_assessment
      and a.status in ('published','closed','archived')
        and (
          private.sai_security_can_read_student(
            (select s.id from public.students s
              where s.class_id = a.class_id and s.user_id = (select auth.uid())
                and private.sai_learning_assessment_eligible(a.id, s.id) limit 1)
          )
          or private.sai_security_can_read_student(
            (select s.id from public.students s
              join public.parent_student_links l on l.student_id = s.id
              where s.class_id = a.class_id and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
                and private.sai_learning_assessment_eligible(a.id, s.id) limit 1)
          )
        )
  );
$$;

revoke all on function private.sai_learning_assessment_manage(uuid),
  private.sai_learning_assessment_read(uuid),
  private.sai_learning_assessment_eligible(uuid, uuid) from public, anon;
grant execute on function private.sai_learning_assessment_manage(uuid),
  private.sai_learning_assessment_read(uuid),
  private.sai_learning_assessment_eligible(uuid, uuid) to authenticated;

create policy learning_assessments_select on public.learning_assessments
  for select to authenticated
  using (
    private.sai_learning_can_manage_course(course_id)
    or (status in ('published','closed','archived') and private.sai_security_can_read_student(
      (select s.id from public.students s
        where s.class_id = learning_assessments.class_id and s.user_id = (select auth.uid())
          and private.sai_learning_assessment_eligible(learning_assessments.id, s.id) limit 1)
    ))
    or (status in ('published','closed','archived') and private.sai_security_can_read_student(
      (select s.id from public.students s
        join public.parent_student_links l on l.student_id = s.id
        where s.class_id = learning_assessments.class_id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
          and private.sai_learning_assessment_eligible(learning_assessments.id, s.id) limit 1)
    ))
  );

create policy learning_assessments_write on public.learning_assessments
  for all to authenticated
  using (private.sai_learning_can_manage_course(course_id))
  with check (private.sai_learning_can_manage_course(course_id));

create function public.sai_learning_assessment_roster(p_assessment uuid)
returns table (
  student_id uuid, full_name text, admission_no text,
  assigned boolean, class_wide boolean
)
language plpgsql stable security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_class uuid;
begin
  if (select auth.uid()) is null
    or not private.sai_learning_assessment_manage(p_assessment) then
    raise exception 'Assessment roster is not available to this account'
      using errcode = '42501';
  end if;
  select a.class_id into v_class
    from public.learning_assessments a where a.id = p_assessment;
  return query
    select s.id, s.full_name, s.admission_no,
      (not exists (
        select 1 from public.learning_assessment_assignments x
        where x.assessment_id = p_assessment
      ) or exists (
        select 1 from public.learning_assessment_assignments x
        where x.assessment_id = p_assessment and x.student_id = s.id
      )),
      not exists (
        select 1 from public.learning_assessment_assignments x
        where x.assessment_id = p_assessment
      )
    from public.students s
    where s.class_id = v_class and s.status = 'active'
    order by s.full_name, s.id;
end;
$$;

create function public.sai_learning_assessment_assign(
  p_assessment uuid, p_student_ids uuid[]
)
returns integer language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_assessment public.learning_assessments%rowtype;
  v_count integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select a.* into v_assessment
    from public.learning_assessments a
    where a.id = p_assessment for update;
  if v_assessment.id is null
    or not private.sai_learning_assessment_manage(p_assessment) then
    raise exception 'Assessment assignment is not authorized'
      using errcode = '42501';
  end if;
  if v_assessment.status not in ('draft','published')
    or exists (
      select 1 from public.learning_assessment_attempts a
      where a.assessment_id = p_assessment
    ) then
    raise exception 'Assignments are locked after attempts begin or the assessment closes'
      using errcode = '23514';
  end if;
  if p_student_ids is null or cardinality(p_student_ids) > 1000
    or cardinality(p_student_ids) <>
      (select count(distinct wanted.id)
        from unnest(p_student_ids) as wanted(id)) then
    raise exception 'Student assignment list is invalid' using errcode = '23514';
  end if;
  if exists (
    select 1 from unnest(p_student_ids) wanted(id)
    where not exists (
      select 1 from public.students s
      where s.id = wanted.id and s.class_id = v_assessment.class_id
        and s.status = 'active'
    )
  ) then
    raise exception 'Every assigned student must be active in the assessment class'
      using errcode = '23514';
  end if;
  delete from public.learning_assessment_assignments x
    where x.assessment_id = p_assessment;
  insert into public.learning_assessment_assignments
    (assessment_id, student_id, assigned_by)
  select p_assessment, wanted.id, (select auth.uid())
    from unnest(p_student_ids) wanted(id);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create function public.sai_learning_assessment_duplicate(
  p_assessment uuid, p_title text default null
)
returns uuid language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_source public.learning_assessments%rowtype;
  v_id uuid;
  v_title text;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select a.* into v_source
    from public.learning_assessments a
    where a.id = p_assessment for share;
  if v_source.id is null
    or not private.sai_learning_assessment_manage(p_assessment) then
    raise exception 'Assessment duplication is not authorized'
      using errcode = '42501';
  end if;
  v_title := coalesce(nullif(btrim(p_title), ''), v_source.title || ' (نسخة)');
  if length(v_title) < 2 or length(v_title) > 200 then
    raise exception 'Assessment title must contain 2 to 200 characters'
      using errcode = '23514';
  end if;
  insert into public.learning_assessments (
    course_id, lesson_id, title, instructions, starts_at, due_at,
    time_limit_minutes, attempt_limit, passing_score, randomize_questions,
    status, results_released
  )
  values (
    v_source.course_id, v_source.lesson_id, v_title, v_source.instructions,
    null, null, v_source.time_limit_minutes, v_source.attempt_limit,
    v_source.passing_score, v_source.randomize_questions, 'draft', false
  )
  returning id into v_id;
  insert into public.learning_exercise_questions (
    lesson_id, vocabulary_id, kind, prompt, choices, correct_choice,
    position, is_published, assessment_id, points, answer_key, bank_category
  )
  select q.lesson_id, q.vocabulary_id, q.kind, q.prompt, q.choices,
    q.correct_choice, q.position, false, v_id, q.points, q.answer_key,
    q.bank_category
  from public.learning_exercise_questions q
  where q.assessment_id = p_assessment
  order by q.position, q.id;
  return v_id;
end;
$$;

create function public.sai_learning_assessment_question_bank(
  p_course uuid, p_category text default null
)
returns table (
  id uuid, category text, kind text, prompt text, choices jsonb,
  correct_choice integer, answer_key jsonb, points numeric, "position" integer,
  lesson_id uuid
)
language plpgsql stable security definer
set search_path = pg_catalog, public, private, auth
as $$
begin
  if (select auth.uid()) is null
    or not private.sai_learning_can_manage_course(p_course) then
    raise exception 'Question bank is not available to this account' using errcode = '42501';
  end if;
  return query
    select q.id, q.bank_category, q.kind, q.prompt, q.choices,
      q.correct_choice, q.answer_key, q.points, q.position, q.lesson_id
    from public.learning_exercise_questions q
    join public.learning_lessons l on l.id = q.lesson_id
    where l.course_id = p_course and q.bank_category is not null
      and (p_category is null or q.bank_category = btrim(p_category))
    order by q.bank_category, q.created_at desc, q.id;
end;
$$;

create function public.sai_learning_assessment_add_from_bank(
  p_assessment uuid, p_question uuid
)
returns uuid language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_assessment public.learning_assessments%rowtype;
  v_question public.learning_exercise_questions%rowtype;
  v_new_question uuid;
  v_position integer;
begin
  select a.* into v_assessment from public.learning_assessments a
    where a.id = p_assessment and a.status = 'draft' for update;
  if v_assessment.id is null
    or not private.sai_learning_assessment_manage(p_assessment) then
    raise exception 'Assessment cannot accept bank questions' using errcode = '42501';
  end if;
  select q.* into v_question
    from public.learning_exercise_questions q
    join public.learning_lessons l on l.id = q.lesson_id
    where q.id = p_question and q.bank_category is not null
      and l.course_id = v_assessment.course_id;
  if v_question.id is null then
    raise exception 'Question is not in this course question bank' using errcode = '42501';
  end if;
  select coalesce(max(q.position), 0) + 1 into v_position
    from public.learning_exercise_questions q where q.assessment_id = p_assessment;
  insert into public.learning_exercise_questions (
    lesson_id, kind, prompt, choices, correct_choice, position,
    is_published, assessment_id, points, answer_key, bank_category
  ) values (
    v_assessment.lesson_id, v_question.kind, v_question.prompt, v_question.choices,
    v_question.correct_choice, v_position, false, p_assessment, v_question.points,
    v_question.answer_key, v_question.bank_category
  ) returning id into v_new_question;
  return v_new_question;
end;
$$;

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
      and private.sai_learning_assessment_eligible(assessment_id, student_id)
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
            and private.sai_learning_assessment_eligible(a.assessment_id, a.student_id)
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
  if new.starts_at is not null and new.due_at is not null
    and new.starts_at >= new.due_at then
    raise exception 'Assessment end must be after its start' using errcode = '23514';
  end if;
  new.class_id := v_course.class_id;
  new.academic_session_id := v_course.session_id;
  new.updated_at := now();
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not (
      (old.status = 'draft' and new.status in ('published','archived'))
      or (old.status = 'published' and new.status in ('draft','closed'))
      or (old.status = 'closed' and new.status = 'archived')
    ) then
      raise exception 'Invalid assessment state transition' using errcode = '23514';
    end if;
  end if;
  if tg_op = 'UPDATE' and old.status in ('closed','archived')
    and (new.course_id, new.lesson_id, new.title, new.instructions, new.starts_at,
      new.due_at, new.time_limit_minutes, new.attempt_limit, new.passing_score,
      new.randomize_questions)
    is distinct from
      (old.course_id, old.lesson_id, old.title, old.instructions, old.starts_at,
      old.due_at, old.time_limit_minutes, old.attempt_limit, old.passing_score,
      old.randomize_questions) then
    raise exception 'Closed or archived assessments cannot be edited'
      using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and new.status = 'published' and old.status <> 'published' then
    new.published_at := now();
  elsif new.status = 'draft' then
    new.published_at := null;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published'
    and exists (select 1 from public.learning_assessment_attempts a where a.assessment_id = old.id)
    and (new.course_id, new.lesson_id, new.title, new.instructions, new.starts_at,
      new.due_at, new.time_limit_minutes, new.attempt_limit, new.passing_score,
      new.randomize_questions)
      is distinct from
      (old.course_id, old.lesson_id, old.title, old.instructions, old.starts_at,
      old.due_at, old.time_limit_minutes, old.attempt_limit, old.passing_score,
      old.randomize_questions) then
    raise exception 'Published assessment with attempts cannot be edited' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and old.status = 'published'
    and new.status = 'draft'
    and exists (select 1 from public.learning_assessment_attempts a where a.assessment_id = old.id) then
    raise exception 'Published assessment with attempts cannot return to draft' using errcode = '23514';
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

create function private.sai_learning_assessment_delete_guard()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if old.status in ('published','closed','archived')
    or exists (select 1 from public.learning_assessment_attempts a
      where a.assessment_id = old.id) then
    raise exception 'Published assessments and assessment history cannot be deleted'
      using errcode = '23514';
  end if;
  return old;
end;
$$;

create trigger learning_assessments_delete_guard
  before delete on public.learning_assessments
  for each row execute function private.sai_learning_assessment_delete_guard();

create function private.sai_learning_assessment_questions_sync()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_old_assessment uuid;
  v_new_assessment uuid;
begin
  if tg_op <> 'INSERT' then
    v_old_assessment := old.assessment_id;
  end if;
  if tg_op <> 'DELETE' then
    v_new_assessment := new.assessment_id;
  end if;
  if v_old_assessment is not null or v_new_assessment is not null then
    if current_setting('transaction_isolation') <> 'read committed' then
      raise exception 'Assessment question changes require read committed isolation' using errcode = '25001';
    end if;
    perform 1 from public.learning_assessments a
      where a.id = any (array[v_old_assessment, v_new_assessment])
      order by a.id for update;
  end if;
  if exists (select 1 from public.learning_assessment_attempts a
    where a.assessment_id = any (array[v_old_assessment, v_new_assessment])) then
    raise exception 'Assessment questions cannot be edited after attempts begin' using errcode = '23514';
  end if;
  if exists (select 1 from public.learning_assessments a
  where a.id = any (array[v_old_assessment, v_new_assessment])
    and a.status in ('closed','archived')) then
  raise exception 'Closed or archived assessment questions cannot be edited'
    using errcode = '23514';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  if new.assessment_id is not null then
    if not exists (select 1 from public.learning_assessments a
      where a.id = new.assessment_id and a.lesson_id = new.lesson_id) then
      raise exception 'Question must belong to the assessment lesson' using errcode = '23514';
    end if;
    new.is_published := exists (select 1 from public.learning_assessments a
      where a.id = new.assessment_id and a.status = 'published');
  elsif new.bank_category is not null then
    new.bank_category := btrim(new.bank_category);
    if length(new.bank_category) not between 1 and 80 then
      raise exception 'Question category must be between 1 and 80 characters'
        using errcode = '23514';
    end if;
    new.is_published := false;
  end if;
  if new.assessment_id is not null or new.bank_category is not null then
    if jsonb_typeof(new.choices) is distinct from 'array' then
      raise exception 'Question options must be a JSON array' using errcode = '23514';
    end if;
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
    elsif new.kind = 'multiple_select' then
      if jsonb_array_length(new.choices) < 2 or jsonb_array_length(new.choices) > 6
        or jsonb_typeof(new.answer_key) is distinct from 'array'
        or jsonb_array_length(new.answer_key) < 1
        or jsonb_array_length(new.answer_key) > jsonb_array_length(new.choices)
        or new.correct_choice is not null
        or exists (
          select 1 from jsonb_array_elements(new.answer_key) selected(value)
          where jsonb_typeof(selected.value) <> 'number'
            or (case when selected.value #>> '{}' ~ '^\d+$'
                then (selected.value #>> '{}')::integer else -1 end)
              not between 0 and jsonb_array_length(new.choices) - 1
        )
        or (select count(*) from jsonb_array_elements(new.answer_key))
          <> (select count(distinct value::integer)
              from jsonb_array_elements_text(new.answer_key) values(value)) then
        raise exception 'Multiple-select question needs distinct valid answer indexes'
          using errcode = '23514';
      end if;
      select jsonb_agg(index order by index) into new.answer_key
        from jsonb_array_elements_text(new.answer_key) selected(value)
        cross join lateral (select selected.value::integer as index) normalized;
    elsif new.kind = 'ordering' then
      if jsonb_array_length(new.choices) < 2 or jsonb_array_length(new.choices) > 10
        or jsonb_typeof(new.answer_key) is distinct from 'array'
        or jsonb_array_length(new.answer_key) <> jsonb_array_length(new.choices)
        or new.correct_choice is not null
        or exists (
          select 1 from jsonb_array_elements(new.answer_key) answer(value)
          where jsonb_typeof(answer.value) <> 'string'
            or not exists (
              select 1 from jsonb_array_elements_text(new.choices) choice(value)
              where choice.value = answer.value #>> '{}'
            )
        )
        or (select count(*) from jsonb_array_elements_text(new.answer_key))
          <> (select count(distinct value)
              from jsonb_array_elements_text(new.answer_key) values(value)) then
        raise exception 'Ordering question needs a permutation of all choices'
          using errcode = '23514';
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
  before insert or update or delete on public.learning_exercise_questions
  for each row execute function private.sai_learning_assessment_questions_sync();

create function private.sai_learning_assessment_publish_questions()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public
as $$
begin
  if new.status is distinct from old.status then
    update public.learning_exercise_questions
      set is_published = (new.status <> 'draft')
      where assessment_id = new.id
        and is_published is distinct from (new.status <> 'draft');
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
  v_expired_attempt public.learning_assessment_attempts%rowtype;
  v_next integer;
  v_question_order uuid[];
  v_max_score numeric(9,2);
begin
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'Starting an assessment requires read committed isolation' using errcode = '25001';
  end if;
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
  if not private.sai_learning_assessment_eligible(p_assessment, v_student) then
    raise exception 'Assessment is not assigned to this student' using errcode = '42501';
  end if;
  if v_assessment.starts_at is not null and clock_timestamp() < v_assessment.starts_at then
    raise exception 'Assessment has not started yet' using errcode = 'P0001';
  end if;
  if v_assessment.due_at is not null and clock_timestamp() > v_assessment.due_at then
    raise exception 'Assessment deadline has passed' using errcode = 'P0001';
  end if;
  select a.* into v_attempt from public.learning_assessment_attempts a
    where a.assessment_id = p_assessment and a.student_id = v_student
      and a.status = 'in_progress'
    order by a.attempt_number desc limit 1 for update;
  if v_attempt.id is not null and v_attempt.expires_at is not null
    and clock_timestamp() >= v_attempt.expires_at then
    v_expired_attempt := v_attempt;
    perform public.sai_learning_assessment_submit(v_attempt.id);
    select * into v_expired_attempt from public.learning_assessment_attempts
      where id = v_attempt.id;
    v_attempt.id := null;
  end if;
  if v_attempt.id is null then
    select coalesce(max(a.attempt_number), 0) + 1 into v_next
      from public.learning_assessment_attempts a
      where a.assessment_id = p_assessment and a.student_id = v_student;
    if v_next > v_assessment.attempt_limit then
      if v_expired_attempt.id is not null then
        return jsonb_build_object(
          'attempt_id', v_expired_attempt.id,
          'attempt_number', v_expired_attempt.attempt_number,
          'status', v_expired_attempt.status,
          'timed_out', true,
          'due_at', v_assessment.due_at,
          'expires_at', v_expired_attempt.expires_at,
          'passing_score', v_assessment.passing_score,
          'questions', '[]'::jsonb,
          'saved_answers', '{}'::jsonb
        );
      end if;
      raise exception 'No attempts remain for this assessment' using errcode = 'P0001';
    end if;
    select array_agg(q.id order by
        case when v_assessment.randomize_questions then random() end,
        q.position, q.id),
      coalesce(sum(q.points), 0)
      into v_question_order, v_max_score
      from public.learning_exercise_questions q
      where q.assessment_id = p_assessment and q.is_published;
    insert into public.learning_assessment_attempts
      (assessment_id, student_id, attempt_number, max_score, question_order, expires_at)
    values (p_assessment, v_student, v_next, v_max_score, v_question_order,
      case when v_assessment.time_limit_minutes is null then v_assessment.due_at
        else least(coalesce(v_assessment.due_at, 'infinity'::timestamptz),
          clock_timestamp() + make_interval(mins => v_assessment.time_limit_minutes))
      end)
    returning * into v_attempt;
  end if;
  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_number', v_attempt.attempt_number,
    'due_at', v_assessment.due_at,
    'expires_at', v_attempt.expires_at,
    'passing_score', v_assessment.passing_score,
    'questions', coalesce(case when cardinality(v_attempt.question_order) > 0 then (
      select jsonb_agg(jsonb_build_object(
        'id', q.id, 'kind', q.kind, 'prompt', q.prompt,
        'choices', q.choices, 'points', q.points, 'position', q.position
      ) order by ordered.ordinality)
      from unnest(v_attempt.question_order) with ordinality ordered(question_id, ordinality)
      join public.learning_exercise_questions q on q.id = ordered.question_id
    ) else (
      select jsonb_agg(jsonb_build_object(
        'id', q.id, 'kind', q.kind, 'prompt', q.prompt,
        'choices', q.choices, 'points', q.points, 'position', q.position
      ) order by q.position, q.id)
      from public.learning_exercise_questions q
      where q.assessment_id = p_assessment and q.is_published
    ) end, '[]'::jsonb),
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
    where x.id = v_attempt.assessment_id and x.status <> 'published') then
    raise exception 'Assessment is closed' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.learning_assessments x
    where x.id = v_attempt.assessment_id and x.due_at is not null
      and clock_timestamp() > x.due_at) then
    raise exception 'Assessment deadline has passed' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.learning_assessment_attempts a
    where a.id = v_attempt.id and a.expires_at is not null
      and clock_timestamp() >= a.expires_at) then
    raise exception 'Assessment time limit has passed' using errcode = 'P0001';
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
  elsif v_question.kind = 'multiple_select' and (
    jsonb_typeof(p_answer) <> 'array'
    or jsonb_array_length(p_answer) < 1
    or exists (
      select 1 from jsonb_array_elements(p_answer) selected(value)
      where jsonb_typeof(selected.value) <> 'number'
        or (case when selected.value #>> '{}' ~ '^\d+$'
            then (selected.value #>> '{}')::integer else -1 end)
          not between 0 and jsonb_array_length(v_question.choices) - 1
    )
    or (select count(*) from jsonb_array_elements(p_answer))
      <> (select count(distinct value::integer)
          from jsonb_array_elements_text(p_answer) values(value))
  ) then
    raise exception 'Multiple-select answer must contain unique valid option indexes'
      using errcode = '23514';
   elsif v_question.kind = 'ordering' and (
    jsonb_typeof(p_answer) <> 'array'
    or jsonb_array_length(p_answer) <> jsonb_array_length(v_question.choices)
    or exists (
      select 1 from jsonb_array_elements(p_answer) answer(value)
      where jsonb_typeof(answer.value) <> 'string'
        or not exists (
          select 1 from jsonb_array_elements_text(v_question.choices) choice(value)
          where choice.value = answer.value #>> '{}'
        )
    )
    or (select count(*) from jsonb_array_elements_text(p_answer))
      <> (select count(distinct value)
          from jsonb_array_elements_text(p_answer) values(value))
   ) then
    raise exception 'Ordering answer must be a permutation of all choices'
      using errcode = '23514';
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
    where x.id = v_attempt.assessment_id and x.status <> 'published') then
    raise exception 'Assessment is closed' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.learning_assessments x
    where x.id = v_attempt.assessment_id and x.due_at is not null
      and clock_timestamp() > x.due_at) then
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
    elsif v_question.kind in ('matching','multiple_select','ordering') then
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
  "position" integer, is_published boolean, bank_category text
)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select q.id, q.lesson_id, q.kind, q.prompt, q.choices, q.correct_choice,
    q.answer_key, q.points, q.position, q.is_published, q.bank_category
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
  points_awarded numeric, feedback text, prompt text, kind text, passed boolean
)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select a.id, a.student_id, a.attempt_number, a.status, a.score, a.max_score,
    a.submitted_at, x.id, x.question_id, x.answer, x.is_correct,
    x.points_awarded, x.feedback, q.prompt, q.kind,
    case when a.score is null then null
      else a.score * 100 / nullif(a.max_score, 0) >= s.passing_score end
  from public.learning_assessment_attempts a
  join public.learning_assessments s on s.id = a.assessment_id
  left join public.learning_assessment_answers x on x.attempt_id = a.id
  left join public.learning_exercise_questions q on q.id = x.question_id
  where a.assessment_id = p_assessment
    and (private.sai_learning_assessment_manage(s.id)
      or (s.results_released
        and private.sai_learning_assessment_eligible(s.id, a.student_id)
        and private.sai_security_can_read_student(a.student_id)))
  order by a.attempt_number desc, a.started_at desc, q.position, q.id;
$$;

-- Keep the existing scored-practice contracts separate from assessment questions.
create or replace function public.sai_learning_exercise_questions_admin(p_lesson uuid)
returns table (id uuid, lesson_id uuid, vocabulary_id uuid, kind text, prompt text,
  choices jsonb, correct_choice integer, "position" integer, is_published boolean,
  created_at timestamptz, updated_at timestamptz)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select q.id, q.lesson_id, q.vocabulary_id, q.kind, q.prompt, q.choices, q.correct_choice,
    q.position, q.is_published, q.created_at, q.updated_at
  from public.learning_exercise_questions q
  where q.lesson_id = p_lesson and q.assessment_id is null
    and q.bank_category is null
    and private.sai_learning_can_manage_course(private.sai_learning_question_course(p_lesson))
  order by q.position, q.id;
$$;

create or replace function public.sai_learning_submit_exercise(p_lesson uuid, p_answers jsonb)
returns jsonb language plpgsql security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_student uuid;
  v_course uuid;
  v_total integer;
  v_correct integer := 0;
  v_score integer;
  v_passed boolean;
  v_answer jsonb;
  v_question public.learning_exercise_questions%rowtype;
  v_choice integer;
  v_right boolean;
  v_results jsonb := '[]'::jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select s.id into v_student from public.students s
    where s.user_id = (select auth.uid())
      and exists (select 1 from public.user_roles r
        where r.user_id = (select auth.uid()) and r.role = 'student');
  if v_student is null then
    raise exception 'No enrolled student record for this account' using errcode = '42501';
  end if;
  select l.course_id into v_course from public.learning_lessons l
    where l.id = p_lesson and l.is_published;
  if v_course is null or not exists (
    select 1 from public.learning_courses c
    join public.students s on s.class_id = c.class_id
    where c.id = v_course and s.id = v_student
  ) then
    raise exception 'Not enrolled in this lesson''s course' using errcode = '42501';
  end if;
  if p_answers is null or jsonb_typeof(p_answers) <> 'array' then
    raise exception 'Invalid answers payload' using errcode = '23514';
  end if;

  select count(*) into v_total from public.learning_exercise_questions q
    where q.lesson_id = p_lesson and q.is_published and q.assessment_id is null;
  if v_total = 0 then
    raise exception 'This lesson has no assessed questions' using errcode = '23514';
  end if;
  for v_question in
    select q.* from public.learning_exercise_questions q
    where q.lesson_id = p_lesson and q.is_published and q.assessment_id is null
    order by q.position, q.id
  loop
    v_answer := (
      select a from jsonb_array_elements(p_answers) a
      where a ->> 'question' = v_question.id::text
      limit 1
    );
    v_choice := null;
    if v_answer is not null and jsonb_typeof(v_answer -> 'choice') = 'number'
      and (v_answer ->> 'choice') ~ '^\d+$' then
      v_choice := (v_answer ->> 'choice')::integer;
    end if;
    if v_choice is not null and v_choice >= jsonb_array_length(v_question.choices) then
      v_choice := null;
    end if;
    v_right := v_choice is not null and v_choice = v_question.correct_choice;
    if v_right then v_correct := v_correct + 1; end if;
    if v_choice is not null then
      insert into public.learning_exercise_attempts
        (question_id, student_id, selected_choice, is_correct, answered_at)
      values (v_question.id, v_student, v_choice, v_right, now())
      on conflict (question_id, student_id) do update
        set selected_choice = excluded.selected_choice,
            is_correct = excluded.is_correct,
            answered_at = excluded.answered_at;
    end if;
    if not v_right and v_question.kind = 'vocabulary' and v_question.vocabulary_id is not null then
      insert into public.learning_vocab_progress
        (vocabulary_id, student_id, status, review_count, last_reviewed_at, updated_at)
      values (v_question.vocabulary_id, v_student, 'learning', 0, now(), now())
      on conflict (vocabulary_id, student_id) do update
        set status = 'learning', review_count = 0,
            last_reviewed_at = now(), updated_at = now();
    end if;
    v_results := v_results || jsonb_build_object('question', v_question.id, 'correct', v_right);
  end loop;
  v_score := (v_correct * 100) / v_total;
  v_passed := v_score >= 70;
  if v_passed then
    perform set_config('sai.assessed_completion', 'on', true);
    insert into public.learning_lesson_progress
      (lesson_id, student_id, status, completion_basis, updated_at)
    values (p_lesson, v_student, 'completed', 'assessed', now())
    on conflict (lesson_id, student_id) do update
      set status = 'completed', completion_basis = 'assessed', updated_at = now();
  end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values ((select auth.uid()), 'exercise_submit', 'learning_lessons', p_lesson,
    jsonb_build_object('student_id', v_student, 'score', v_score, 'passed', v_passed,
      'source', 'sai_learning_submit_exercise'));
  return jsonb_build_object(
    'total', v_total, 'correct', v_correct, 'score', v_score, 'passed', v_passed,
    'results', v_results
  );
end;
$$;

revoke all on function private.sai_learning_assessment_guard(),
  private.sai_learning_assessment_delete_guard(),
  private.sai_learning_assessment_questions_sync(),
  private.sai_learning_assessment_publish_questions(),
  private.sai_learning_assessment_recalculate(uuid) from public, anon, authenticated;
revoke all on function public.sai_learning_assessment_start(uuid),
  public.sai_learning_assessment_save(uuid, uuid, jsonb),
  public.sai_learning_assessment_submit(uuid),
  public.sai_learning_assessment_grade(uuid, numeric, text),
  public.sai_learning_assessment_questions_admin(uuid),
  public.sai_learning_assessment_results(uuid),
  public.sai_learning_assessment_roster(uuid),
  public.sai_learning_assessment_assign(uuid, uuid[]),
  public.sai_learning_assessment_duplicate(uuid, text),
  public.sai_learning_assessment_question_bank(uuid, text),
  public.sai_learning_assessment_add_from_bank(uuid, uuid) from public, anon, authenticated;
grant execute on function public.sai_learning_assessment_start(uuid),
  public.sai_learning_assessment_save(uuid, uuid, jsonb),
  public.sai_learning_assessment_submit(uuid),
  public.sai_learning_assessment_grade(uuid, numeric, text),
  public.sai_learning_assessment_questions_admin(uuid),
  public.sai_learning_assessment_results(uuid),
  public.sai_learning_assessment_roster(uuid),
  public.sai_learning_assessment_assign(uuid, uuid[]),
  public.sai_learning_assessment_duplicate(uuid, text),
  public.sai_learning_assessment_question_bank(uuid, text),
  public.sai_learning_assessment_add_from_bank(uuid, uuid) to authenticated;

revoke all on function public.sai_learning_exercise_questions_admin(uuid),
  public.sai_learning_submit_exercise(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.sai_learning_exercise_questions_admin(uuid),
  public.sai_learning_submit_exercise(uuid, jsonb) to authenticated;

commit;
