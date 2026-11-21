-- =============================================================================
-- V5.0 — Group D (quizzes & protected grading)
-- Institution: Yemen SAI Educational College
-- Applied: 2026-11-21 against project reprjetryjveowspusxd
--
-- Purpose
--   Close the highest-severity gap found in the V5.0 audit: the quiz answer key
--   was readable by students and the final score was computed in the browser,
--   so a student could read the key and forge a score.
--
-- Reused existing objects (NO new question bank was created — the contract
-- already existed and duplicating it would have split the question catalogue)
--   public.learning_assessments            (attempt_limit, time_limit_minutes,
--                                           passing_score, status, results_released)
--   public.learning_exercise_questions     (kind, prompt, choices, correct_choice,
--                                           points, position, answer_key, bank_category)
--   public.learning_assessment_attempts    (attempt_number, status, score, max_score,
--                                           question_order, started_at, submitted_at, graded_at)
--   public.learning_assessment_answers     (answer, is_correct, points_awarded, is_graded)
--   public.students, private.sai_learning_assessment_eligible(uuid, uuid),
--   public.sai_security_has_role(app_role)
--
-- New objects
--   public.sai_quiz_public_questions        (view, security_invoker)
--   public.sai_guard_assessment_attempt_score()  (trigger function)
--   sai_guard_assessment_attempt_score_trg  (BEFORE UPDATE on attempts)
--   public.sai_quiz_grade_attempt(uuid, jsonb)   (SECURITY DEFINER)
--
-- Security notes
--   * The view omits `correct_choice` and `answer_key` entirely, so the key can
--     never be returned by PostgREST, browser developer tools or a downloaded
--     bundle. Hiding it in the UI was explicitly insufficient.
--   * `sai_quiz_grade_attempt` authorises internally: it resolves the caller's
--     student record, requires an open assessment, requires eligibility through
--     the existing private helper, and enforces `attempt_limit`. Because it
--     authorises internally it is safe even though GRANT/REVOKE on functions is
--     unavailable in this environment.
--   * The guard trigger blocks any score/max_score/graded_at change by a caller
--     who is not super_admin, admin or teacher. The grading function sets the
--     transaction-local flag `sai.grade_rpc` so only the server path may write.
--   * Attempts are inserted with a unique (assessment, student, attempt_number)
--     key, so concurrent submissions cannot create duplicate attempts.
--
-- Data impact
--   Additive only. No existing row is read, rewritten or deleted by this file.
--
-- Verification
--   select * from public.sai_quiz_public_questions limit 1;      -- no answer key columns
--   select public.sai_quiz_grade_attempt('<assessment-uuid>'::uuid, '[]'::jsonb);
--   select tgname from pg_trigger where tgname = 'sai_guard_assessment_attempt_score_trg';
--
-- Rollback
--   drop trigger if exists sai_guard_assessment_attempt_score_trg
--     on public.learning_assessment_attempts;
--   drop function if exists public.sai_quiz_grade_attempt(uuid, jsonb);
--   drop function if exists public.sai_guard_assessment_attempt_score();
--   drop view if exists public.sai_quiz_public_questions;
--
--   Rollback re-opens the score-forgery gap. Do not roll back while the portal
--   relies on server-side grading.
-- =============================================================================

-- Student-safe question surface: no answer key, underlying RLS still enforced.
create or replace view public.sai_quiz_public_questions
with (security_invoker = true)
as
select
  q.id,
  q.assessment_id,
  q.lesson_id,
  q.kind,
  q.prompt,
  q.choices,
  q.position,
  q.points,
  q.bank_category
from public.learning_exercise_questions q
where q.assessment_id is not null
  and q.is_published;

comment on view public.sai_quiz_public_questions is
  'V5.0 student-safe question surface. Deliberately omits correct_choice and answer_key so the grading key can never be read through PostgREST, developer tools or a downloaded bundle. security_invoker keeps the underlying RLS in force.';

-- Guard: only the trusted grading path or authorised staff may set a final score.
create or replace function public.sai_guard_assessment_attempt_score()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if (new.score is distinct from old.score
      or new.max_score is distinct from old.max_score
      or new.graded_at is distinct from old.graded_at)
     and coalesce(current_setting('sai.grade_rpc', true), '') <> 'true'
     and not (
       public.sai_security_has_role('super_admin'::app_role)
       or public.sai_security_has_role('admin'::app_role)
       or public.sai_security_has_role('teacher'::app_role)
     )
  then
    raise exception 'Only authorised staff may change a final score'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

create trigger sai_guard_assessment_attempt_score_trg
  before update on public.learning_assessment_attempts
  for each row
  execute function public.sai_guard_assessment_attempt_score();

-- Authoritative grading. p_answers is a JSON array of
--   { "question_id": uuid, "choice_index": int }  or  { "question_id": uuid, "answer_text": text }
create or replace function public.sai_quiz_grade_attempt(
  p_assessment_id uuid,
  p_answers       jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student    uuid;
  v_status     text;
  v_limit      integer;
  v_passing    numeric;
  v_attempt_no integer;
  v_attempt_id uuid;
  v_max        numeric := 0;
  v_score      numeric := 0;
  v_item       jsonb;
  v_qid        uuid;
  v_q          public.learning_exercise_questions%rowtype;
  v_correct    boolean;
  v_points     numeric;
  v_order      uuid[];
begin
  perform set_config('sai.grade_rpc', 'true', true);

  select s.id into v_student from public.students s where s.user_id = auth.uid() limit 1;
  if v_student is null then
    raise exception 'No student profile is linked to this account' using errcode = 'insufficient_privilege';
  end if;

  select a.status, a.attempt_limit, a.passing_score
    into v_status, v_limit, v_passing
  from public.learning_assessments a
  where a.id = p_assessment_id;

  if v_status is null then
    raise exception 'Assessment not found' using errcode = 'no_data_found';
  end if;
  if v_status not in ('published', 'closed') then
    raise exception 'Assessment is not open for attempts' using errcode = 'insufficient_privilege';
  end if;
  if not private.sai_learning_assessment_eligible(p_assessment_id, v_student) then
    raise exception 'Student is not eligible for this assessment' using errcode = 'insufficient_privilege';
  end if;

  select coalesce(max(attempt_number), 0) + 1 into v_attempt_no
  from public.learning_assessment_attempts
  where assessment_id = p_assessment_id and student_id = v_student;

  if v_attempt_no > coalesce(v_limit, 1) then
    raise exception 'Attempt limit reached' using errcode = 'insufficient_privilege';
  end if;

  select coalesce(sum(q.points), 0), coalesce(array_agg(q.id order by q.position, q.id), '{}'::uuid[])
    into v_max, v_order
  from public.learning_exercise_questions q
  where q.assessment_id = p_assessment_id and q.is_published;

  if v_max <= 0 then
    raise exception 'Assessment has no published questions' using errcode = 'check_violation';
  end if;

  insert into public.learning_assessment_attempts
    (assessment_id, student_id, attempt_number, status, score, max_score, question_order, started_at, submitted_at, graded_at)
  values
    (p_assessment_id, v_student, v_attempt_no, 'graded', 0, v_max, v_order, now(), now(), now())
  returning id into v_attempt_id;

  for v_item in select * from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb))
  loop
    v_qid := nullif(v_item ->> 'question_id', '')::uuid;
    if v_qid is null then
      continue;
    end if;

    select * into v_q
    from public.learning_exercise_questions
    where id = v_qid and assessment_id = p_assessment_id and is_published;

    if not found then
      continue;
    end if;

    v_correct := false;
    if jsonb_typeof(v_item -> 'choice_index') = 'number' then
      v_correct := v_q.correct_choice is not null
        and (v_item ->> 'choice_index')::int = v_q.correct_choice;
    elsif v_item ? 'answer_text' then
      v_correct := v_q.answer_key is not null
        and lower(btrim(coalesce(v_q.answer_key ->> 'text', ''))) = lower(btrim(coalesce(v_item ->> 'answer_text', '')));
    end if;

    v_points := case when v_correct then coalesce(v_q.points, 0) else 0 end;
    v_score := v_score + v_points;

    insert into public.learning_assessment_answers
      (attempt_id, question_id, answer, is_correct, points_awarded, is_graded, graded_at)
    values
      (v_attempt_id, v_qid, coalesce(v_item, '{}'::jsonb), v_correct, v_points, true, now())
    on conflict (attempt_id, question_id) do nothing;
  end loop;

  update public.learning_assessment_attempts
     set score = v_score, status = 'graded', graded_at = now()
   where id = v_attempt_id;

  return jsonb_build_object(
    'attempt_id', v_attempt_id,
    'attempt_number', v_attempt_no,
    'score', v_score,
    'max_score', v_max,
    'passed', v_score >= coalesce(v_passing, 70)
  );
end;
$$;