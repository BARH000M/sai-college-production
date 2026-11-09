insert into auth.users(id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002'),
 ('10000000-0000-4000-8000-000000000003'),
 ('10000000-0000-4000-8000-000000000004');
insert into public.user_roles(user_id, role) values
 ('10000000-0000-4000-8000-000000000001', 'super_admin'),
 ('10000000-0000-4000-8000-000000000002', 'admin'),
 ('10000000-0000-4000-8000-000000000003', 'student'),
 ('10000000-0000-4000-8000-000000000004', 'student');
insert into public.profiles(id, full_name) values
 ('10000000-0000-4000-8000-000000000001', 'Synthetic Super Admin'),
 ('10000000-0000-4000-8000-000000000002', 'Synthetic Branch Admin'),
 ('10000000-0000-4000-8000-000000000003', 'Synthetic Student A'),
 ('10000000-0000-4000-8000-000000000004', 'Synthetic Student B');
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
insert into public.branches(id, name, code) values
 ('20000000-0000-4000-8000-000000000001', 'Synthetic Branch A', 'SYN-A'),
 ('20000000-0000-4000-8000-000000000002', 'Synthetic Branch B', 'SYN-B');
insert into public.academic_sessions(id, name, starts_on, ends_on, is_active) values
 ('30000000-0000-4000-8000-000000000001', 'Synthetic Session', '2020-01-01', '2099-12-31', true);
insert into public.branch_memberships(user_id, branch_id) values
 ('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001');
insert into public.classes(id, branch_id, session_id, name, program) values
 ('40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001', 'Synthetic Class', 'Synthetic Program');
insert into public.students(id, user_id, branch_id, admission_no, full_name, class_id) values
 ('50000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003',
  '20000000-0000-4000-8000-000000000001', 'SYN-001', 'Synthetic Student A',
  '40000000-0000-4000-8000-000000000001'),
 ('50000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000004',
  '20000000-0000-4000-8000-000000000002', 'SYN-002', 'Synthetic Student B', null);
select set_config('request.jwt.claim.sub', '', true);
