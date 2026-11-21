-- =============================================================================
-- V6.0 — Quiz delivery projection fix + media usage tracking
-- Institution: Yemen SAI Educational College
-- Applied: 2026-11-21 against the authorised production project
--
-- Defect found by the V6.0 read-only security audit
--   Version 95 created `sai_quiz_public_questions` with `security_invoker = true`.
--   The base-table RLS policy for a student requires `assessment_id is null` and
--   class membership, so a student can never see assessment questions directly.
--   Because the view ran with the caller's privileges, students saw ZERO quiz
--   questions — quiz delivery was silently broken even though it looked secure.
--
--   A naive fix (granting the base table) would have exposed `correct_choice` and
--   `answer_key`. Instead this migration uses a reviewed secure projection:
--   a SECURITY DEFINER eligibility helper plus a definer view that omits the
--   answer columns entirely, so the key can never be returned by PostgREST,
--   developer tools or a downloaded bundle.
--
-- New / changed objects
--   public.sai_quiz_can_access_assessment(uuid)  SECURITY DEFINER
--   public.sai_quiz_public_questions             (view, no answer-key columns)
--   public.sai_media_assets.usage_count          (additive column)
--
-- Security notes
--   * `sai_quiz_can_access_assessment` returns true only for staff who manage
--     the course or an eligible student in the assessment class.
--   * The view exposes: id, assessment_id, lesson_id, kind, prompt, choices,
--     position, points, bank_category. It never exposes correct_choice or
--     answer_key.
--   * Grading remains server-side through `sai_quiz_grade_attempt(uuid, jsonb)`.
--
-- Data impact
--   Additive only. No row is read, rewritten or deleted.
--
-- Verification
--   select * from public.sai_quiz_public_questions limit 1;  -- no key columns
--   select public.sai_quiz_can_access_assessment('<assessment-uuid>'::uuid);
--
-- Rollback
--   Reverting this migration re-breaks quiz delivery for students. Do not roll
--   back while the Quizzes screen depends on the safe projection.
-- =============================================================================

create or replace function public.sai_quiz_can_access_assessment(p_assessment_id uuid)
returns boolean
language sql
security definer
set search_path = public, private
as $$
  select exists (
    select 1
    from public.learning_assessments a
    where a.id = p_assessment_id
      and a.status in ('published','closed','archived')
      and (
        private.sai_learning_can_manage_course(a.course_id)
        or exists (
          select 1
          from public.students s
          where s.user_id = auth.uid()
            and s.class_id = a.class_id
            and private.sai_learning_assessment_eligible(a.id, s.id)
        )
      )
  );
$$;

create or replace view public.sai_quiz_public_questions as
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
  and q.is_published
  and public.sai_quiz_can_access_assessment(q.assessment_id);

comment on view public.sai_quiz_public_questions is
  'V6.0 student-safe quiz delivery projection. Eligibility-filtered and omits correct_choice and answer_key so the grading key can never be read through PostgREST, developer tools or a downloaded bundle.';

alter table public.sai_media_assets
  add column if not exists usage_count integer not null default 0 check (usage_count >= 0);