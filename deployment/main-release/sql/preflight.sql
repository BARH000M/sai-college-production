-- Read-only preflight. This is not sufficient proof of production readiness.
do $$
declare
  missing text;
  history text[];
begin
  if current_setting('server_version_num')::integer < 160000 then
    raise exception 'Finance migration requires PostgreSQL 16 or later';
  end if;
  if not (select rolcreaterole or rolsuper from pg_catalog.pg_roles where rolname = current_user)
     or not has_database_privilege(current_user, current_database(), 'CREATE')
     or not has_schema_privilege(current_user, 'public', 'CREATE') then
    raise exception 'Executor lacks a required role, database or public schema privilege';
  end if;
  if has_schema_privilege('public', 'public', 'CREATE')
     or has_schema_privilege('anon', 'public', 'CREATE')
     or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted public schema CREATE privilege';
  end if;
  if to_regclass('supabase_migrations.schema_migrations') is null then
    raise exception 'Migration history unavailable';
  end if;
  select array_agg(version order by version) into history from supabase_migrations.schema_migrations;
  if history is distinct from array['001','002','003','004']::text[] then
    raise exception 'Unexpected migration history: %', history;
  end if;
  select string_agg(name, ', ') into missing
  from (values ('public.branches'), ('public.academic_sessions'),
    ('public.branch_memberships'), ('public.classes'), ('public.students'),
    ('public.parent_student_links'), ('public.user_roles'), ('public.audit_logs'),
    ('public.admissions_enquiries'), ('auth.users')) as required(name)
  where to_regclass(name) is null;
  if missing is not null then raise exception 'Required tables missing: %', missing; end if;
  if to_regclass('public.attendance_sessions') is not null
     or to_regclass('public.attendance_records') is not null
     or exists (select 1 from pg_catalog.pg_namespace where nspname = 'sai_finance')
     or exists (select 1 from pg_catalog.pg_roles where rolname = 'sai_finance_owner') then
    raise exception 'Attendance or finance objects already exist; compare state';
  end if;
  if to_regprocedure('public.sai_admissions_sessions(uuid)') is not null
     or to_regprocedure('public.sai_admissions_prepare()') is null
     or to_regprocedure('public.sai_admissions_audit()') is null
     or to_regprocedure('public.sai_public_admission_submit(text,text,text,text,text)') is null
     or to_regprocedure('public.sai_submit_application(text,text,text,text,text,text,text)') is null
     or to_regprocedure('auth.uid()') is null
     or to_regprocedure('public.sai_security_has_role(public.app_role)') is null
     or to_regprocedure('public.sai_security_branch_member(uuid)') is null then
    raise exception 'Required admissions or security functions differ';
  end if;
  select string_agg(required.tbl || '.' || required.col, ', ') into missing
  from (values ('classes','session_id'),('classes','teacher_id'),('classes','is_active'),
    ('students','class_id'),('students','branch_id'),('students','user_id'),
    ('branch_memberships','is_active'),('branch_memberships','branch_id'),
    ('academic_sessions','is_active'),('parent_student_links','verified_at')
  ) as required(tbl, col)
  where not exists (select 1 from pg_catalog.pg_attribute a
    where a.attrelid = to_regclass('public.' || required.tbl)
      and a.attname = required.col and a.attnum > 0 and not a.attisdropped);
  if missing is not null then raise exception 'Required columns missing: %', missing; end if;
  select string_agg(name, ', ') into missing
  from (values ('public.branches'), ('public.academic_sessions'),
    ('public.classes'), ('public.students'), ('auth.users')) as required(name)
  where not has_table_privilege(current_user, to_regclass(name), 'REFERENCES');
  if missing is not null then raise exception 'REFERENCES privilege missing: %', missing; end if;
  select string_agg(c.relname, ', ') into missing
  from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname in
    ('user_roles','branch_memberships','students','classes','parent_student_links')
    and not pg_has_role(current_user, c.relowner, 'USAGE');
  if missing is not null then raise exception 'Policy ownership privilege missing: %', missing; end if;
end;
$$;

select current_database() as database, current_user as executor,
       current_setting('server_version') as server_version,
       (select rolcreaterole from pg_catalog.pg_roles where rolname = current_user) as can_create_role,
       has_database_privilege(current_user, current_database(), 'CREATE') as can_create_schema,
       has_schema_privilege(current_user, 'public', 'CREATE') as can_create_public_objects,
       has_schema_privilege('anon', 'public', 'CREATE') as anon_can_create_public,
       has_schema_privilege('authenticated', 'public', 'CREATE') as authenticated_can_create_public;

select version from supabase_migrations.schema_migrations order by version;

select n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity,
       pg_catalog.pg_get_userbyid(c.relowner) as owner
from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in
  ('branches','academic_sessions','branch_memberships','classes','students',
   'parent_student_links','user_roles','audit_logs','admissions_enquiries')
order by c.relname;

select required.name, to_regprocedure(required.name) is not null as present
from (values
 ('auth.uid()'), ('public.sai_security_has_role(public.app_role)'),
 ('public.sai_security_branch_member(uuid)'), ('public.sai_admissions_prepare()'),
 ('public.sai_admissions_audit()'),
 ('public.sai_public_admission_submit(text,text,text,text,text)')
) as required(name);

select n.nspname, p.proname, pg_catalog.pg_get_userbyid(p.proowner) as owner,
       p.prosecdef, p.proconfig, p.proacl
from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in
 ('sai_admissions_prepare','sai_admissions_audit','sai_public_admission_submit',
  'sai_submit_application','sai_admissions_sessions')
order by p.proname;

select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_catalog.pg_policies
where schemaname = 'public' and tablename in
 ('user_roles','branch_memberships','students','classes','parent_student_links','admissions_enquiries')
order by tablename, policyname;
