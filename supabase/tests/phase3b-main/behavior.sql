-- Synthetic isolated cluster only. run_local.py verifies data_directory in
-- every session before executing this file. Never run on a hosted database.
begin;
do $$begin
 if current_database()<>'phase3b_main' then raise exception 'Isolated database required';end if;
 if (select settings from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by category,setting_key) from public.sai_system_settings s)
 or (select settings_audit from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by id) from public.sai_system_settings_audit s)
 or (select audit from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by id) from public.audit_logs s)
 or (select accounts from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by id) from auth.users s)
 or (select roles from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by user_id,role) from public.user_roles s)
 or (select memberships from public.phase3b_preservation_snapshot) is distinct from
   (select jsonb_agg(to_jsonb(s) order by user_id,branch_id) from public.branch_memberships s)
 then raise exception 'Proposal changed existing records'; end if;
 if (select count(*) from public.sai_system_settings)<>7 or
    (select count(*) from public.sai_system_settings_audit)<>8 then raise exception 'Invalid preservation fixture';end if;
end $$;

create function pg_temp.expect_error(expected text,command text) returns void language plpgsql as $$
begin
 begin execute command; exception when others then
   if sqlstate=expected then return;end if;
   raise exception 'Expected %, got %: %',expected,sqlstate,sqlerrm;
 end;
 raise exception 'Expected % but statement succeeded: %',expected,command;
end $$;
create function pg_temp.change(target uuid,action text,role public.app_role,branches uuid[] default '{}',confirmation boolean default false)
returns jsonb language sql as $$ select public.sai_manage_role_assignment(
 '00000000-0000-4000-8000-000000000001',target,action,role,branches,true,confirmation,'forged@example.test','Forged') $$;

-- Catalog boundary plus actual browser and service attempts.
do $$declare r text;c record;begin
 foreach r in array array['anon','authenticated','service_role'] loop
   if has_table_privilege(r,'public.user_roles','INSERT,UPDATE,DELETE,TRUNCATE')
     or has_any_column_privilege(r,'public.user_roles','INSERT,UPDATE')
     or has_table_privilege(r,'public.branch_memberships','INSERT,UPDATE,DELETE,TRUNCATE')
     or has_any_column_privilege(r,'public.branch_memberships','INSERT,UPDATE') then
     raise exception 'Direct role/scope write survived for %',r;
   end if;
   if has_function_privilege(r,'public.sai_set_role(uuid,public.app_role,boolean)','EXECUTE') then
     raise exception 'Legacy role writer callable';end if;
 end loop;
 for c in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname ~ '^sai_(security_|learning_(can_|own_student)|finance_(has_role|staff|can_read_student))' loop
   if has_function_privilege('authenticated',c.oid,'EXECUTE') or has_function_privilege('anon',c.oid,'EXECUTE') then
     raise exception 'Public wrapper % remains callable',c.proname;
   end if;
 end loop;
end $$;
set local role anon;
select pg_temp.expect_error('42501',$q$select public.sai_manage_role_assignment(null,null,'grant','super_admin','{}',true,true,null,null)$q$);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.expect_error('42501',$q$insert into public.user_roles(user_id,role) values('00000000-0000-4000-8000-000000000002','super_admin')$q$);
select pg_temp.expect_error('42501',$q$update public.branch_memberships set branch_id='20000000-0000-4000-8000-000000000002'$q$);
select pg_temp.expect_error('42501',$q$select public.sai_set_role('00000000-0000-4000-8000-000000000002','super_admin',true)$q$);
reset role;
set local role service_role;
select pg_temp.expect_error('42501',$q$insert into public.user_roles(user_id,role) values('00000000-0000-4000-8000-000000000002','super_admin')$q$);
select pg_temp.expect_error('42501',$q$delete from public.user_roles$q$);
select pg_temp.expect_error('42501',$q$insert into public.branch_memberships values('00000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002',true)$q$);
select pg_temp.expect_error('42501',$q$select public.sai_manage_role_assignment('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','grant','super_admin','{}',true,true,null,null)$q$);
select pg_temp.expect_error('22023',$q$select pg_temp.change('00000000-0000-4000-8000-000000000003','grant','student')$q$);
select pg_temp.expect_error('22023',$q$select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','super_admin')$q$);
select pg_temp.expect_error('22023',$q$select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','teacher')$q$);
select pg_temp.expect_error('22023',$q$select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','teacher',array['20000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001']::uuid[])$q$);
select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','teacher',array['20000000-0000-4000-8000-000000000001']::uuid[]);
select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','accountant',array['20000000-0000-4000-8000-000000000002']::uuid[]);
select pg_temp.expect_error('23505',$q$select pg_temp.change('00000000-0000-4000-8000-000000000002','grant','teacher',array['20000000-0000-4000-8000-000000000001']::uuid[])$q$);
reset role;
do $$begin
 if (select count(*) from public.branch_memberships where user_id='00000000-0000-4000-8000-000000000002' and is_active)<>2 then
   raise exception 'Multi-role grant erased existing scope';end if;
end $$;
-- Teacher changes are atomic and preserve other staff memberships.
set local role service_role;
select public.sai_manage_teacher_assignment('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','assign','40000000-0000-4000-8000-000000000001');
select public.sai_manage_teacher_assignment('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','reassign','40000000-0000-4000-8000-000000000002');
reset role;
do $$begin if (select count(*) from public.branch_memberships where user_id='00000000-0000-4000-8000-000000000002' and is_active)<>2 then
 raise exception 'Teacher reassign broke accountant scope';end if;end $$;

-- Direct linking is denied, verified RPC grants only student and retains links.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select pg_temp.expect_error('42501',$q$insert into public.students(branch_id,admission_no,full_name,user_id) values('20000000-0000-4000-8000-000000000001','BAD','Bad','00000000-0000-4000-8000-000000000005')$q$);
select public.admissions_link_student_account('50000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000005');
select pg_temp.expect_error('23505',$q$select public.admissions_link_student_account('50000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002')$q$);
reset role;
set local role service_role;
select pg_temp.change('00000000-0000-4000-8000-000000000004','grant','parent');
reset role;
set local role authenticated;
select public.admissions_verify_parent_student('50000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000004');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
set local role authenticated;
do $$begin if (select count(*) from public.students)<>1 then raise exception 'Parent isolation failed';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
set local role authenticated;
do $$begin if (select count(*) from public.students)<>1 then raise exception 'Student isolation failed';end if;end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$begin if (select count(*) from public.students where id='50000000-0000-4000-8000-000000000001')<>0
 or (select count(*) from public.students)<>1 then raise exception 'Teacher assigned-class isolation failed';end if;end $$;
reset role;
set local role service_role;
select pg_temp.change('00000000-0000-4000-8000-000000000005','grant','admin',array['20000000-0000-4000-8000-000000000001']::uuid[]);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000005',true);
set local role authenticated;
select pg_temp.expect_error('42501',$q$select public.admissions_link_student_account('50000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003')$q$);
do $$begin if (select count(*) from public.branch_memberships)<>1 then raise exception 'Membership privacy failed';end if;end $$;
reset role;

-- Audit failure rolls back the role, membership and profile mutation together.
insert into auth.users(id,email,email_confirmed_at) values('00000000-0000-4000-8000-000000000007','atomic@example.test',now());
create function pg_temp.reject_role_audit() returns trigger language plpgsql as $$begin
 if new.action='role_grant' then raise exception 'Synthetic audit rejection';end if;return new;end$$;
create trigger local_reject_role_audit before insert on public.audit_logs for each row execute function pg_temp.reject_role_audit();
set local role service_role;
select pg_temp.expect_error('P0001',$q$select pg_temp.change('00000000-0000-4000-8000-000000000007','grant','librarian',array['20000000-0000-4000-8000-000000000001']::uuid[])$q$);
reset role;
drop trigger local_reject_role_audit on public.audit_logs;
do $$begin
 if exists(select 1 from public.user_roles where user_id='00000000-0000-4000-8000-000000000007')
 or exists(select 1 from public.branch_memberships where user_id='00000000-0000-4000-8000-000000000007')
 or exists(select 1 from public.profiles where id='00000000-0000-4000-8000-000000000007') then
 raise exception 'Audit failure left partial authorization';end if;
end$$;
-- Table guard protects even owner-level accidental DELETE and role replacement.
select pg_temp.expect_error('23514',$q$delete from public.user_roles where role='super_admin'$q$);
select pg_temp.expect_error('23514',$q$update public.user_roles set role='student' where role='super_admin'$q$);
-- Isolate the cascade guard from Main's unrelated audit-actor RESTRICT FK.
savepoint cascade_guard;
insert into auth.users(id,email,email_confirmed_at) values('00000000-0000-4000-8000-000000000006','cascade@example.test',now());
insert into public.user_roles(user_id,role) values('00000000-0000-4000-8000-000000000006','super_admin');
delete from public.user_roles where user_id='00000000-0000-4000-8000-000000000001' and role='super_admin';
select pg_temp.expect_error('23514',$q$delete from auth.users where id='00000000-0000-4000-8000-000000000006'$q$);
rollback to cascade_guard;
set local role service_role;
select pg_temp.change('00000000-0000-4000-8000-000000000005','grant','super_admin','{}',true);
reset role;
update auth.users set banned_until=now()+interval '1 day' where id='00000000-0000-4000-8000-000000000005';
set local role service_role;
select pg_temp.expect_error('23514',$q$select pg_temp.change('00000000-0000-4000-8000-000000000001','revoke','super_admin')$q$);
reset role;
update auth.users set banned_until=null,deleted_at=now() where id='00000000-0000-4000-8000-000000000005';
set local role service_role;
select pg_temp.expect_error('23514',$q$select pg_temp.change('00000000-0000-4000-8000-000000000001','revoke','super_admin')$q$);
reset role;
update auth.users set deleted_at=null,email_confirmed_at=null where id='00000000-0000-4000-8000-000000000005';
set local role service_role;
select pg_temp.expect_error('23514',$q$select pg_temp.change('00000000-0000-4000-8000-000000000001','revoke','super_admin')$q$);
reset role;
-- Exercise every enum role through the secured API, with explicit scope.
do $$declare r public.app_role; target uuid; scope uuid[]; begin
 foreach r in array enum_range(null::public.app_role) loop
   target:=gen_random_uuid();
   insert into auth.users(id,email,email_confirmed_at) values(target,target::text||'@example.test',now());
   scope:=case when r in ('super_admin','student','parent') then '{}'::uuid[] else array['20000000-0000-4000-8000-000000000001']::uuid[] end;
   execute 'set local role service_role';
   perform pg_temp.change(target,'grant',r,scope,r='super_admin');
   execute 'reset role';
   if not exists(select 1 from public.user_roles where user_id=target and role=r) then raise exception 'Role % failed',r;end if;
   if (select email from public.profiles where id=target)<>target::text||'@example.test' then
     raise exception 'Service supplied identity replaced authoritative Auth data';end if;
 end loop;
end$$;
rollback;
select 'Behavior assertions passed; synthetic mutations rolled back' as result;
