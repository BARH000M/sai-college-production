-- Additive local/main-compatible proposal. Creates a disabled, server-enforced
-- write hold; it does not activate the hold when installed.
begin;

create table private.sai_mutation_hold_state (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  changed_at timestamptz not null default pg_catalog.now(),
  changed_by uuid,
  reason text not null default 'initial install'
);

create table private.sai_mutation_hold_audit (
  id bigint generated always as identity primary key,
  enabled boolean not null,
  actor_id uuid,
  actor_role text not null,
  reason text not null,
  changed_at timestamptz not null default pg_catalog.now()
);

insert into private.sai_mutation_hold_state(singleton, enabled, reason)
values (true, false, 'initial install');

alter table private.sai_mutation_hold_state enable row level security;
alter table private.sai_mutation_hold_audit enable row level security;
revoke all on private.sai_mutation_hold_state, private.sai_mutation_hold_audit
  from public, anon, authenticated, service_role;

create function private.sai_assert_mutations_enabled()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
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
end
$$;
revoke all on function private.sai_assert_mutations_enabled() from public, anon, authenticated, service_role;

create function private.sai_mutation_hold_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.sai_assert_mutations_enabled();
  if tg_level = 'STATEMENT' then
    return null;
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;
revoke all on function private.sai_mutation_hold_guard() from public, anon, authenticated, service_role;

create function private.sai_install_mutation_hold_guards()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_relation record;
  v_count integer := 0;
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
  end loop;

  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
      and c.relispartition
    order by n.nspname, c.relname
  loop
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_partition_statement on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'create trigger sai_mutation_hold_partition_statement before insert or update or delete on %I.%I '
      'for each statement execute function private.sai_mutation_hold_guard()',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_partition_truncate on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'create trigger sai_mutation_hold_partition_truncate before truncate on %I.%I '
      'for each statement execute function private.sai_mutation_hold_guard()',
      v_relation.nspname, v_relation.relname
    );
    v_count := v_count + 1;
  end loop;

  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'auth'
      and c.relname in ('users', 'identities')
      and c.relkind = 'r'
    order by c.relname
  loop
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_account_insert_delete on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'create trigger sai_mutation_hold_account_insert_delete before insert or delete on %I.%I '
      'for each statement execute function private.sai_mutation_hold_guard()',
      v_relation.nspname, v_relation.relname
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end
$$;
revoke all on function private.sai_install_mutation_hold_guards() from public, anon, authenticated, service_role;

select private.sai_install_mutation_hold_guards();

create function public.sai_assert_mutations_enabled()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform private.sai_assert_mutations_enabled();
end
$$;
revoke all on function public.sai_assert_mutations_enabled() from public, anon;
grant execute on function public.sai_assert_mutations_enabled() to authenticated, service_role;

create function public.sai_mutation_hold_status()
returns table (enabled boolean, changed_at timestamptz, reason text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (
    coalesce(pg_catalog.current_setting('request.jwt.claim.role', true), '') = 'service_role'
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
end
$$;
revoke all on function public.sai_mutation_hold_status() from public, anon;
grant execute on function public.sai_mutation_hold_status() to authenticated, service_role;

create function public.sai_set_mutation_hold(p_enabled boolean, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := pg_catalog.current_setting('request.jwt.claim.role', true);
  v_reason text := pg_catalog.btrim(p_reason);
begin
  if p_enabled is null or v_reason is null or pg_catalog.char_length(v_reason) not between 8 and 240 then
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
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
      and c.relispartition
      and (
        not exists (
          select 1 from pg_catalog.pg_trigger t
          where t.tgrelid = c.oid
            and t.tgname = 'sai_mutation_hold_partition_statement'
            and not t.tgisinternal
        )
        or not exists (
          select 1 from pg_catalog.pg_trigger t
          where t.tgrelid = c.oid
            and t.tgname = 'sai_mutation_hold_partition_truncate'
            and not t.tgisinternal
        )
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
          and t.tgname = 'sai_mutation_hold_account_insert_delete'
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
end
$$;
revoke all on function public.sai_set_mutation_hold(boolean, text) from public, anon, service_role;
grant execute on function public.sai_set_mutation_hold(boolean, text) to authenticated;

commit;
