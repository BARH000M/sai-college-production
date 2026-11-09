-- Fail-closed structural assertions; behavior and full ACL equivalence require
-- separate tests and human review. Does not write database state.
do $$
declare
  t text;
  f oid;
  owner_oid oid := (select oid from pg_catalog.pg_roles where rolname = 'sai_finance_owner');
begin
  if to_regprocedure('public.sai_admissions_sessions(uuid)') is null
     or has_function_privilege('anon', 'public.sai_admissions_sessions(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated', 'public.sai_admissions_sessions(uuid)', 'EXECUTE') then
    raise exception 'Session directory or its effective execution grants differ';
  end if;
  if has_schema_privilege('public', 'public', 'CREATE')
     or has_schema_privilege('anon', 'public', 'CREATE')
     or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public';
  end if;
  foreach t in array array['attendance_sessions','attendance_records'] loop
    if not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'public' and c.relname = t and c.relrowsecurity) then
      raise exception 'Attendance RLS or table missing: %', t;
    end if;
  end loop;
  if owner_oid is null or exists (select 1 from pg_catalog.pg_roles
    where oid = owner_oid and (rolcanlogin or rolsuper or rolbypassrls or rolcreaterole
      or rolcreatedb or rolreplication or rolinherit)) then
    raise exception 'Finance owner missing or has unsafe attributes';
  end if;
  if not exists (select 1 from pg_catalog.pg_namespace where nspname = 'sai_finance' and nspowner = owner_oid)
     or has_schema_privilege('sai_finance_owner', 'public', 'CREATE') then
    raise exception 'Finance schema ownership or temporary CREATE grant differs';
  end if;
  if has_schema_privilege('anon', 'sai_finance', 'USAGE')
     or has_schema_privilege('authenticated', 'sai_finance', 'USAGE')
     or pg_has_role('anon', 'sai_finance_owner', 'MEMBER')
     or pg_has_role('authenticated', 'sai_finance_owner', 'MEMBER') then
    raise exception 'Browser role has finance schema access or membership';
  end if;
  foreach t in array array['fee_groups','assignments','payments','waivers','refunds','audit_log'] loop
    if not exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
                   where n.nspname = 'sai_finance' and c.relname = t and c.relowner = owner_oid
                     and c.relrowsecurity and c.relforcerowsecurity) then
      raise exception 'Finance table owner or FORCE RLS differs: %', t;
    end if;
  end loop;
  foreach t in array array[
    'public.sai_finance_groups()',
    'public.sai_finance_save_group(uuid,uuid,uuid,text,text,numeric,date,boolean)',
    'public.sai_finance_assign(uuid,uuid,numeric,date)',
    'public.sai_finance_assignments()',
    'public.sai_finance_pay(uuid,numeric,text,text,uuid)',
    'public.sai_finance_void(uuid,text)',
    'public.sai_finance_waive(uuid,text)',
    'public.sai_finance_cancel(uuid,text)',
    'public.sai_finance_refund(uuid,numeric,text,text,text,uuid)',
    'public.sai_finance_payments(uuid)',
    'public.sai_finance_refunds(uuid)',
    'public.sai_finance_audit(uuid)'
  ] loop
    f := to_regprocedure(t);
    if f is null then raise exception 'Finance RPC missing: %', t; end if;
    if not exists (select 1 from pg_catalog.pg_proc where oid = f and proowner = owner_oid and prosecdef)
       or has_function_privilege('anon', f, 'EXECUTE')
       or not has_function_privilege('authenticated', f, 'EXECUTE') then
      raise exception 'Finance RPC owner, definer or grants differ: %', t;
    end if;
  end loop;
end;
$$;
select 'Structural assertions passed; full release verification remains required' as result;
