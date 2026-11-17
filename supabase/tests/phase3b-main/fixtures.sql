-- Synthetic records only. This file is loaded exclusively by run_local.py.
do $$begin if current_database()<>'phase3b_main' or replace(current_setting('data_directory'),'\','/') not like '%/.tmp-phase3b-main/%' then
 raise exception 'Task-owned isolated database required';end if;end$$;
insert into auth.users(id,email,email_confirmed_at) values
 ('00000000-0000-4000-8000-000000000001','admin@example.test',now()),
 ('00000000-0000-4000-8000-000000000002','target@example.test',now()),
 ('00000000-0000-4000-8000-000000000003','unconfirmed@example.test',null),
 ('00000000-0000-4000-8000-000000000004','parent@example.test',now()),
 ('00000000-0000-4000-8000-000000000005','other@example.test',now());
insert into public.user_roles(user_id,role) values
 ('00000000-0000-4000-8000-000000000001','super_admin');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
insert into public.profiles(id,full_name,email) select id,'Synthetic',email from auth.users;
insert into public.branches(id,name,code) values
 ('20000000-0000-4000-8000-000000000001','A','LOCAL_A'),
 ('20000000-0000-4000-8000-000000000002','B','LOCAL_B');
insert into public.academic_sessions(id,name,starts_on,ends_on,is_active) values
 ('30000000-0000-4000-8000-000000000001','Local',current_date,current_date+30,true);
insert into public.classes(id,branch_id,session_id,name,program) values
 ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Class A','Local'),
 ('40000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000001','Class B','Local');
insert into public.students(id,branch_id,admission_no,full_name,class_id) values
 ('50000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','LOCAL_A','Student A','40000000-0000-4000-8000-000000000001'),
 ('50000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','LOCAL_B','Student B','40000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
insert into public.sai_system_settings(category,setting_key,value_text) values
 ('general','college_name','Synthetic'),('general','website_url','http://legacy.example.test'),
 ('general','contact_email','local@example.test'),('general','contact_phone','123456'),
 ('general','address','Local'),('payments','default_currency','YER'),('printing','paper_size','A4');
update public.sai_system_settings set value_text='Synthetic updated' where category='general' and setting_key='college_name';
-- Main's identity audit column is modeled explicitly in this synthetic replay.
-- The baseline runner installs its captured sequence default before this file.
select set_config('request.jwt.claim.sub','',false);
create table public.phase3b_preservation_snapshot as select
 (select jsonb_agg(to_jsonb(s) order by category,setting_key) from public.sai_system_settings s) settings,
 (select jsonb_agg(to_jsonb(a) order by id) from public.sai_system_settings_audit a) settings_audit,
 (select jsonb_agg(to_jsonb(a) order by id) from public.audit_logs a) audit,
 (select jsonb_agg(to_jsonb(a) order by id) from auth.users a) accounts,
 (select jsonb_agg(to_jsonb(a) order by user_id,role) from public.user_roles a) roles,
 (select jsonb_agg(to_jsonb(a) order by user_id,branch_id) from public.branch_memberships a) memberships;
