-- ISOLATED DATABASE ONLY. Requires 20261120120000_role_management_and_hold_infrastructure.sql
-- AND a Supabase-shaped schema (auth.users, public.app_role, branches, user_roles,
-- branch_memberships, profiles, audit_logs, private). It therefore cannot run on the bare
-- initdb cluster used by supabase/tests/run_native_contracts.py — run it against a local
-- Supabase database or a restored clone, e.g.
--   PGOPTIONS='-c sai.role_and_hold_forward_test=yes' psql -X -v ON_ERROR_STOP=1 -f <this file>
-- Never run against Main.
-- Marker-guarded: refuses to run unless the operator sets sai.role_and_hold_forward_test = 'yes'.
-- Every fixture is rolled back at the end; nothing here may run against Main.
begin;
do $$
begin
  if current_setting('sai.role_and_hold_forward_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  actor_id uuid := gen_random_uuid();
  target_id uuid := gen_random_uuid();
  outsider_id uuid := gen_random_uuid();
  banned_admin_id uuid := gen_random_uuid();
  deleted_admin_id uuid := gen_random_uuid();
  unconfirmed_admin_id uuid := gen_random_uuid();
  selected_branch uuid := gen_random_uuid();
  other_branch uuid := gen_random_uuid();
  inactive_branch uuid := gen_random_uuid();
  run_id text := replace(gen_random_uuid()::text, '-', '');
  branch_count bigint;
  role_count bigint;
  audit_count bigint;
  hold_count bigint;
  lock_count bigint;
begin
  -- ---------------------------------------------------------------- fixtures
  insert into auth.users (id, email, email_confirmed_at)
  values
    (actor_id, 'fwd_actor_' || run_id || '@example.test', now()),
    (target_id, 'fwd_target_' || run_id || '@example.test', now()),
    (outsider_id, 'fwd_outsider_' || run_id || '@example.test', now()),
    (banned_admin_id, 'fwd_banned_' || run_id || '@example.test', now()),
    (deleted_admin_id, 'fwd_deleted_' || run_id || '@example.test', now()),
    (unconfirmed_admin_id, 'fwd_unconfirmed_' || run_id || '@example.test', null);

  update auth.users set banned_until = now() + interval '1 day' where id = banned_admin_id;
  update auth.users set deleted_at = now() where id = deleted_admin_id;

  insert into public.user_roles (user_id, role)
  values (actor_id, 'super_admin'), (outsider_id, 'student');

  insert into public.branches (id, name, code, is_active)
  values
    (selected_branch, 'FWD_SELECTED_' || run_id, 'FWD_A_' || run_id, true),
    (other_branch, 'FWD_OTHER_' || run_id, 'FWD_B_' || run_id, true),
    (inactive_branch, 'FWD_INACTIVE_' || run_id, 'FWD_C_' || run_id, false);

  -- ------------------------------------------- hold infrastructure installed OFF
  select count(*) into hold_count
  from private.sai_mutation_hold_state
  where singleton and enabled is false;
  if hold_count <> 1 then
    raise exception 'Mutation hold is not installed disabled';
  end if;

  perform public.sai_assert_mutations_enabled();

  -- Normal authorized operation with the hold OFF must still write.
  insert into public.branches (id, name, code, is_active)
  values (gen_random_uuid(), 'FWD_WRITE_' || run_id, 'FWD_W_' || run_id, true);

  -- --------------------------------------------------- privilege surface checks
  if has_function_privilege(
    'authenticated',
    'public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)',
    'execute'
  ) or has_function_privilege(
    'anon',
    'public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)',
    'execute'
  ) then
    raise exception 'Role management RPC is executable by a browser role';
  end if;

  if not has_function_privilege(
    'service_role',
    'public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)',
    'execute'
  ) then
    raise exception 'Role management RPC is not executable by service_role';
  end if;

  if not has_function_privilege(
    'service_role',
    'public.sai_assert_mutations_enabled()',
    'execute'
  ) then
    raise exception 'Mutation gate is not executable by service_role';
  end if;

  execute 'set local role service_role';

  -- ------------------------------------------------- authorization: not a Super Admin
  begin
    perform public.sai_manage_role_assignment(
      outsider_id, target_id, 'grant', 'teacher', array[selected_branch],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'A non Super Admin actor was unexpectedly accepted';
  exception when insufficient_privilege then
    null;
  end;

  -- -------------------------------------------------- staff grant + branch scope
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'teacher', array[selected_branch],
    true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
  );

  select count(*) into branch_count
  from public.branch_memberships
  where user_id = target_id and is_active;
  if branch_count <> 1 or not exists (
    select 1 from public.branch_memberships
    where user_id = target_id and branch_id = selected_branch and is_active
  ) then
    raise exception 'Staff grant did not scope the account to the selected branch';
  end if;

  -- The transaction-scoped advisory lock must be held (concurrency serialization).
  select count(*) into lock_count
  from pg_locks
  where locktype = 'advisory' and classid = 831704 and objid = 1;
  if lock_count < 1 then
    raise exception 'Role mutations are not serialized by the advisory lock';
  end if;

  -- ----------------------------------------------- multi-role support preserved
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'student', array[]::uuid[],
    true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
  );
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'revoke', 'student', array[]::uuid[],
    true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
  );

  select count(*) into role_count
  from public.user_roles
  where user_id = target_id and role = 'teacher';
  select count(*) into branch_count
  from public.branch_memberships
  where user_id = target_id and is_active;
  if role_count <> 1 or branch_count <> 1 then
    raise exception 'Removing a non-staff role dropped the remaining staff scope';
  end if;

  -- -------------------------------------------------- escalation guards
  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'accountant', array[inactive_branch],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Inactive branch was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'student', array[]::uuid[],
      false, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Unverified email was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'super_admin', array[]::uuid[],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Unconfirmed Super Admin grant was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'teacher', array[selected_branch],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Duplicate role was unexpectedly accepted';
  exception when unique_violation then
    null;
  end;

  -- -------------------------------------------------- last usable Super Admin
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'super_admin', array[]::uuid[],
    true, true, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
  );

  -- Two usable Super Admins: the target may revoke the actor.
  perform public.sai_manage_role_assignment(
    target_id, actor_id, 'revoke', 'super_admin', array[]::uuid[],
    true, false, 'fwd_actor_' || run_id || '@example.test', 'Forward Test Actor'
  );

  begin
    perform public.sai_manage_role_assignment(
      target_id, target_id, 'revoke', 'super_admin', array[]::uuid[],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Last Super Admin revocation was unexpectedly accepted';
  exception when check_violation then
    null;
  end;

  -- Unusable Super Admin rows must not count as protection.
  insert into public.user_roles (user_id, role, assigned_by)
  values
    (banned_admin_id, 'super_admin', target_id),
    (deleted_admin_id, 'super_admin', target_id),
    (unconfirmed_admin_id, 'super_admin', target_id);

  begin
    perform public.sai_manage_role_assignment(
      target_id, target_id, 'revoke', 'super_admin', array[]::uuid[],
      true, false, 'fwd_target_' || run_id || '@example.test', 'Forward Test User'
    );
    raise exception 'Unusable Super Admins were counted as revocation protection';
  exception when check_violation then
    null;
  end;

  -- An unusable Super Admin can still be removed while a usable one remains.
  perform public.sai_manage_role_assignment(
    target_id, banned_admin_id, 'revoke', 'super_admin', array[]::uuid[],
    true, false, 'fwd_banned_' || run_id || '@example.test', 'Forward Test Banned'
  );

  -- -------------------------------------------- hold activation and release
  execute 'reset role';

  update private.sai_mutation_hold_state
  set enabled = true, changed_at = now(), reason = 'isolated hold activation test'
  where singleton;

  begin
    perform public.sai_assert_mutations_enabled();
    raise exception 'An active mutation hold did not reject the operation';
  exception when sqlstate '55000' then
    null;
  end;

  begin
    insert into public.branches (id, name, code, is_active)
    values (gen_random_uuid(), 'FWD_BLOCKED_' || run_id, 'FWD_X_' || run_id, true);
    raise exception 'An active mutation hold did not block a table write';
  exception when sqlstate '55000' then
    null;
  end;

  -- The package revokes every privilege on private.sai_mutation_hold_state, so only the
  -- reviewed super-admin RPC can move the hold. A direct service_role write must fail.
  execute 'set local role service_role';
  begin
    update private.sai_mutation_hold_state
    set enabled = false, changed_at = now(), reason = 'illegal direct release attempt';
    raise exception 'service_role modified the mutation hold state directly';
  exception when insufficient_privilege then
    null;
  end;
  execute 'reset role';

  -- Release as the package owner, matching the reviewed maintenance procedure.
  update private.sai_mutation_hold_state
  set enabled = false, changed_at = now(), reason = 'isolated hold release test'
  where singleton;

  perform public.sai_assert_mutations_enabled();
  insert into public.branches (id, name, code, is_active)
  values (gen_random_uuid(), 'FWD_REOPENED_' || run_id, 'FWD_R_' || run_id, true);

  -- ------------------------------------------------------- audit integrity
  select count(*) into audit_count
  from public.audit_logs
  where entity_id in (actor_id, target_id, banned_admin_id)
    and action in ('role_grant', 'role_revoke');
  -- Exactly six calls reach the audit insert; every other call raises before it:
  --   1 grant teacher        2 grant student       3 revoke student
  --   4 grant super_admin    5 revoke super_admin (actor)   6 revoke super_admin (banned)
  -- Rejected calls (non-admin actor, inactive branch, unverified email, unconfirmed
  -- super_admin, duplicate role, twice-protected last admin) roll back in their own
  -- subtransaction and must leave no audit row behind.
  if audit_count <> 6 then
    raise exception 'Expected 6 transactional role audit rows, found %', audit_count;
  end if;

  select count(*) into role_count
  from public.user_roles
  where user_id = target_id and role = 'super_admin';
  if role_count <> 1 then
    raise exception 'Super Admin role state is inconsistent after the guard checks';
  end if;
end;
$$;

rollback;
select 'Role management authorization, branch scope, multi-role, last-admin, advisory-lock, audit, and hold on/off assertions passed; fixtures rolled back' as result;