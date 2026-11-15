-- SELECT-only post-approval verification. Does not verify authenticated behavior.
select to_regclass('public.sai_system_settings') as settings_table,
       to_regclass('private.sai_system_settings_audit') as trusted_audit,
       has_schema_privilege('service_role','public','USAGE') as service_schema_usage,
       has_function_privilege('authenticated',
         'public.admissions_link_student_account(uuid,uuid)','EXECUTE') as caller_link_rpc,
       has_function_privilege('service_role',
         'public.admissions_link_student_account(uuid,uuid)','EXECUTE') as service_link_rpc_expected_false;

select table_name, column_name,
       has_column_privilege('service_role',format('%I.%I',table_schema,table_name),column_name,'SELECT') as service_select,
       has_column_privilege('service_role',format('%I.%I',table_schema,table_name),column_name,'INSERT') as service_insert,
       has_column_privilege('service_role',format('%I.%I',table_schema,table_name),column_name,'UPDATE') as service_update
from information_schema.columns
where table_schema='public' and table_name in (
  'profiles','user_roles','branches','branch_memberships','students','parent_student_links',
  'classes','academic_sessions','learning_courses','learning_lessons','learning_lesson_progress',
  'learning_homework','learning_homework_submissions','admissions_enquiries','audit_logs',
  'sai_system_settings')
order by table_name,ordinal_position;

select schemaname,tablename,policyname,roles,cmd,qual,with_check
from pg_policies
where (schemaname='public' and tablename='sai_system_settings')
   or (schemaname='private' and tablename='sai_system_settings_audit')
order by schemaname,tablename,policyname;

select rolname,rolcanlogin,rolsuper,rolcreaterole,rolbypassrls
from pg_roles where rolname='sai_settings_audit_writer';

select n.nspname,p.proname,pg_get_userbyid(p.proowner) as owner,p.prosecdef,p.proconfig,
       has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_execute,
       has_function_privilege('anon',p.oid,'EXECUTE') as anon_execute
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='private' and p.proname in
  ('sai_setting_definition','validate_system_setting','audit_system_setting');

-- Negative checks: no surviving audit-writer memberships/CREATE, no RLS gaps.
select pg_get_userbyid(m.member) as member, m.admin_option, m.inherit_option, m.set_option
from pg_auth_members m join pg_roles r on r.oid=m.roleid
where r.rolname='sai_settings_audit_writer';

select case when exists(select 1 from pg_roles where rolname='sai_settings_audit_writer')
  then has_schema_privilege('sai_settings_audit_writer','private','CREATE')
  else null end as audit_writer_create_expected_false;

select n.nspname,c.relname,c.relrowsecurity,
       has_table_privilege('anon',c.oid,'SELECT') as anon_select_expected_false,
       has_table_privilege('authenticated',c.oid,'DELETE') as caller_delete_expected_false,
       has_table_privilege('authenticated',c.oid,'TRUNCATE') as caller_truncate_expected_false
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where (n.nspname='public' and c.relname='sai_system_settings')
   or (n.nspname='private' and c.relname='sai_system_settings_audit');
