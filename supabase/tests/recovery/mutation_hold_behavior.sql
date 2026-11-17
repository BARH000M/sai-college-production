\set ON_ERROR_STOP on
\set QUIET on
\set VERBOSITY verbose

do $$
declare
  v_actor uuid;
begin
  select u.id into v_actor
  from auth.users u
  join public.user_roles r on r.user_id = u.id and r.role = 'super_admin'
  where u.email_confirmed_at is not null
    and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now())
  order by u.id
  limit 1;
  if v_actor is null then
    raise exception 'No usable Super Admin is available in the isolated restore';
  end if;
  perform set_config('request.jwt.claim.sub', v_actor::text, false);
  perform set_config('request.jwt.claim.role', 'authenticated', false);
end
$$;

set role authenticated;

do $$
declare
  v_enabled boolean;
begin
  select s.enabled into v_enabled from public.sai_mutation_hold_status() s;
  if v_enabled then
    raise exception 'Maintenance hold must start disabled';
  end if;
end
$$;

insert into public.sai_mutation_hold_probe(note) values ('before-hold');

reset role;
create table public.sai_mutation_hold_late_probe (
  id bigint generated always as identity primary key,
  note text not null
);
alter table public.sai_mutation_hold_late_probe enable row level security;
create policy sai_mutation_hold_late_probe_authenticated
  on public.sai_mutation_hold_late_probe
  for all to authenticated
  using (true) with check (true);
grant select, insert, update, delete on public.sai_mutation_hold_late_probe
  to anon, authenticated, service_role;
grant usage, select on sequence public.sai_mutation_hold_late_probe_id_seq
  to anon, authenticated, service_role;
select private.sai_install_mutation_hold_guards();
set request.jwt.claim.sub = '';
set request.jwt.claim.role = 'anon';
set role anon;

do $$
declare
  v_denied boolean := false;
begin
  begin
    perform public.sai_set_mutation_hold(true, 'unauthorized attempt');
  exception when insufficient_privilege then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'Anonymous caller changed maintenance mode';
  end if;
end
$$;

reset role;
do $$
declare
  v_actor uuid;
begin
  select u.id into v_actor
  from auth.users u
  join public.user_roles r on r.user_id = u.id and r.role = 'super_admin'
  where u.email_confirmed_at is not null
    and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now())
  order by u.id
  limit 1;
  perform set_config('request.jwt.claim.sub', v_actor::text, false);
  perform set_config('request.jwt.claim.role', 'authenticated', false);
end
$$;
set role authenticated;
select public.sai_set_mutation_hold(true, 'local recovery authorization test');

do $$
declare
  v_denied boolean;
  v_enabled boolean;
begin
  select s.enabled into v_enabled from public.sai_mutation_hold_status() s;
  if not v_enabled then
    raise exception 'Super Admin could not enable maintenance mode';
  end if;

  v_denied := false;
  begin
    insert into public.sai_mutation_hold_probe(note) values ('authenticated-api');
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Authenticated direct DML bypassed the hold'; end if;

  v_denied := false;
  begin
    insert into public.sai_mutation_hold_late_probe(note) values ('late-table');
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Newly created table bypassed refreshed hold guards'; end if;

  v_denied := false;
  begin
    update public.sai_mutation_hold_probe set note = 'changed';
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Authenticated UPDATE bypassed the hold'; end if;

  v_denied := false;
  begin
    delete from public.sai_mutation_hold_probe;
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Authenticated DELETE bypassed the hold'; end if;

  v_denied := false;
  begin
    perform public.sai_mutation_hold_probe_rpc();
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'SECURITY DEFINER RPC bypassed the hold'; end if;
end
$$;

reset role;
set role service_role;
do $$
declare
  v_denied boolean := false;
begin
  begin
    insert into public.sai_mutation_hold_probe(note) values ('service-job');
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'BYPASSRLS service writer bypassed the hold'; end if;
end
$$;

reset role;
set role supabase_auth_admin;
do $$
declare
  v_denied boolean := false;
begin
  if not exists (select 1 from auth.users) then
    raise exception 'Auth update guard test requires a recovered user';
  end if;

  begin
    update auth.users
    set email = email
    where id = (select id from auth.users order by id limit 1);
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then
    raise exception 'Privileged Auth user UPDATE bypassed the hold';
  end if;
end
$$;

reset role;
do $$
declare
  v_denied boolean := false;
begin
  begin
    insert into auth.users(id) values (pg_catalog.gen_random_uuid());
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Auth provisioning bypassed the hold'; end if;
end
$$;

reset role;
do $$
declare
  v_denied boolean := false;
begin
  begin
    insert into public.sai_mutation_hold_probe(note) values ('postgres-writer');
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Privileged database writer bypassed the hold'; end if;

  v_denied := false;
  begin
    execute 'truncate table public.sai_mutation_hold_probe';
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'TRUNCATE bypassed the hold'; end if;

  v_denied := false;
  begin
    execute 'create table public.sai_mutation_hold_ddl_probe (id integer)';
  exception when sqlstate '55000' then
    v_denied := true;
  end;
  if not v_denied then raise exception 'Privileged DDL bypassed the hold'; end if;
end
$$;

set role authenticated;
select public.sai_set_mutation_hold(false, 'local recovery authorization test complete');
reset role;

do $$
declare
  v_enabled boolean;
  v_audit_count bigint;
begin
  select s.enabled into v_enabled from public.sai_mutation_hold_status() s;
  select count(*) into v_audit_count from private.sai_mutation_hold_audit;
  if v_enabled or v_audit_count < 2 then
    raise exception 'Super Admin recovery path or audit record failed';
  end if;
end
$$;

set role authenticated;
insert into public.sai_mutation_hold_probe(note) values ('after-hold');
reset role;

do $$
declare
  v_count bigint;
begin
  select count(*) into v_count from public.sai_mutation_hold_probe;
  if v_count <> 2 then
    raise exception 'Allowed writes before/after maintenance were not preserved';
  end if;
end
$$;
