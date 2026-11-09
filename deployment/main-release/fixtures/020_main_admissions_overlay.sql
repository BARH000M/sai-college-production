-- The runner installs four exact function definitions from the pinned MAIN dump
-- before this overlay. 004's directory conflicts with the saved MAIN state.
drop function public.sai_admissions_sessions(uuid);
create sequence public.admissions_application_no_seq start with 1042;
alter sequence public.admissions_application_no_seq owned by public.admissions_enquiries.application_no;
alter table public.admissions_enquiries alter column application_no
  set default ('SAI-APP-'::text || nextval('public.admissions_application_no_seq'::regclass));

-- The source dump excludes ACLs; these are test assumptions, not MAIN evidence.
-- Direct staff inserts run as authenticated, so their default needs nextval.
revoke all on sequence public.admissions_application_no_seq from public, anon, authenticated;
grant usage on sequence public.admissions_application_no_seq to authenticated;
revoke all on function public.sai_public_admission_submit(text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.sai_public_admission_submit(text,text,text,text,text) to anon, authenticated;
revoke all on function public.sai_submit_application(text,text,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.sai_submit_application(text,text,text,text,text,text,text) to anon, authenticated;

-- Synthetic tracking only: never copy or apply these records to any live project.
create schema supabase_migrations;
create table supabase_migrations.schema_migrations (version text primary key, name text);
insert into supabase_migrations.schema_migrations (version, name) values
 ('001','synthetic_initial_schema'), ('002','synthetic_security_policies'),
 ('003','synthetic_staff_management'), ('004','synthetic_main_admissions_overlay');
