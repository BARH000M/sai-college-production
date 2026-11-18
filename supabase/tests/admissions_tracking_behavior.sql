-- ISOLATED LOCAL DATABASE ONLY. Verifies public tracking protections and
-- authorized student/parent account linking after migrations 001 through 032.
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
  admin_id uuid := gen_random_uuid();
  receptionist_id uuid := gen_random_uuid();
  student_account_id uuid := gen_random_uuid();
  unverified_account_id uuid := gen_random_uuid();
  parent_id uuid := gen_random_uuid();
  branch_id uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  result jsonb;
  reference text;
  token text;
  status_result jsonb;
  history_result jsonb;
  student_id uuid;
  student_id_text text;
  denied boolean;
  allowed boolean;
  i integer;
  client_key text := encode(pg_catalog.sha256(convert_to(gen_random_uuid()::text, 'UTF8')), 'hex');
  run_id text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into auth.users (id, email_confirmed_at)
  values
    (super_id, now()), (admin_id, now()), (receptionist_id, now()),
    (student_account_id, now()), (parent_id, now());
  insert into auth.users (id) values (unverified_account_id);
  insert into public.user_roles (user_id, role)
  values
    (super_id, 'super_admin'), (admin_id, 'admin'),
    (receptionist_id, 'receptionist'), (parent_id, 'parent');
  insert into public.profiles (id, full_name, email)
  values
    (super_id, 'TRACK_TEST_super', 'TRACK_TEST_super@example.test'),
    (admin_id, 'TRACK_TEST_admin', 'TRACK_TEST_admin@example.test'),
    (receptionist_id, 'TRACK_TEST_reception', 'TRACK_TEST_reception@example.test'),
    (parent_id, 'TRACK_TEST_parent', 'TRACK_TEST_parent@example.test');
  -- Public submission chooses the oldest active branch. Keep this fixture
  -- deterministic when the Main replay already contains synthetic branches.
  insert into public.branches (id, name, code, is_active, created_at)
  values (branch_id, 'TRACK_TEST_' || run_id, 'TRACK_TEST_' || run_id, true, '1900-01-01');
  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
  values (session_id, 'TRACK_TEST_' || run_id, date '2031-01-01', date '2031-12-31', true);
  insert into public.branch_memberships (user_id, branch_id)
  values (admin_id, branch_id), (receptionist_id, branch_id);

  if has_function_privilege('anon', 'public.admissions_public_submit(text,text,text,text,text)', 'execute')
    or has_function_privilege('authenticated', 'public.admissions_public_submit(text,text,text,text,text)', 'execute')
    or has_function_privilege('anon', 'public.admissions_public_status(text,text)', 'execute')
    or has_function_privilege('authenticated', 'public.admissions_public_status(text,text)', 'execute')
    or has_function_privilege('anon', 'public.admissions_public_history(text,text)', 'execute')
    or has_function_privilege('authenticated', 'public.admissions_public_history(text,text)', 'execute') then
    raise exception 'Public tracking RPC is directly executable by an untrusted role';
  end if;
  if not has_function_privilege('service_role', 'public.admissions_public_submit(text,text,text,text,text)', 'execute')
    or not has_function_privilege('service_role', 'public.admissions_public_status(text,text)', 'execute')
    or not has_function_privilege('service_role', 'public.admissions_public_history(text,text)', 'execute') then
    raise exception 'Service role lost public tracking RPC access';
  end if;
  if to_regprocedure('public.sai_public_admission_status(text)') is not null
    and has_function_privilege('anon', 'public.sai_public_admission_status(text)', 'execute') then
    raise exception 'Legacy public status RPC is still executable by anon';
  end if;
  if to_regprocedure('public.sai_public_admission_history(text)') is not null
    and has_function_privilege('authenticated', 'public.sai_public_admission_history(text)', 'execute') then
    raise exception 'Legacy public history RPC is still executable by authenticated';
  end if;

  execute 'set local role service_role';
  select public.admissions_public_submit(
    'TRACK_TEST_applicant', '777123456', 'applicant@example.test', 'Chinese', 'Tracking test'
  ) into result;
  execute 'reset role';
  reference := result ->> 'reference';
  token := result ->> 'tracking_token';
  if reference is null or token is null or token !~ '^[0-9a-f]{64}$' then
    raise exception 'Submission did not return a reference and 256-bit tracking token';
  end if;
  if exists (
    select 1 from private.admission_tracking_tokens
    where enquiry_id = (select id from public.admissions_enquiries where application_no = reference)
      and token_hash = convert_to(token, 'UTF8')
  ) then
    raise exception 'Tracking token was stored in plaintext';
  end if;
  if not exists (
    select 1 from private.admission_tracking_tokens
    where enquiry_id = (select id from public.admissions_enquiries where application_no = reference)
      and token_hash = pg_catalog.sha256(convert_to(token, 'UTF8'))
  ) then
    raise exception 'Server-side tracking token hash is missing or incorrect';
  end if;

  execute 'set local role service_role';
  select public.admissions_public_status(reference, repeat('0', 64)) into status_result;
  if status_result is not null then raise exception 'Wrong tracking token revealed an application'; end if;
  select public.admissions_public_status(reference, token) into status_result;
  select public.admissions_public_history(reference, token) into history_result;
  for i in 1..6 loop
    select public.admissions_public_rate_limit(client_key, 'submit') into allowed;
    if allowed is distinct from (i <= 5) then
      raise exception 'Submission rate limit did not enforce the configured threshold';
    end if;
  end loop;
  execute 'reset role';

  if status_result is null
    or (select count(*) from jsonb_object_keys(status_result)) <> 3
    or status_result ?| array['applicant_full_name', 'email', 'phone', 'branch', 'session'] then
    raise exception 'Public status response included PII or an invalid shape';
  end if;
  if history_result is null or jsonb_typeof(history_result) <> 'array'
    or history_result = '[]'::jsonb
    or (history_result -> 0) ?| array['applicant_full_name', 'email', 'phone', 'actor_name'] then
    raise exception 'Public history response was empty or included PII';
  end if;

  perform set_config('request.jwt.claim.sub', super_id::text, true);
  execute 'set local role authenticated';
  perform public.sai_admissions_set_status(
    (select id from public.admissions_enquiries where application_no = reference),
    'accepted'
  );
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  select public.sai_admissions_enroll(
    (select id from public.admissions_enquiries where application_no = reference)
  ) ->> 'student_id' into student_id_text;
  student_id := student_id_text::uuid;
  perform public.admissions_link_student_account(student_id, student_account_id);
  execute 'reset role';
  if not exists (
    select 1 from public.students
    where id = student_id and user_id = student_account_id
  ) or not exists (
    select 1 from public.user_roles
    where user_id = student_account_id and role = 'student'
  ) then
    raise exception 'Authorized staff did not link the verified student account';
  end if;

  execute 'set local role authenticated';
  denied := false;
  begin
    perform public.admissions_link_student_account(student_id, unverified_account_id);
  exception when invalid_parameter_value then denied := true;
  end;
  if not denied then raise exception 'Unverified Auth account was linked to a student'; end if;
  perform public.admissions_verify_parent_student(student_id, parent_id);

  denied := false;
  begin
    update public.students set user_id = null where id = student_id;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Direct student account unlink bypassed the guarded RPC'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', receptionist_id::text, true);
  execute 'set local role authenticated';
  denied := false;
  begin
    perform public.admissions_unlink_student_account(student_id);
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Receptionist bypassed administrator account-link permissions'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', parent_id::text, true);
  execute 'set local role authenticated';
  if (select count(*) from public.students) <> 1
    or not exists (select 1 from public.students where id = student_id) then
    raise exception 'Verified parent cannot read the linked student record';
  end if;
  execute 'reset role';
end;
$$;
rollback;
select 'Admission tracking and verified account-link assertions passed; fixtures rolled back' as result;
