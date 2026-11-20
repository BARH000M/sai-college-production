-- Forward-only remediation for project aeryusbrulqdxjdynwfh (Main).
--
-- Why this file exists
--   The live database never received 20261116142308 (atomic role management) or
--   20261117202728 (mutation-hold guard). The deployed manage-roles function calls
--   public.sai_manage_role_assignment() and public.sai_assert_mutations_enabled(),
--   both of which are absent, so every grant/revoke fails.
--
-- Why it is a new file instead of replaying the historical ones
--   20261117202728 ends by switching the global write hold ON and installing
--   statement/row triggers over public, private, storage and auth.users. Applied
--   verbatim today it would block every insert/update/delete platform-wide, and the
--   committed "release" migration (20261117202835) is an empty file. This package
--   installs the same reviewed infrastructure with the hold explicitly OFF.
--
-- Safety
--   Forward-only. Creates objects only; drops nothing outside its own trigger names.
--   Re-running is safe (idempotent create/drop-if-exists). An already-installed hold
--   state is never overwritten, so an intentional hold is preserved.
--
-- Companion test: supabase/tests/role_management_and_hold_forward.sql
-- Review package: docs/reports/PHASE7N_ROLE_AND_HOLD_PACKAGE_2026-11-20.md
-- Do not execute without explicit owner approval.

begin;

-- ---------------------------------------------------------------------------
-- 1. Mutation-hold state and audit (installed DISABLED)
-- ---------------------------------------------------------------------------
create table if not exists private.sai_mutation_hold_state (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  changed_at timestamptz not null default pg_catalog.now(),
  changed_by uuid,
  reason text not null default 'initial install'
);

create table if not exists private.sai_mutation_hold_audit (
  id bigint generated always as identity primary key,
  enabled boolean not null,
  actor_id uuid,
  actor_role text not null,
  reason text not null,
  changed_at timestamptz not null default pg_catalog.now()
);

-- Never clobber an existing hold state: only a first install writes this row.
insert into private.sai_mutation_hold_state (singleton, enabled, reason)
values (true, false, 'installed disabled 2026-11-20 role and hold remediation')
on conflict (singleton) do nothing;

alter table private.sai_mutation_hold_state enable row level security;
alter table private.sai_mutation_hold_audit enable row level security;

revoke all on private.sai_mutation_hold_state, private.sai_mutation_hold_audit
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Hold enforcement primitives
-- ---------------------------------------------------------------------------
create or replace function private.sai_assert_mutations_enabled()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_enabled boolean;
begin
  select s.enabled into v_enabled
  from private.sai_mutation_hold_state s
  where s.singleton
  for share;

  if not found then
    raise exception 'mutation_hold_state_missing' using errcode = '55000';
  end if;
  if v_enabled then
    raise exception 'maintenance_mode' using errcode = '55000';
  end if;
end;
$function$;

revoke all on function private.sai_assert_mutations_enabled()
  from public, anon, authenticated, service_role;

create or replace function private.sai_mutation_hold_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  perform private.sai_assert_mutations_enabled();
  if tg_level = 'STATEMENT' then
    return null;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$function$;

revoke all on function private.sai_mutation_hold_guard()
  from public, anon, authenticated, service_role;

-- Installs the guards idempotently. The hold state/audit tables are excluded so a
-- Super Admin can always operate the hold while it is engaged.
create or replace function private.sai_install_mutation_hold_guards()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_relation record;
  v_count integer := 0;
  v_skipped integer := 0;
begin
  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
      and not c.relispartition
      and not (n.nspname = 'private' and c.relname in (
        'sai_mutation_hold_state', 'sai_mutation_hold_audit'
      ))
    order by n.nspname, c.relname
  loop
    -- Some hosted schemas (storage, auth) are owned by other service roles. A
    -- deployer that cannot alter them must not abort the whole package; the
    -- relation is skipped and sai_set_mutation_hold() will refuse to engage the
    -- hold until coverage is complete. Fail-safe, never silent.
    begin
      execute pg_catalog.format(
        'drop trigger if exists sai_mutation_hold_statement on %I.%I',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'create trigger sai_mutation_hold_statement before insert or update or delete on %I.%I '
        'for each statement execute function private.sai_mutation_hold_guard()',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'drop trigger if exists sai_mutation_hold_truncate on %I.%I',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'create trigger sai_mutation_hold_truncate before truncate on %I.%I '
        'for each statement execute function private.sai_mutation_hold_guard()',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'drop trigger if exists sai_mutation_hold_row on %I.%I',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'create trigger sai_mutation_hold_row before insert or update or delete on %I.%I '
        'for each row execute function private.sai_mutation_hold_guard()',
        v_relation.nspname, v_relation.relname
      );
      v_count := v_count + 1;
    exception
      when insufficient_privilege then
        v_skipped := v_skipped + 1;
        raise notice 'mutation hold guard skipped for %.% (insufficient privilege)',
          v_relation.nspname, v_relation.relname;
    end;
  end loop;

  if v_skipped > 0 then
    raise notice 'mutation hold: % relation(s) skipped; hold engagement stays blocked until coverage is complete', v_skipped;
  end if;

  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'auth'
      and c.relname in ('users', 'identities')
      and c.relkind = 'r'
    order by c.relname
  loop
    begin
      execute pg_catalog.format(
        'drop trigger if exists sai_mutation_hold_account_mutation on %I.%I',
        v_relation.nspname, v_relation.relname
      );
      execute pg_catalog.format(
        'create trigger sai_mutation_hold_account_mutation before insert or update or delete on %I.%I '
        'for each statement execute function private.sai_mutation_hold_guard()',
        v_relation.nspname, v_relation.relname
      );
      v_count := v_count + 1;
    exception
      when insufficient_privilege then
        raise notice 'mutation hold account guard skipped for %.% (insufficient privilege)',
          v_relation.nspname, v_relation.relname;
    end;
  end loop;

  return v_count;
end;
$function$;

revoke all on function private.sai_install_mutation_hold_guards()
  from public, anon, authenticated, service_role;

-- Post-flight helper: 0 means every eligible table is guarded. A non-zero value is
-- expected on hosted projects where storage/auth tables belong to another role, and
-- it keeps the hold from being engaged until an authorized role closes the gap.
create or replace function private.sai_mutation_hold_missing_guards()
returns integer
language sql
stable
security definer
set search_path = ''
as $function$
  select pg_catalog.count(*)::integer
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public', 'private', 'storage')
    and c.relkind in ('r', 'p')
    and not c.relispartition
    and not (n.nspname = 'private' and c.relname in (
      'sai_mutation_hold_state', 'sai_mutation_hold_audit'
    ))
    and not exists (
      select 1 from pg_catalog.pg_trigger t
      where t.tgrelid = c.oid
        and t.tgname = 'sai_mutation_hold_statement'
        and not t.tgisinternal
    );
$function$;

revoke all on function private.sai_mutation_hold_missing_guards()
  from public, anon, authenticated, service_role;

select private.sai_install_mutation_hold_guards();

-- Callable by the deployed Edge Functions (service_role) as the mutation gate.
create or replace function public.sai_assert_mutations_enabled()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  perform private.sai_assert_mutations_enabled();
end;
$function$;

revoke all on function public.sai_assert_mutations_enabled() from public, anon;
grant execute on function public.sai_assert_mutations_enabled()
  to authenticated, service_role;

create or replace function public.sai_mutation_hold_status()
returns table (enabled boolean, changed_at timestamptz, reason text)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not (
    pg_catalog.current_setting('request.jwt.claim.role', true) = 'service_role'
    or exists (
      select 1
      from public.user_roles r
      join auth.users u on u.id = r.user_id
      where r.user_id = auth.uid()
        and r.role = 'super_admin'
        and u.email_confirmed_at is not null
        and u.deleted_at is null
        and (u.banned_until is null or u.banned_until <= pg_catalog.now())
    )
  ) then
    raise exception 'super_admin_required' using errcode = '42501';
  end if;

  return query
  select s.enabled, s.changed_at, s.reason
  from private.sai_mutation_hold_state s
  where s.singleton;
end;
$function$;

revoke all on function public.sai_mutation_hold_status() from public, anon;
grant execute on function public.sai_mutation_hold_status()
  to authenticated, service_role;

create or replace function public.sai_set_mutation_hold(p_enabled boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_role text := pg_catalog.current_setting('request.jwt.claim.role', true);
  v_reason text := pg_catalog.btrim(p_reason);
begin
  if p_enabled is null or v_reason is null
    or pg_catalog.char_length(v_reason) not between 8 and 240 then
    raise exception 'invalid_maintenance_request' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.user_roles r
    join auth.users u on u.id = r.user_id
    where r.user_id = v_actor
      and r.role = 'super_admin'
      and u.email_confirmed_at is not null
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= pg_catalog.now())
  ) then
    raise exception 'super_admin_required' using errcode = '42501';
  end if;

  -- Guards must be complete before the hold can be engaged, otherwise a table
  -- that appeared after installation could keep accepting writes.
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
      and not c.relispartition
      and not (n.nspname = 'private' and c.relname in (
        'sai_mutation_hold_state', 'sai_mutation_hold_audit'
      ))
      and not exists (
        select 1 from pg_catalog.pg_trigger t
        where t.tgrelid = c.oid
          and t.tgname = 'sai_mutation_hold_statement'
          and not t.tgisinternal
      )
  ) or exists (
    select 1
    from (values ('auth', 'users'), ('auth', 'identities')) expected(nspname, relname)
    join pg_catalog.pg_namespace n on n.nspname = expected.nspname
    join pg_catalog.pg_class c on c.relnamespace = n.oid and c.relname = expected.relname
    where c.relkind = 'r'
      and not exists (
        select 1 from pg_catalog.pg_trigger t
        where t.tgrelid = c.oid
          and t.tgname = 'sai_mutation_hold_account_mutation'
          and not t.tgisinternal
      )
  ) then
    raise exception 'mutation_hold_guards_incomplete' using errcode = '55000';
  end if;

  update private.sai_mutation_hold_state
  set enabled = p_enabled,
      changed_at = pg_catalog.now(),
      changed_by = v_actor,
      reason = v_reason
  where singleton;
  if not found then
    raise exception 'mutation_hold_state_missing' using errcode = '55000';
  end if;

  insert into private.sai_mutation_hold_audit(enabled, actor_id, actor_role, reason)
  values (p_enabled, v_actor, coalesce(v_role, 'authenticated'), v_reason);
end;
$function$;

revoke all on function public.sai_set_mutation_hold(boolean, text) from public, anon, service_role;
grant execute on function public.sai_set_mutation_hold(boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Atomic role management (reviewed contract from 20261116142308)
-- ---------------------------------------------------------------------------
-- service_role cannot read auth.users, so the "another usable Super Admin exists"
-- proof needs this narrow definer helper. It returns only a boolean, pins its
-- search_path, and is executable by service_role alone. The caller RPC stays
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

  -- Serializes every role mutation so two concurrent last-admin revocations cannot
  -- both pass the "another usable Super Admin exists" check.
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
    values (
      p_target_id,
      coalesce(nullif(pg_catalog.btrim(p_full_name), ''), 'مستخدم جديد'),
      p_target_email
    )
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
      -- Fail closed: row counts alone are not proof of usability.
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

-- ---------------------------------------------------------------------------
-- 4. Post-install assertion: the hold must be OFF when this package commits
-- ---------------------------------------------------------------------------
do $verify$
declare
  v_enabled boolean;
  v_admin_usable boolean;
begin
  select s.enabled into v_enabled
  from private.sai_mutation_hold_state s
  where s.singleton;

  if v_enabled is null then
    raise exception 'mutation_hold_state_missing' using errcode = '55000';
  end if;
  if v_enabled then
    raise exception 'mutation_hold_active_after_install' using errcode = '55000';
  end if;

  -- Raises 'maintenance_mode' if the guard is engaged; proves writes stay open.
  perform private.sai_assert_mutations_enabled();

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'sai_manage_role_assignment'
  ) then
    raise exception 'role_management_rpc_missing' using errcode = '55000';
  end if;

  -- The installed RPC must be SECURITY INVOKER; only the narrow helper is definer.
  select not p.prosecdef into v_admin_usable
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'sai_manage_role_assignment'
  limit 1;
  if v_admin_usable is not true then
    raise exception 'role_management_rpc_must_be_invoker' using errcode = '55000';
  end if;
end;
$verify$;

notify pgrst, 'reload schema';

commit;