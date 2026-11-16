-- ISOLATED LOCAL DATABASE ONLY. Requires the local role-management proposal.
begin;
do $$
begin
  if current_setting('sai.role_management_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  actor_id uuid := gen_random_uuid();
  target_id uuid := gen_random_uuid();
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
begin
  insert into auth.users (id, email, email_confirmed_at)
  values
    (actor_id, 'role_actor_' || run_id || '@example.test', now()),
    (target_id, 'role_target_' || run_id || '@example.test', now()),
    (banned_admin_id, 'role_banned_' || run_id || '@example.test', now()),
    (deleted_admin_id, 'role_deleted_' || run_id || '@example.test', now()),
    (unconfirmed_admin_id, 'role_unconfirmed_' || run_id || '@example.test', null);

  update auth.users set banned_until = now() + interval '1 day' where id = banned_admin_id;
  update auth.users set deleted_at = now() where id = deleted_admin_id;

  insert into public.user_roles (user_id, role)
  values (actor_id, 'super_admin');

  insert into public.branches (id, name, code, is_active)
  values
    (selected_branch, 'ROLE_TEST_SELECTED_' || run_id, 'ROLE_TEST_A_' || run_id, true),
    (other_branch, 'ROLE_TEST_OTHER_' || run_id, 'ROLE_TEST_B_' || run_id, true),
    (inactive_branch, 'ROLE_TEST_INACTIVE_' || run_id, 'ROLE_TEST_C_' || run_id, false);

  insert into public.branch_memberships (user_id, branch_id, is_active)
  values (actor_id, other_branch, true);

  execute 'set local role service_role';
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'teacher', array[selected_branch],
    true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
  );

  select count(*) into branch_count
  from public.branch_memberships
  where user_id = target_id and is_active;
  if branch_count <> 1 or not exists (
    select 1 from public.branch_memberships
    where user_id = target_id and branch_id = selected_branch and is_active
  ) then
    raise exception 'Staff grant did not use only the selected branch';
  end if;

  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'student', array[]::uuid[],
    true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
  );
  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'revoke', 'student', array[]::uuid[],
    true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
  );

  select count(*) into branch_count
  from public.branch_memberships
  where user_id = target_id and is_active;
  select count(*) into role_count
  from public.user_roles
  where user_id = target_id and role = 'teacher';
  if branch_count <> 1 or role_count <> 1 then
    raise exception 'A multi-role change removed the remaining staff role scope';
  end if;

  perform public.sai_manage_role_assignment(
    actor_id, actor_id, 'grant', 'student', array[]::uuid[],
    true, false, 'role_actor_' || run_id || '@example.test', 'Role Test Actor'
  );
  perform public.sai_manage_role_assignment(
    actor_id, actor_id, 'revoke', 'student', array[]::uuid[],
    true, false, 'role_actor_' || run_id || '@example.test', 'Role Test Actor'
  );
  if not exists (
    select 1 from public.branch_memberships
    where user_id = actor_id and branch_id = other_branch and is_active
  ) then
    raise exception 'Revoking a non-staff role removed unrelated branch membership';
  end if;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'accountant', array[inactive_branch],
      true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Inactive branch was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'student', array[]::uuid[],
      false, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Unverified email was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'student', array[]::uuid[],
      null, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Null email confirmation was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'super_admin', array[]::uuid[],
      true, null, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Null Super Admin confirmation was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'teacher', array[selected_branch],
      true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Duplicate role was unexpectedly accepted';
  exception when unique_violation then
    null;
  end;

  begin
    perform public.sai_manage_role_assignment(
      actor_id, target_id, 'grant', 'super_admin', array[]::uuid[],
      true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Unconfirmed Super Admin grant was unexpectedly accepted';
  exception when sqlstate '22023' then
    null;
  end;

  perform public.sai_manage_role_assignment(
    actor_id, target_id, 'grant', 'super_admin', array[]::uuid[],
    true, true, 'role_target_' || run_id || '@example.test', 'Role Test User'
  );
  perform public.sai_manage_role_assignment(
    actor_id, actor_id, 'revoke', 'super_admin', array[]::uuid[],
    true, false, 'role_actor_' || run_id || '@example.test', 'Role Test Actor'
  );

  begin
    perform public.sai_manage_role_assignment(
      target_id, target_id, 'revoke', 'super_admin', array[]::uuid[],
      true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Last Super Admin revocation was unexpectedly accepted';
  exception when check_violation then
    null;
  end;

  -- Banned, deleted, or email-unconfirmed Super Admins must not count as
  -- usable protection for the last usable one.
  insert into public.user_roles (user_id, role, assigned_by)
  values
    (banned_admin_id, 'super_admin', target_id),
    (deleted_admin_id, 'super_admin', target_id),
    (unconfirmed_admin_id, 'super_admin', target_id);

  begin
    perform public.sai_manage_role_assignment(
      target_id, target_id, 'revoke', 'super_admin', array[]::uuid[],
      true, false, 'role_target_' || run_id || '@example.test', 'Role Test User'
    );
    raise exception 'Unusable Super Admins were counted as revocation protection';
  exception when check_violation then
    null;
  end;

  -- An unusable Super Admin can still be removed while a usable one remains.
  perform public.sai_manage_role_assignment(
    target_id, banned_admin_id, 'revoke', 'super_admin', array[]::uuid[],
    true, false, 'role_banned_' || run_id || '@example.test', 'Role Banned Admin'
  );

  execute 'reset role';

  select count(*) into role_count
  from public.user_roles
  where user_id = target_id and role = 'super_admin';
  select count(*) into audit_count
  from public.audit_logs
  where entity_id in (actor_id, target_id, banned_admin_id)
    and action in ('role_grant', 'role_revoke');
  if role_count <> 1 or audit_count <> 8 then
    raise exception 'Super Admin protection or transactional audit invariant failed';
  end if;
end;
$$;

rollback;
select 'Atomic role assignment, selected branch, confirmation, last-admin, and audit assertions passed; fixtures rolled back' as result;
