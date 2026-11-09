do $$
begin
  if exists (
    select 1 from release_admissions_baseline b
    left join pg_catalog.pg_proc p on p.oid = b.oid
    where p.oid is null or pg_catalog.pg_get_functiondef(p.oid) is distinct from b.definition
      or p.proowner is distinct from b.proowner or p.proacl is distinct from b.proacl
      or p.proconfig is distinct from b.proconfig or p.prosecdef is distinct from b.prosecdef
  ) then
    raise exception 'Existing admissions function definition, ownership or ACL changed';
  end if;
  if exists (
    select 1 from release_admissions_triggers b left join pg_catalog.pg_trigger t on t.oid = b.oid
    where t.oid is null or pg_catalog.pg_get_triggerdef(t.oid) is distinct from b.definition
      or t.tgenabled is distinct from b.tgenabled
  ) then raise exception 'Existing admissions trigger changed'; end if;
end;
$$;
