-- ISOLATED LOCAL SUPABASE ONLY. Never run this script on a linked database.
-- All fixtures are transaction-local and are rolled back even on failure.
begin;

do $$
begin
  if current_setting('sai.wave1_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

create temporary table wave1_test_results (test_name text not null, passed boolean not null);
grant insert, select on wave1_test_results to authenticated;

alter table public.audit_logs add constraint wave1_test_reject_audit
  check (current_setting('sai.wave1_block_audit', true) is distinct from 'yes');

do $$
declare
  super_id uuid := gen_random_uuid();
  admin_id uuid := gen_random_uuid();
  role_id uuid;
  role_name text;
  table_name text;
  branch_a uuid;
  branch_b uuid;
  session_id uuid;
  class_id uuid;
  student_id uuid;
  admin_class_id uuid;
  admin_student_id uuid;
  audit_before bigint;
  audit_after bigint;
  affected integer;
  denied boolean;
  run_id text := replace(gen_random_uuid()::text, '-', '');
  row_name text;
begin
  insert into auth.users (id) values (super_id), (admin_id);
  insert into public.user_roles (user_id, role)
    values (super_id, 'super_admin'), (admin_id, 'admin');

  perform set_config('request.jwt.claim.sub', super_id::text, true);
  execute 'set local role authenticated';

  row_name := 'WAVE1_TEST_' || run_id || '_branch_a';
  insert into public.branches (name, code) values (row_name, row_name) returning id into branch_a;
  update public.branches set name = row_name || '_edited' where id = branch_a;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'super_admin branch update failed'; end if;
  insert into wave1_test_results values ('super_admin branch create and edit', true);

  row_name := 'WAVE1_TEST_' || run_id || '_branch_b';
  insert into public.branches (name, code) values (row_name, row_name) returning id into branch_b;
  row_name := 'WAVE1_TEST_' || run_id || '_session';
  insert into public.academic_sessions (name, starts_on, ends_on)
    values (row_name, date '2031-01-01', date '2031-12-31') returning id into session_id;
  update public.academic_sessions set name = row_name || '_edited' where id = session_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'super_admin session update failed'; end if;
  insert into wave1_test_results values ('super_admin session create and edit', true);

  insert into public.classes (branch_id, session_id, name, program, capacity)
    values (branch_a, session_id, 'WAVE1_TEST_' || run_id || '_class', 'WAVE1_TEST_program', 10)
    returning id into class_id;
  update public.classes set capacity = 11 where id = class_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'super_admin class update failed'; end if;
  insert into public.students (branch_id, admission_no, full_name, class_id)
    values (branch_a, 'WAVE1_TEST_' || run_id, 'WAVE1_TEST_' || run_id || '_student', class_id)
    returning id into student_id;
  update public.students set full_name = 'WAVE1_TEST_' || run_id || '_student_edited' where id = student_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'super_admin student update failed'; end if;
  insert into wave1_test_results values ('super_admin class and student create and edit', true);

  select count(*) into audit_before from public.audit_logs
    where actor_user_id = super_id and entity_id in (branch_a, session_id, class_id, student_id)
      and metadata ->> 'source' = 'sai_management_trigger';
  if audit_before <> 8 then
    raise exception 'Expected eight insert/update audit entries, got %', audit_before;
  end if;
  insert into wave1_test_results values ('successful operations produce audit rows', true);

  denied := false;
  begin
    insert into public.students (branch_id, admission_no, full_name, class_id)
      values (branch_b, 'WAVE1_TEST_' || run_id || '_invalid',
        'WAVE1_TEST_' || run_id || '_invalid', class_id);
  exception when others then
    if sqlerrm <> 'Invalid class or branch' then raise; end if;
    denied := true;
  end;
  if not denied then raise exception 'Invalid cross-branch assignment was accepted'; end if;
  select count(*) into audit_after from public.audit_logs
    where actor_user_id = super_id and metadata ->> 'source' = 'sai_management_trigger';
  if audit_after <> audit_before + 1 then
    -- One additional entry belongs to branch_b.
    raise exception 'Failed operation changed audit row count';
  end if;
  insert into wave1_test_results values ('failed mutation leaves no audit row', true);

  perform set_config('sai.wave1_block_audit', 'yes', true);
  denied := false;
  row_name := 'WAVE1_TEST_' || run_id || '_audit_failure';
  begin
    insert into public.branches (name, code) values (row_name, row_name);
  exception when check_violation then
    get stacked diagnostics row_name = constraint_name;
    if row_name <> 'wave1_test_reject_audit' then raise; end if;
    denied := true;
  end;
  perform set_config('sai.wave1_block_audit', 'no', true);
  if not denied or exists (select 1 from public.branches where code = 'WAVE1_TEST_' || run_id || '_audit_failure') then
    raise exception 'Mutation persisted after audit failure';
  end if;
  select count(*) into audit_after from public.audit_logs
    where actor_user_id = super_id and metadata ->> 'source' = 'sai_management_trigger';
  if audit_after <> audit_before + 1 then raise exception 'Audit failure created a row'; end if;
  insert into wave1_test_results values ('audit failure rolls back mutation atomically', true);

  insert into public.branch_memberships (user_id, branch_id) values (admin_id, branch_a);
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  update public.branches set name = 'WAVE1_TEST_' || run_id || '_admin_edit' where id = branch_a;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin could not update assigned branch'; end if;
  update public.branches set name = 'WAVE1_TEST_' || run_id || '_unauthorized' where id = branch_b;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Admin updated another branch'; end if;
  insert into public.classes (branch_id, session_id, name, program)
    values (branch_a, session_id, 'WAVE1_TEST_' || run_id || '_admin_class', 'WAVE1_TEST_program')
    returning id into admin_class_id;
  insert into public.students (branch_id, admission_no, full_name, class_id)
    values (branch_a, 'WAVE1_TEST_' || run_id || '_admin_student',
      'WAVE1_TEST_' || run_id || '_admin_student', admin_class_id)
    returning id into admin_student_id;
  update public.classes set capacity = 21 where id = admin_class_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin could not update assigned-branch class'; end if;
  update public.students set full_name = 'WAVE1_TEST_' || run_id || '_admin_student_edited' where id = admin_student_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin could not update assigned-branch student'; end if;
  denied := false;
  begin
    insert into public.classes (branch_id, session_id, name, program)
      values (branch_b, session_id, 'WAVE1_TEST_' || run_id || '_admin_other_class', 'WAVE1_TEST_program');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Admin inserted class into another branch'; end if;
  denied := false;
  begin
    insert into public.students (branch_id, admission_no, full_name)
      values (branch_b, 'WAVE1_TEST_' || run_id || '_admin',
        'WAVE1_TEST_' || run_id || '_admin');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Admin inserted student into another branch'; end if;
  update public.academic_sessions set name = 'WAVE1_TEST_unauthorized' where id = session_id;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Admin updated a global session'; end if;
  insert into wave1_test_results values ('admin assigned branch scope', true);

  execute 'reset role';
  foreach role_name in array array['teacher','student','parent','librarian',
    'accountant','receptionist','content_editor']
  loop
    role_id := gen_random_uuid();
    insert into auth.users (id) values (role_id);
    insert into public.user_roles (user_id, role) values (role_id, role_name::public.app_role);
    insert into public.branch_memberships (user_id, branch_id) values (role_id, branch_a);
    if role_name = 'teacher' then
      update public.classes set teacher_id = role_id where id = class_id;
    elsif role_name = 'student' then
      update public.students set user_id = role_id where id = student_id;
    elsif role_name = 'parent' then
      insert into public.parent_student_links (parent_user_id, student_id, verified_at)
        values (role_id, student_id, now());
    end if;
    perform set_config('request.jwt.claim.sub', role_id::text, true);
    execute 'set local role authenticated';
    foreach table_name in array array['branches','academic_sessions','classes','students','branch_memberships']
    loop
      denied := false;
      begin
        case table_name
          when 'branches' then
            insert into public.branches (name, code)
              values ('WAVE1_TEST_' || run_id || '_' || role_name, 'WAVE1_TEST_' || run_id || '_' || role_name);
          when 'academic_sessions' then
            insert into public.academic_sessions (name, starts_on, ends_on)
              values ('WAVE1_TEST_' || run_id || '_' || role_name, date '2031-01-01', date '2031-12-31');
          when 'classes' then
            insert into public.classes (branch_id, session_id, name, program)
              values (branch_a, session_id, 'WAVE1_TEST_' || run_id || '_' || role_name, 'WAVE1_TEST_program');
          when 'students' then
            insert into public.students (branch_id, admission_no, full_name)
              values (branch_a, 'WAVE1_TEST_' || run_id || '_' || role_name, 'WAVE1_TEST_' || run_id || '_' || role_name);
          when 'branch_memberships' then
            insert into public.branch_memberships (user_id, branch_id) values (role_id, branch_b);
        end case;
      exception when insufficient_privilege then denied := true;
      end;
      if not denied then raise exception '% inserted into %', role_name, table_name; end if;
      case table_name
        when 'branches' then update public.branches set name = 'WAVE1_TEST_unauthorized' where id = branch_a;
        when 'academic_sessions' then update public.academic_sessions set name = 'WAVE1_TEST_unauthorized' where id = session_id;
        when 'classes' then update public.classes set name = 'WAVE1_TEST_unauthorized' where id = class_id;
        when 'students' then update public.students set full_name = 'WAVE1_TEST_unauthorized' where id = student_id;
        when 'branch_memberships' then update public.branch_memberships set is_active = false where user_id = role_id and branch_id = branch_a;
      end case;
      get diagnostics affected = row_count;
      if affected <> 0 then raise exception '% updated %', role_name, table_name; end if;
    end loop;
    insert into wave1_test_results values (role_name || ' denied management writes', true);
    execute 'reset role';
  end loop;

  -- Exercise the browser role grant boundary for all nine assigned roles.
  for role_id, role_name in select user_id, role from public.user_roles
    where user_id in (super_id, admin_id) or user_id in (
      select u.id from auth.users u
      where u.id in (select m.user_id from public.branch_memberships m where m.branch_id = branch_a)
    )
  loop
    perform set_config('request.jwt.claim.sub', role_id::text, true);
    execute 'set local role authenticated';
    denied := false;
    begin
      insert into public.user_roles (user_id, role) values (role_id, 'super_admin');
    exception when insufficient_privilege then denied := true;
    end;
    if not denied then raise exception '% could assign super_admin', role_name; end if;
    insert into wave1_test_results values (role_name::text || ' denied role assignment', true);
    execute 'reset role';
  end loop;

  perform set_config('request.jwt.claim.sub', super_id::text, true);
  execute 'set local role authenticated';
  update public.students set status = 'inactive' where id = student_id;
  update public.students set status = 'inactive' where id = admin_student_id;
  update public.classes set is_active = false where id = class_id;
  update public.classes set is_active = false where id = admin_class_id;
  update public.academic_sessions set is_active = false where id = session_id;
  update public.branch_memberships set is_active = false where branch_id = branch_a;
  update public.branches set is_active = false where id in (branch_a, branch_b);
  if not exists (select 1 from public.students where id = student_id and status = 'inactive')
    or not exists (select 1 from public.classes where id = class_id and not is_active)
    or not exists (select 1 from public.students where id = admin_student_id and status = 'inactive')
    or not exists (select 1 from public.classes where id = admin_class_id and not is_active)
    or not exists (select 1 from public.branches where id = branch_a and not is_active)
    or not exists (select 1 from public.academic_sessions where id = session_id and not is_active) then
    raise exception 'Deactivated rows are not queryable';
  end if;
  insert into wave1_test_results values ('deactivation retains records', true);
  execute 'reset role';
  select count(*) into affected from wave1_test_results where passed;
  if affected <> 24 then raise exception 'Expected 24 test assertions, got %', affected; end if;
end;
$$;

rollback;
select '24 local transactional authorization assertions passed; all fixtures rolled back' as result;
