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
  parent_a uuid := gen_random_uuid();
  parent_b uuid := gen_random_uuid();
  branch_id uuid := gen_random_uuid();
  student_record_a uuid := gen_random_uuid();
  student_record_b uuid := gen_random_uuid();
  run_id text := replace(gen_random_uuid()::text, '-', '');
  visible_count bigint;
begin
  insert into auth.users (id)
  values (super_id), (student_a), (student_b), (parent_a), (parent_b);
  insert into public.user_roles (user_id, role)
  values (super_id, 'super_admin'), (student_a, 'student'), (student_b, 'student'),
         (parent_a, 'parent'), (parent_b, 'parent');
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  insert into public.branches (id, name, code)
  values (branch_id, 'RLS_TEST_' || run_id, 'RLS_TEST_' || run_id);
  insert into public.students (id, user_id, branch_id, admission_no, full_name)
  values
    (student_record_a, student_a, branch_id, 'RLS_TEST_A_' || run_id, 'RLS_TEST_student_a'),
    (student_record_b, student_b, branch_id, 'RLS_TEST_B_' || run_id, 'RLS_TEST_student_b');
  insert into public.parent_student_links (parent_user_id, student_id, verified_at)
  values
    (parent_a, student_record_a, now()),
    (parent_a, student_record_b, null),
    (parent_b, student_record_b, now());

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
end;
$$;
rollback;
select 'Student and verified-parent RLS assertions passed; fixtures rolled back' as result;
