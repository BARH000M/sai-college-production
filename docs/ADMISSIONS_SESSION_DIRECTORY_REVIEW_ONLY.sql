-- REVIEW ONLY: not a migration, not approved for execution or deployment.
-- Requires an atomic migration-aware runner and separately verified MAIN
-- catalog/ACL preconditions. Never run this in the current workflow.
-- This does not resolve pending migration 005 or alter migration history.

do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;

  if to_regprocedure('public.sai_admissions_sessions(uuid)') is not null then
    raise exception 'Session directory already exists; compare definition and ACL before proceeding';
  end if;

  if to_regprocedure('public.sai_admissions_prepare()') is null
    or to_regprocedure('public.sai_admissions_audit()') is null
    or to_regprocedure('public.sai_public_admission_submit(text,text,text,text,text)') is null then
    raise exception 'Expected production admissions functions are missing';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_trigger t
    where t.tgrelid = 'public.admissions_enquiries'::regclass
      and t.tgname = 'admissions_prepare'
      and t.tgfoid = 'public.sai_admissions_prepare()'::regprocedure
      and not t.tgisinternal
      and t.tgenabled = 'O'
  ) or not exists (
    select 1
    from pg_catalog.pg_trigger t
    where t.tgrelid = 'public.admissions_enquiries'::regclass
      and t.tgname = 'admissions_audit'
      and t.tgfoid = 'public.sai_admissions_audit()'::regprocedure
      and not t.tgisinternal
      and t.tgenabled = 'O'
  ) then
    raise exception 'Expected admissions triggers are missing or disabled';
  end if;
end;
$$;

create function public.sai_admissions_sessions(wanted_branch uuid)
returns table (id uuid, name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if wanted_branch is null or not exists (select 1 from public.branches b where b.id = wanted_branch)
    or not (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(wanted_branch)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query select s.id, s.name from public.academic_sessions s
    where s.is_active order by s.name, s.id;
end;
$$;

revoke all on function public.sai_admissions_sessions(uuid) from public, anon, authenticated;
grant execute on function public.sai_admissions_sessions(uuid) to authenticated;
