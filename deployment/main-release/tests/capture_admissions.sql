-- Same-session snapshot across the disposable release transaction.
create temporary table release_admissions_baseline as
select p.oid, pg_catalog.pg_get_functiondef(p.oid) as definition,
       p.proowner, p.proacl, p.proconfig, p.prosecdef
from pg_catalog.pg_proc p
where p.oid in (
  'public.sai_admissions_prepare()'::regprocedure,
  'public.sai_admissions_audit()'::regprocedure,
  'public.sai_public_admission_submit(text,text,text,text,text)'::regprocedure,
  'public.sai_submit_application(text,text,text,text,text,text,text)'::regprocedure
);
create temporary table release_admissions_triggers as
select t.oid, pg_catalog.pg_get_triggerdef(t.oid) as definition, t.tgenabled
from pg_catalog.pg_trigger t
where t.tgrelid = 'public.admissions_enquiries'::regclass
  and t.tgname in ('admissions_prepare', 'admissions_audit') and not t.tgisinternal;
do $$ begin
  if (select count(*) from release_admissions_baseline) <> 4
     or (select count(*) from release_admissions_triggers) <> 2 then
    raise exception 'MAIN-like admissions baseline is incomplete';
  end if;
end $$;
