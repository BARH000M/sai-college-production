-- Teacher account management: password resets, class reassignment and unassignment.
-- No new columns are required: the existing classes.teacher_id, learning_courses.teacher_id
-- and branch_memberships tables already carry the access model. These indexes keep the
-- "which class/course belongs to this teacher" lookups fast when an admin moves a teacher.
--
-- The privileged work itself runs inside the provision-learning-account Edge Function,
-- which requires a signed-in super admin and uses the service role only after that check.

create index if not exists classes_teacher_id_idx
  on public.classes (teacher_id)
  where teacher_id is not null;

create index if not exists learning_courses_teacher_id_idx
  on public.learning_courses (teacher_id)
  where teacher_id is not null;

create index if not exists branch_memberships_user_active_idx
  on public.branch_memberships (user_id, is_active);