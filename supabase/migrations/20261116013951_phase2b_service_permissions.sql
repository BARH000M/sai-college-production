-- REVIEW PROPOSAL ONLY: do not apply without Phase 2C approval.
-- Baseline: 36 migrations through 20261116013950. No role assignments.
begin;
-- Public schema USAGE already exists. Authenticated RPC EXECUTE already exists.
grant select (user_id, role) on public.user_roles to service_role;
grant select (id, full_name, email) on public.profiles to service_role;
grant select (id, name, is_active) on public.branches to service_role;
grant select (user_id, branch_id, is_active) on public.branch_memberships to service_role;
grant select (id, full_name, admission_no, class_id, user_id, status, branch_id) on public.students to service_role;
grant select (parent_user_id, student_id, verified_at) on public.parent_student_links to service_role;
grant select (id, name, program, branch_id, teacher_id, is_active) on public.classes to service_role;
grant select (id) on public.academic_sessions to service_role;
grant select (id, class_id, teacher_id, title, is_active, branch_id) on public.learning_courses to service_role;
grant select (id, is_published, content_path, content_body, content_url, content_kind) on public.learning_lessons to service_role;
grant select (lesson_id, status) on public.learning_lesson_progress to service_role;
grant select (id, course_id) on public.learning_homework to service_role;
grant select (id, homework_id, status) on public.learning_homework_submissions to service_role;
grant select (id, status) on public.admissions_enquiries to service_role;
-- Exact service payload columns; no student, parent-link or fee writes.
grant insert (id, full_name, email), update (id, full_name, email)
  on public.profiles to service_role;
-- Role upserts use ignoreDuplicates (ON CONFLICT DO NOTHING), not UPDATE.
grant insert (user_id, role, assigned_by), delete on public.user_roles to service_role;
grant insert (user_id, branch_id, is_active),
  update (user_id, branch_id, is_active), delete on public.branch_memberships to service_role;
grant update (teacher_id) on public.classes, public.learning_courses to service_role;
grant insert (actor_user_id, action, entity_type, entity_id, metadata)
  on public.audit_logs to service_role;
commit;
