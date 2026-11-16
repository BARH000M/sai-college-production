-- ISOLATED LOCAL DATABASE ONLY. Verifies student ownership and verified parent
-- links do not expose another student's record.
begin;
do $$
begin
  if current_setting('sai.wave1_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  super_id uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid();
  student_b uuid := gen_random_uuid();
  student_c uuid := gen_random_uuid();
  parent_a uuid := gen_random_uuid();
  parent_b uuid := gen_random_uuid();
  teacher_a uuid := gen_random_uuid();
  multi_role_user uuid := gen_random_uuid();
  branch_id uuid := gen_random_uuid();
  other_branch_id uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  class_a uuid := gen_random_uuid();
  class_b uuid := gen_random_uuid();
  class_c uuid := gen_random_uuid();
  student_record_a uuid := gen_random_uuid();
  student_record_b uuid := gen_random_uuid();
  student_record_c uuid := gen_random_uuid();
  student_record_multi uuid := gen_random_uuid();
  student_record_unrelated uuid := gen_random_uuid();
  run_id text := replace(gen_random_uuid()::text, '-', '');
  visible_count bigint;
begin
  insert into auth.users (id, email_confirmed_at)
  values
    (super_id, now()), (student_a, now()), (student_b, now()), (student_c, now()),
    (parent_a, now()), (parent_b, now()), (teacher_a, now()), (multi_role_user, now());
  insert into public.user_roles (user_id, role)
  values (super_id, 'super_admin'), (student_a, 'student'), (student_b, 'student'),
         (student_c, 'student'), (parent_a, 'parent'), (parent_b, 'parent'),
         (teacher_a, 'teacher'), (multi_role_user, 'teacher'), (multi_role_user, 'student');
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  insert into public.branches (id, name, code)
  values
    (branch_id, 'RLS_TEST_' || run_id, 'RLS_TEST_' || run_id),
    (other_branch_id, 'RLS_TEST_OTHER_' || run_id, 'RLS_TEST_OTHER_' || run_id);
  insert into public.academic_sessions (id, name, starts_on, ends_on)
  values (session_id, 'RLS_TEST_' || run_id, current_date, current_date + 1);
  insert into public.classes (id, branch_id, session_id, name, program, teacher_id)
  values
    (class_a, branch_id, session_id, 'RLS_TEST_CLASS_A_' || run_id, 'Test', teacher_a),
    (class_b, branch_id, session_id, 'RLS_TEST_CLASS_B_' || run_id, 'Test', multi_role_user),
    (class_c, other_branch_id, session_id, 'RLS_TEST_CLASS_C_' || run_id, 'Test', multi_role_user);
  insert into public.branch_memberships (user_id, branch_id, is_active)
  values (teacher_a, branch_id, true), (multi_role_user, branch_id, true);
  insert into public.students (id, branch_id, admission_no, full_name, class_id, user_id)
  values
    (student_record_a, branch_id, 'RLS_TEST_A_' || run_id, 'RLS_TEST_student_a', class_a, student_a),
    (student_record_b, branch_id, 'RLS_TEST_B_' || run_id, 'RLS_TEST_student_b', class_b, student_b),
    (student_record_c, other_branch_id, 'RLS_TEST_C_' || run_id, 'RLS_TEST_student_c', class_c, student_c),
    (student_record_multi, branch_id, 'RLS_TEST_M_' || run_id, 'RLS_TEST_multi', class_a, multi_role_user),
    (student_record_unrelated, branch_id, 'RLS_TEST_U_' || run_id, 'RLS_TEST_unrelated', class_a, null);
  insert into public.profiles (id, full_name, email)
  values
    (parent_a, 'RLS_TEST_parent_a', 'RLS_TEST_parent_a@example.test'),
    (parent_b, 'RLS_TEST_parent_b', 'RLS_TEST_parent_b@example.test');

  execute 'set local role authenticated';
  perform public.admissions_link_student_account(student_record_a, student_a);
  perform public.admissions_link_student_account(student_record_b, student_b);
  perform public.admissions_link_student_account(student_record_c, student_c);
  perform public.admissions_verify_parent_student(student_record_a, parent_a);
  perform public.admissions_verify_parent_student(student_record_b, parent_b);
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', student_a::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.parent_student_links (parent_user_id, student_id, verified_at)
    values (parent_a, student_record_b, now());
    raise exception 'Direct parent-link insertion unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', student_a::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.students;
  if visible_count <> 1
    or not exists (select 1 from public.students where id = student_record_a)
    or exists (select 1 from public.students where id = student_record_b) then
    raise exception 'Student can see another student or cannot see their own record';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', parent_a::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.students;
  if visible_count <> 1
    or not exists (select 1 from public.students where id = student_record_a)
    or exists (select 1 from public.students where id = student_record_b) then
    raise exception 'Parent can see an unverified or unrelated student record';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', parent_b::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.students;
  if visible_count <> 1
    or not exists (select 1 from public.students where id = student_record_b)
    or exists (select 1 from public.students where id = student_record_a) then
    raise exception 'Parent can see a student without a verified relationship';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', teacher_a::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.students;
  if visible_count <> 3
    or not exists (select 1 from public.students where id = student_record_a)
    or not exists (select 1 from public.students where id = student_record_multi)
    or not exists (select 1 from public.students where id = student_record_unrelated)
    or exists (select 1 from public.students where id = student_record_b)
    or exists (select 1 from public.students where id = student_record_c) then
    raise exception 'Teacher access escaped their assigned class or branch';
  end if;
  if exists (select 1 from public.classes where id = class_b or id = class_c) then
    raise exception 'Teacher can see a class that is not assigned to them in their branch';
  end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', multi_role_user::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.students;
  if visible_count <> 2
    or not exists (select 1 from public.students where id = student_record_multi)
    or not exists (select 1 from public.students where id = student_record_b)
    or exists (select 1 from public.students where id = student_record_a)
    or exists (select 1 from public.students where id = student_record_unrelated)
    or exists (select 1 from public.students where id = student_record_c) then
    raise exception 'Multiple roles bypassed student ownership, class assignment, or branch scope';
  end if;
  execute 'reset role';
end;
$$;
rollback;
select 'Student and verified-parent RLS assertions passed; fixtures rolled back' as result;
