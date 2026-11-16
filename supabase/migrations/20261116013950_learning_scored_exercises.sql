-- Scored Chinese exercises: server-controlled questions and server-graded attempts.
-- Correct answers are never selectable by client roles; grading happens only
-- inside the sai_learning_submit_exercise RPC. Passing writes a completion
-- with basis 'assessed', which a guarded trigger reserves for that RPC.

create table public.learning_exercise_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.learning_lessons(id) on delete cascade,
  vocabulary_id uuid references public.learning_vocabulary(id) on delete set null,
  kind text not null check (kind in ('vocabulary', 'listening')),
  prompt text not null check (length(btrim(prompt)) between 2 and 200),
  choices jsonb not null,
  correct_choice integer not null,
  position integer not null default 1,
  is_published boolean not null default true,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(choices) = 'array'
    and jsonb_array_length(choices) between 2 and 6
    and correct_choice >= 0
    and correct_choice < jsonb_array_length(choices))
);

create table public.learning_exercise_attempts (
  question_id uuid not null references public.learning_exercise_questions(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  selected_choice integer not null check (selected_choice >= 0),
  is_correct boolean not null,
  answered_at timestamptz not null default now(),
  primary key (question_id, student_id)
);

create index learning_exercise_questions_lesson_idx
  on public.learning_exercise_questions(lesson_id, position);
create index learning_exercise_attempts_student_idx
  on public.learning_exercise_attempts(student_id, answered_at desc);

alter table public.learning_exercise_questions enable row level security;
alter table public.learning_exercise_attempts enable row level security;

-- correct_choice is deliberately absent from the SELECT grant: students read
-- questions but can never fetch the answer key. Managers edit it through
-- writes and read it back through the manager-only RPC below.
revoke all on public.learning_exercise_questions, public.learning_exercise_attempts
  from public, anon, authenticated;
grant select (id, lesson_id, vocabulary_id, kind, prompt, choices, position, is_published, created_at)
  on public.learning_exercise_questions to authenticated;
grant insert (lesson_id, vocabulary_id, kind, prompt, choices, correct_choice, position, is_published),
  update (vocabulary_id, kind, prompt, choices, correct_choice, position, is_published), delete
  on public.learning_exercise_questions to authenticated;
grant select on public.learning_exercise_attempts to authenticated;

create or replace function private.sai_learning_question_course(wanted_lesson uuid)
returns uuid language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select l.course_id from public.learning_lessons l where l.id = wanted_lesson;
$$;
-- RLS policies run as the caller, so this read-only course lookup must be
-- executable by signed-in users; it reveals nothing beyond the lesson's course.
revoke all on function private.sai_learning_question_course(uuid) from public, anon;
grant execute on function private.sai_learning_question_course(uuid) to authenticated;

create policy learning_exercise_questions_select on public.learning_exercise_questions
  for select to authenticated
  using (
    private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id))
    or (is_published and exists (
      select 1
      from public.learning_lessons l
      join public.learning_courses c on c.id = l.course_id
      join public.students s on s.class_id = c.class_id and s.user_id = (select auth.uid())
      where l.id = lesson_id and l.is_published
    ))
  );

create policy learning_exercise_questions_write on public.learning_exercise_questions
  for all to authenticated
  using (private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id)))
  with check (private.sai_learning_can_manage_course(private.sai_learning_question_course(lesson_id)));

-- Students, their class teachers and verified parents read results; only the
-- grading RPC writes them, so no client INSERT/UPDATE/DELETE grant exists.
create policy learning_exercise_attempts_select on public.learning_exercise_attempts
  for select to authenticated
  using (private.sai_security_can_read_student(student_id));

-- Choice payloads must be 2-6 non-empty short strings.
create function private.sai_learning_validate_question()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
begin
  if exists (
    select 1 from jsonb_array_elements(new.choices) choice
    where jsonb_typeof(choice) <> 'string'
      or length(btrim(choice #>> '{}')) = 0
      or length(choice #>> '{}') > 200
  ) then
    raise exception 'Invalid choice list' using errcode = '23514';
  end if;
  if new.kind = 'vocabulary' and new.vocabulary_id is not null and not exists (
    select 1 from public.learning_vocabulary v
    join public.learning_lessons l on l.id = new.lesson_id
    where v.id = new.vocabulary_id and v.course_id = l.course_id
  ) then
    raise exception 'Vocabulary word does not belong to this lesson''s course' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.sai_learning_validate_question() from public, anon, authenticated;
create trigger learning_exercise_questions_validate
  before insert or update on public.learning_exercise_questions
  for each row execute function private.sai_learning_validate_question();

-- 'assessed' completion may only be written by the grading RPC.
alter table public.learning_lesson_progress
  drop constraint if exists learning_lesson_progress_completion_basis_check;
alter table public.learning_lesson_progress
  add constraint learning_lesson_progress_completion_basis_check
  check (completion_basis is null or completion_basis in ('self_reported', 'assessed'));

create function private.sai_learning_guard_assessed_completion()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if new.completion_basis = 'assessed'
    and current_setting('sai.assessed_completion', true) is distinct from 'on' then
    raise exception 'Assessed completion requires the server grading workflow' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function private.sai_learning_guard_assessed_completion() from public, anon, authenticated;
create trigger learning_lesson_progress_guard_assessed
  before insert or update on public.learning_lesson_progress
  for each row execute function private.sai_learning_guard_assessed_completion();

-- Managers read back their full questions, including the answer key.
create function public.sai_learning_exercise_questions_admin(p_lesson uuid)
returns table (id uuid, lesson_id uuid, vocabulary_id uuid, kind text, prompt text,
  choices jsonb, correct_choice integer, "position" integer, is_published boolean,
  created_at timestamptz, updated_at timestamptz)
language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select q.id, q.lesson_id, q.vocabulary_id, q.kind, q.prompt, q.choices, q.correct_choice,
    q.position, q.is_published, q.created_at, q.updated_at
  from public.learning_exercise_questions q
  where q.lesson_id = p_lesson
    and private.sai_learning_can_manage_course(private.sai_learning_question_course(p_lesson))
  order by q.position, q.id;
$$;

-- Grades submitted answers against server-held keys, stores attempts, queues
-- wrong vocabulary for spaced review, and records assessed completion on pass.
create function public.sai_learning_submit_exercise(p_lesson uuid, p_answers jsonb)
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
    where q.lesson_id = p_lesson and q.is_published;
  if v_total = 0 then
    raise exception 'This lesson has no assessed questions' using errcode = '23514';
  end if;

  for v_question in
    select q.* from public.learning_exercise_questions q
    where q.lesson_id = p_lesson and q.is_published
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
    -- Fractional, negative or out-of-range choices are wrong answers, never errors.
    if v_choice is not null and v_choice >= jsonb_array_length(v_question.choices) then
      v_choice := null;
    end if;
    v_right := v_choice is not null and v_choice = v_question.correct_choice;
    if v_right then v_correct := v_correct + 1; end if;

    -- Unanswered questions count as wrong in the score but store no attempt.
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
      -- Rewind the word into the front of the learner's spaced-review queue.
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

revoke all on function public.sai_learning_exercise_questions_admin(uuid),
  public.sai_learning_submit_exercise(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.sai_learning_exercise_questions_admin(uuid),
  public.sai_learning_submit_exercise(uuid, jsonb) to authenticated;
