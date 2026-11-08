-- 009: lesson content, teacher grading and account provisioning support
-- Applied to the live project; kept here so a fresh environment matches production.

alter table public.learning_lessons
  add column if not exists content_kind text not null default 'none',
  add column if not exists content_url text,
  add column if not exists content_body text,
  add column if not exists content_updated_at timestamptz;

alter table public.learning_lessons drop constraint if exists learning_lessons_content_kind_check;
alter table public.learning_lessons
  add constraint learning_lessons_content_kind_check
  check (content_kind in ('none', 'video', 'reading', 'audio', 'link'));

-- Learning content must never be readable without an authenticated session.
revoke all on public.learning_courses from anon;
revoke all on public.learning_lessons from anon;
revoke all on public.learning_homework from anon;
revoke all on public.learning_homework_submissions from anon;
revoke all on public.learning_lesson_progress from anon;

-- A returned homework must be resubmittable by the student who owns it.
alter policy learning_submissions_student_update on public.learning_homework_submissions
  using (sai_learning_own_student(student_id) and status in ('submitted', 'returned'))
  with check (sai_learning_own_student(student_id) and status = 'submitted');