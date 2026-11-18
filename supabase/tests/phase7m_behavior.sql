-- Executed only by the task-owned Main replay runner.
begin;
do $$ begin
  if current_database()<>'phase3b_main' or replace(current_setting('data_directory'),'\','/') not like '%/.tmp-phase3b-main/%' then
    raise exception 'Isolated Main replay required';
  end if;
  if to_regnamespace('sai_finance') is not null or exists(select 1 from pg_roles where rolname='sai_finance_owner') then
    raise exception 'Obsolete finance contract installed';
  end if;
  if to_regprocedure('public.sai_finance_students()') is null
    or has_function_privilege('anon','public.sai_finance_students()','EXECUTE') then
    raise exception 'Finance directory ACL failure';
  end if;
  if (select jsonb_agg(to_jsonb(s)-'value_type'-'scope' order by category,setting_key) from public.sai_system_settings s)
      is distinct from (select settings from private.phase7m_preservation)
    or (select jsonb_agg(to_jsonb(a) order by id) from public.sai_system_settings_audit a)
      is distinct from (select audits from private.phase7m_preservation)
    or exists(select 1 from private.sai_system_settings_audit) then
    raise exception 'Settings or legacy audit preservation failure';
  end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
do $$ begin
  begin
    update public.sai_system_settings set value_text='http://invalid.example' where category='general' and setting_key='website_url';
    raise exception 'Insecure URL accepted';
  exception when sqlstate '22023' then null; end;
  begin
    update public.sai_system_settings set setting_key='address';
    raise exception 'Mutable settings identity';
  exception when sqlstate '22023' then null; end;
  begin
    update public.sai_system_settings set value_text='Bearer credential-pattern-test';
    raise exception 'Credential value accepted';
  exception when sqlstate '22023' then null; end;
  update public.sai_system_settings set value_text='Phase 7-M preservation test' where category='general' and setting_key='college_name';
end $$;
reset role;
do $$ begin
  if (select count(*) from private.sai_system_settings_audit)<>1 then
    raise exception 'Trusted settings audit missing';
  end if;
  if has_table_privilege('authenticated','private.sai_system_settings_audit','INSERT,UPDATE,DELETE') then
    raise exception 'Settings audit forgeable';
  end if;
end $$;
rollback;
