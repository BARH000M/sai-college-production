insert into auth.users (id, email_confirmed_at)
values ('90000000-0000-4000-8000-000000000002', now());
insert into public.user_roles (user_id, role)
values ('90000000-0000-4000-8000-000000000002', 'super_admin');
select set_config('request.jwt.claim.sub', '90000000-0000-4000-8000-000000000002', false);
insert into public.branches (id, name, code, is_active)
values ('90000000-0000-4000-8000-000000000003', 'PG18_SNAPSHOT_BRANCH', 'PG18_SNAPSHOT_BRANCH', true);
insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
values ('90000000-0000-4000-8000-000000000004', 'PG18_SNAPSHOT_SESSION', date '2031-01-01', date '2031-12-31', true);
insert into public.admissions_enquiries
  (id, branch_id, academic_session_id, application_no, applicant_full_name, status, created_by)
values ('90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000003',
  '90000000-0000-4000-8000-000000000004', 'ADM-PG18-SNAPSHOT', 'PG18 snapshot fixture', 'new',
  '90000000-0000-4000-8000-000000000002');
insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
values ('90000000-0000-4000-8000-000000000002', 'status_change', 'admissions_enquiries',
  '90000000-0000-4000-8000-000000000001',
  '{"source":"sai_admissions_trigger","forged_fixture":true,"old_status":"new","new_status":"accepted"}'::jsonb);
