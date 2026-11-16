-- ISOLATED LOCAL DATABASE ONLY. Requires the local branch-membership lockdown
-- proposal (20261116151509_branch_membership_write_lockdown.sql) to be applied
-- in the same disposable database. Never run on Preview or Production.
begin;
do $$
begin
  if current_setting('sai.branch_lockdown_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  admin_id uuid := gen_random_uuid();
  member_id uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid();
  branch_b uuid := gen_random_uuid();
  run_id text := replace(gen_random_uuid()::text, '-', '');
  visible_count bigint;
begin
  -- Catalog assertions: no authenticated write privilege survives at either
  -- the table level or the column level; read-only self access is preserved.
  if has_table_privilege('authenticated', 'public.branch_memberships', 'INSERT')
    or has_table_privilege('authenticated', 'public.branch_memberships', 'UPDATE')
    or has_table_privilege('authenticated', 'public.branch_memberships', 'DELETE')
    or has_column_privilege('authenticated', 'public.branch_memberships', 'user_id', 'INSERT')
    or has_column_privilege('authenticated', 'public.branch_memberships', 'branch_id', 'INSERT')
    or has_column_privilege('authenticated', 'public.branch_memberships', 'is_active', 'INSERT')
    or has_column_privilege('authenticated', 'public.branch_memberships', 'is_active', 'UPDATE')
  then
    raise exception 'Authenticated write privilege remains on branch_memberships';
  end if;
  if not has_table_privilege('authenticated', 'public.branch_memberships', 'SELECT') then
    raise exception 'Read-only self access was revoked';
  end if;

  -- Policy assertions: no UPDATE policy may remain that does not require
  -- super_admin in both USING and WITH CHECK.
  if exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'branch_memberships' and cmd = 'UPDATE'
      and (qual not ilike '%super_admin%' or with_check not ilike '%super_admin%')
  ) then
    raise exception 'A non-super-admin UPDATE policy remains on branch_memberships';
  end if;

  insert into auth.users (id, email, email_confirmed_at)
  values
    (admin_id, 'lock_admin_' || run_id || '@example.test', now()),
    (member_id, 'lock_member_' || run_id || '@example.test', now());
  insert into public.user_roles (user_id, role)
  values (admin_id, 'admin');
  insert into public.branches (id, name, code, is_active)
  values
    (branch_a, 'LOCK_TEST_A_' || run_id, 'LOCK_TEST_A_' || run_id, true),
    (branch_b, 'LOCK_TEST_B_' || run_id, 'LOCK_TEST_B_' || run_id, true);
  insert into public.branch_memberships (user_id, branch_id, is_active)
  values (admin_id, branch_a, true), (member_id, branch_a, true);

  -- Behavioral layer: an authenticated admin cannot retarget their own
  -- membership, touch another user's membership, change ownership, or insert
  -- a new membership for themselves. The audit trigger never gets to record
  -- these because the write is denied before it happens.
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';

  begin
    update public.branch_memberships set branch_id = branch_b
    where user_id = admin_id and branch_id = branch_a;
    raise exception 'Admin moved own membership to another branch';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.branch_memberships set is_active = false
    where user_id = member_id and branch_id = branch_a;
    raise exception 'Admin modified another user''s membership';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.branch_memberships set user_id = member_id
    where user_id = admin_id and branch_id = branch_a;
    raise exception 'Admin reassigned membership ownership';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.branch_memberships (user_id, branch_id, is_active)
    values (admin_id, branch_b, true);
    raise exception 'Admin inserted their own membership into another branch';
  exception when insufficient_privilege then
    null;
  end;

  -- Read-only self access still works.
  select count(*) into visible_count
  from public.branch_memberships
  where user_id = admin_id;
  if visible_count <> 1 then
    raise exception 'Self read of own membership is broken';
  end if;
  execute 'reset role';

  -- The approved server contract (service_role, bypasses RLS) keeps working
  -- for explicit branch management.
  execute 'set local role service_role';
  insert into public.branch_memberships (user_id, branch_id, is_active)
  values (member_id, branch_b, true)
  on conflict (user_id, branch_id) do update set is_active = excluded.is_active;
  update public.branch_memberships set is_active = false
  where user_id = member_id and branch_id = branch_b;
  delete from public.branch_memberships
  where user_id = member_id and branch_id = branch_b;
  if exists (
    select 1 from public.branch_memberships
    where user_id = member_id and branch_id = branch_b
  ) then
    raise exception 'Service-role branch management is broken';
  end if;
  execute 'reset role';
end;
$$;

rollback;
select 'Branch-membership lockdown assertions passed; fixtures rolled back' as result;
