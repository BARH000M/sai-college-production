-- ISOLATED LOCAL SUPABASE ONLY. The runner sets the local marker.
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
  reception_id uuid := gen_random_uuid();
  teacher_id uuid := gen_random_uuid();
  other_id uuid;
  role_name text;
  branch_a uuid := gen_random_uuid();
  branch_b uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  class_a uuid;
  enquiry_id uuid;
  other_enquiry_id uuid;
  affected integer;
  found_count bigint;
  denied boolean;
  run_id text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into auth.users (id) values (super_id), (admin_id), (reception_id), (teacher_id);
  insert into public.user_roles (user_id, role) values
    (super_id, 'super_admin'), (admin_id, 'admin'),
    (reception_id, 'receptionist'), (teacher_id, 'teacher');
  insert into public.profiles (id, full_name) values
    (super_id, 'WAVE1_TEST_super'), (admin_id, 'WAVE1_TEST_admin'),
    (reception_id, 'WAVE1_TEST_reception'), (teacher_id, 'WAVE1_TEST_teacher');
  insert into public.branches (id, name, code) values
    (branch_a, 'WAVE1_TEST_a', 'WAVE1_TEST_' || run_id || '_a'),
    (branch_b, 'WAVE1_TEST_b', 'WAVE1_TEST_' || run_id || '_b');
  insert into public.academic_sessions (id, name, starts_on, ends_on)
    values (session_id, 'WAVE1_TEST_' || run_id, date '2031-01-01', date '2031-12-31');
  insert into public.branch_memberships (user_id, branch_id) values
    (admin_id, branch_a), (reception_id, branch_a), (teacher_id, branch_a);
  insert into public.classes (branch_id, session_id, name, program, teacher_id)
    values (branch_a, session_id, 'WAVE1_TEST_class', 'WAVE1_TEST_program', teacher_id) returning id into class_a;
  alter table public.audit_logs add constraint wave1_admissions_audit_failure
    check (current_setting('sai.admissions_block_audit', true) is distinct from 'yes');

  perform set_config('request.jwt.claim.sub', super_id::text, true);
  execute 'set local role authenticated';
  insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name, assigned_to)
    values (branch_a, session_id, 'WAVE1_TEST_applicant', teacher_id) returning id into enquiry_id;
  update public.admissions_enquiries set status = 'accepted' where id = enquiry_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Super admin could not update'; end if;
  select count(*) into found_count from public.audit_logs
    where entity_type = 'admissions_enquiries' and entity_id = enquiry_id
      and metadata ->> 'source' = 'sai_admissions_trigger';
  if found_count <> 2 then raise exception 'Expected insert and update audit rows'; end if;
  perform set_config('sai.admissions_block_audit', 'yes', true);
  denied := false;
  begin
    update public.admissions_enquiries set status = 'rejected' where id = enquiry_id;
  exception when check_violation then
    get stacked diagnostics role_name = constraint_name;
    if role_name <> 'wave1_admissions_audit_failure' then raise; end if;
    denied := true;
  end;
  perform set_config('sai.admissions_block_audit', 'no', true);
  if not denied or not exists (select 1 from public.admissions_enquiries where id = enquiry_id and status = 'accepted') then
    raise exception 'Audit failure did not roll back mutation';
  end if;
  denied := false;
  begin
    update public.admissions_enquiries set status = 'invalid' where id = enquiry_id;
  exception when check_violation then denied := true;
  end;
  if not denied then raise exception 'Invalid status accepted'; end if;
  select count(*) into found_count from public.audit_logs
    where entity_type = 'admissions_enquiries' and entity_id = enquiry_id
      and metadata ->> 'source' = 'sai_admissions_trigger';
  if found_count <> 2 then raise exception 'Failed update created audit row'; end if;
  denied := false;
  begin
    update public.admissions_enquiries set branch_id = branch_b where id = enquiry_id;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Immutable branch was writable'; end if;
  denied := false;
  begin
    update public.admissions_enquiries set created_by = admin_id where id = enquiry_id;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Immutable creator was writable'; end if;
  denied := false;
  begin
    update public.admissions_enquiries set application_no = 'WAVE1_TEST_modified' where id = enquiry_id;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Immutable application number was writable'; end if;
  insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
    values (branch_a, session_id, 'WAVE1_TEST_unassigned') returning id into other_enquiry_id;

  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  update public.admissions_enquiries set status = 'contacted' where id = enquiry_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Branch admin update denied'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
      values (branch_b, session_id, 'WAVE1_TEST_other_branch');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Cross-branch admin insert accepted'; end if;

  -- The receptionist has no session access under the existing session SELECT
  -- policy; add an independently authorized teacher role to test write scope.
  execute 'reset role';
  insert into public.user_roles (user_id, role) values (reception_id, 'teacher');
  update public.classes set teacher_id = reception_id where id = class_a;
  perform set_config('request.jwt.claim.sub', reception_id::text, true);
  execute 'set local role authenticated';
  insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
    values (branch_a, session_id, 'WAVE1_TEST_reception');
  update public.admissions_enquiries set notes = 'WAVE1_TEST_note' where id = enquiry_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Receptionist update denied'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
      values (branch_b, session_id, 'WAVE1_TEST_cross_scope');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Cross-branch receptionist insert accepted'; end if;

  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  select count(*) into found_count from public.admissions_enquiries where id = enquiry_id;
  if found_count <> 1 then raise exception 'Assigned teacher cannot read enquiry'; end if;
  select count(*) into found_count from public.admissions_enquiries where id = other_enquiry_id;
  if found_count <> 0 then raise exception 'Teacher read an unassigned enquiry'; end if;
  denied := false;
  begin
    perform public.sai_admissions_staff(branch_a);
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Teacher accessed staff directory'; end if;
  update public.admissions_enquiries set notes = 'WAVE1_TEST_denied' where id = enquiry_id;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Teacher updated enquiry'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
      values (branch_a, session_id, 'WAVE1_TEST_denied');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Teacher inserted enquiry'; end if;
  execute 'reset role';

  foreach role_name in array array['student','parent','accountant','librarian','content_editor']
  loop
    other_id := gen_random_uuid();
    insert into auth.users (id) values (other_id);
    insert into public.user_roles (user_id, role) values (other_id, role_name::public.app_role);
    insert into public.branch_memberships (user_id, branch_id) values (other_id, branch_a);
    perform set_config('request.jwt.claim.sub', other_id::text, true);
    execute 'set local role authenticated';
    select count(*) into found_count from public.admissions_enquiries where id = enquiry_id;
    if found_count <> 0 then raise exception '% read enquiry', role_name; end if;
    denied := false;
    begin
      insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
        values (branch_a, session_id, 'WAVE1_TEST_denied');
    exception when insufficient_privilege then denied := true;
    end;
    if not denied then raise exception '% inserted enquiry', role_name; end if;
    execute 'reset role';
  end loop;
end;
$$;
rollback;
select 'Admissions isolated authorization assertions passed; fixtures rolled back' as result;
