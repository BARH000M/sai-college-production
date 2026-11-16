-- Local proposal only. Do not apply without explicit Preview approval.
begin;

-- service_role cannot read auth.users (verified against Preview catalogs), so
-- the "another usable Super Admin exists" proof needs this narrow definer
-- helper. It returns only a boolean, exposes no auth data, is pinned to fixed
-- schemas, and is executable by service_role alone. The caller RPC stays
-- SECURITY INVOKER and performs its own actor authorization first.
create or replace function private.sai_has_other_usable_super_admin(p_target_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
  select exists (
    select 1
    from public.user_roles as remaining_role
    join auth.users as remaining_user
      on remaining_user.id = remaining_role.user_id
    where remaining_role.role = 'super_admin'::public.app_role
      and remaining_role.user_id is distinct from p_target_id
      and remaining_user.email_confirmed_at is not null
      and remaining_user.deleted_at is null
      and (
        remaining_user.banned_until is null
        or remaining_user.banned_until <= pg_catalog.now()
      )
  );
$function$;

revoke all on function private.sai_has_other_usable_super_admin(uuid)
  from public, anon, authenticated;
grant execute on function private.sai_has_other_usable_super_admin(uuid)
  to service_role;

create or replace function public.sai_manage_role_assignment(
  p_actor_id uuid,
  p_target_id uuid,
  p_action text,
  p_role public.app_role,
  p_branch_ids uuid[],
  p_email_confirmed boolean,
  p_confirm_super_admin boolean,
  p_target_email text,
  p_full_name text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_role_exists boolean;
  v_remaining_scoped_roles boolean;
  v_active_branch_count integer;
begin
  if p_action is null or p_action not in ('grant', 'revoke') then
    raise exception using errcode = '22023', message = 'invalid_action';
  end if;

  if p_role is null or p_role not in (
    'super_admin', 'admin', 'teacher', 'accountant', 'receptionist',
    'librarian', 'student', 'parent', 'content_editor'
  ) then
    raise exception using errcode = '22023', message = 'invalid_role';
  end if;

  if p_actor_id is null or p_target_id is null then
    raise exception using errcode = '22023', message = 'invalid_user';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(831704, 1);

  if not exists (
    select 1
    from public.user_roles as actor_role
    where actor_role.user_id = p_actor_id
      and actor_role.role = 'super_admin'::public.app_role
  ) then
    raise exception using errcode = '42501', message = 'super_admin_required';
  end if;

  if p_action = 'grant' then
    if p_email_confirmed is not true then
      raise exception using errcode = '22023', message = 'email_verification_required';
    end if;

    if p_role = 'super_admin'::public.app_role and p_confirm_super_admin is not true then
      raise exception using errcode = '22023', message = 'super_admin_confirmation_required';
    end if;

    if p_role in (
      'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'
    ) then
      if coalesce(pg_catalog.cardinality(p_branch_ids), 0) = 0 then
        raise exception using errcode = '22023', message = 'branch_required';
      end if;
      if pg_catalog.cardinality(p_branch_ids) <> (
        select pg_catalog.count(distinct selected_branch.id)
        from pg_catalog.unnest(p_branch_ids) as selected_branch(id)
      ) then
        raise exception using errcode = '22023', message = 'duplicate_branch';
      end if;

      select pg_catalog.count(distinct branch.id)
      into v_active_branch_count
      from public.branches as branch
      where branch.id = any(p_branch_ids)
        and branch.is_active;

      if v_active_branch_count <> pg_catalog.cardinality(p_branch_ids) then
        raise exception using errcode = '22023', message = 'inactive_or_unknown_branch';
      end if;
    elsif coalesce(pg_catalog.cardinality(p_branch_ids), 0) <> 0 then
      raise exception using errcode = '22023', message = 'branch_not_allowed_for_role';
    end if;

    select exists (
      select 1
      from public.user_roles as target_role
      where target_role.user_id = p_target_id
        and target_role.role = p_role
    ) into v_role_exists;

    if v_role_exists then
      raise exception using errcode = '23505', message = 'role_already_assigned';
    end if;

    insert into public.profiles (id, full_name, email)
    values (p_target_id, coalesce(nullif(pg_catalog.btrim(p_full_name), ''), 'مستخدم جديد'), p_target_email)
    on conflict (id) do nothing;

    insert into public.user_roles (user_id, role, assigned_by)
    values (p_target_id, p_role, p_actor_id);

    if p_role in (
      'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'
    ) then
      delete from public.branch_memberships
      where user_id = p_target_id;

      insert into public.branch_memberships (user_id, branch_id, is_active)
      select p_target_id, selected_branch.id, true
      from pg_catalog.unnest(p_branch_ids) as selected_branch(id);
    end if;
  else
    select exists (
      select 1
      from public.user_roles as target_role
      where target_role.user_id = p_target_id
        and target_role.role = p_role
    ) into v_role_exists;

    if not v_role_exists then
      raise exception using errcode = 'P0002', message = 'role_not_assigned';
    end if;

    if p_role = 'super_admin'::public.app_role then
      -- Fail closed: row counts alone are not proof. Another Super Admin must
      -- exist whose Auth account can actually sign in (email confirmed, not
      -- deleted, not currently banned). The advisory lock above serializes
      -- concurrent role mutations through this function before this check.
      if not private.sai_has_other_usable_super_admin(p_target_id) then
        raise exception using errcode = '23514', message = 'last_usable_super_admin_protected';
      end if;
    end if;

    delete from public.user_roles
    where user_id = p_target_id
      and role = p_role;

    select exists (
      select 1
      from public.user_roles as remaining_role
      where remaining_role.user_id = p_target_id
        and remaining_role.role in (
          'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'
        )
    ) into v_remaining_scoped_roles;

    if p_role in (
      'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'
    ) and not v_remaining_scoped_roles then
      delete from public.branch_memberships
      where user_id = p_target_id;
    end if;
  end if;

  insert into public.audit_logs (
    actor_user_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values (
    p_actor_id,
    case when p_action = 'grant' then 'role_grant' else 'role_revoke' end,
    'user_roles',
    p_target_id,
    pg_catalog.jsonb_build_object(
      'role', p_role,
      'source', 'role_management',
      'target_email', p_target_email,
      'branch_ids', case
        when p_action = 'grant' and p_role in (
          'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'
        ) then pg_catalog.to_jsonb(p_branch_ids)
        else '[]'::jsonb
      end
    )
  );

  return pg_catalog.jsonb_build_object('ok', true, 'action', p_action, 'role', p_role);
end;
$function$;

revoke all on function public.sai_manage_role_assignment(
  uuid, uuid, text, public.app_role, uuid[], boolean, boolean, text, text
) from public, anon, authenticated;
grant execute on function public.sai_manage_role_assignment(
  uuid, uuid, text, public.app_role, uuid[], boolean, boolean, text, text
) to service_role;

notify pgrst, 'reload schema';
commit;