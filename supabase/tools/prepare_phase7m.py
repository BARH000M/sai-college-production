"""Offline, explicit preparation of Main compatibility proposals; never connects to a DB."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'supabase/deployment/phase7m'

def prepare():
    OUT.mkdir(exist_ok=True)
    source = (ROOT/'supabase/migrations/20261115051532_finance_scoped_directories.sql').read_text(encoding='utf-8')
    # Main's existing ledger functions are owned by postgres, not the absent
    # historical private-ledger role. Do not create that role or replay 007.
    start = source.index('grant usage on schema private to sai_finance_owner;')
    end = source.index('alter table public.fee_groups add constraint')
    source = source[:start] + source[end:]
    source = source[source.index('create or replace function'):]
    source = source.replace('alter function public.sai_finance_students() owner to sai_finance_owner;', '')
    source = source.replace('alter function public.sai_finance_group_labels() owner to sai_finance_owner;', '')
    source = source.replace('alter function public.sai_finance_sessions() owner to sai_finance_owner;', '')
    ledger=(ROOT/'supabase/migrations/019_public_finance.sql').read_text(encoding='utf-8')
    # The historical restricted owner supplied an additional RLS boundary.
    # Main's postgres-owned RPCs bypass it: enforce the same role rule in code.
    for name in ('sai_finance_groups','sai_finance_pay'):
        match=re.search(r'create or replace function public\.'+name+r'\(.*?\$\$;',ledger,re.S)
        assert match, name
        source+='\n'+match[0].replace("array['admin', 'accountant', 'receptionist']", "array['admin', 'accountant']")+'\n'
    (OUT/'01_finance_main.sql').write_text('''-- Phase 7-M Main-only forward proposal. No historical private ledger replay.
begin;
set local lock_timeout = '10s';
set local statement_timeout = '60s';
do $$ begin
  if to_regnamespace('sai_finance') is not null
    or exists(select 1 from pg_roles where rolname='sai_finance_owner')
    or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.proname like 'sai_finance_%' and pg_get_userbyid(p.proowner)<>'postgres')
    or to_regprocedure('public.sai_finance_students()') is not null then
    raise exception 'Unexpected finance baseline; stop for reconciliation';
  end if;
end $$;
''' + source + '\ncommit;\n', encoding='utf-8')

    source = (ROOT/'supabase/migrations/20261116013952_phase2b_system_settings.sql').read_text(encoding='utf-8')
    start = source.index('create table public.sai_system_settings (')
    end = source.index('alter table public.sai_system_settings enable row level security;')
    source = source[:start] + '''-- Keep existing values, nullable legacy provenance and legacy audit rows.
-- Remove only the two known triggers while deriving new metadata columns.
drop trigger sai_system_settings_stamp_trigger on public.sai_system_settings;
drop trigger sai_system_settings_audit_trigger on public.sai_system_settings;
alter table public.sai_system_settings add column value_type text;
alter table public.sai_system_settings add column scope text not null default 'global'
  check (scope='global');
update public.sai_system_settings set value_type=private.sai_setting_definition(category,setting_key)->>'type';
alter table public.sai_system_settings alter column value_type set not null;
create trigger sai_system_settings_stamp_trigger before insert or update on public.sai_system_settings
  for each row execute function private.sai_system_settings_stamp();
create trigger sai_system_settings_audit_trigger after insert or update or delete on public.sai_system_settings
  for each row execute function private.sai_system_settings_log();
''' + source[end:]
    # Existing invalid HTTPS values survive unchanged. All inserts and changed
    # URL values must meet the new contract; no value is silently repaired.
    source = source.replace("if new.setting_key='website_url' and new.value_text<>'' and new.value_text !~", "if new.setting_key='website_url' and (tg_op='INSERT' or new.value_text is distinct from old.value_text) and new.value_text<>'' and new.value_text !~")
    source = source.replace('begin;\ncreate function', "begin;\nset local lock_timeout='10s';\nset local statement_timeout='60s';\ncreate function", 1)
    (OUT/'02_settings_main.sql').write_text('-- Phase 7-M additive Main compatibility proposal; no activation or value rewrite.\n'+source,encoding='utf-8')
    tracking=(ROOT/'supabase/migrations/20261115001316_secure_admission_tracking_and_verified_links.sql').read_text(encoding='utf-8')
    enrollment=(ROOT/'supabase/migrations/031_admissions_status_and_enrollment.sql').read_text(encoding='utf-8')
    # 3B already installs the stronger linking implementation. Keep it intact.
    tracking=tracking[:tracking.index('create function public.admissions_link_student_account')]+tracking[tracking.index('revoke all on function public.admissions_public_rate_limit'):tracking.index('revoke all on function public.admissions_link_student_account')]+tracking[tracking.rindex('do $$'):]
    tracking=tracking.replace('begin;','',1)
    (OUT/'03_admissions_remaining.sql').write_text('-- Deferred coordinated admission-tracking cutover; requires Phase 3B onboarding.\nbegin;\n'+enrollment+'\n'+tracking,encoding='utf-8')
    (OUT/'04_admission_events.sql').write_text((ROOT/'supabase/migrations/20261115014149_protected_admission_status_events.sql').read_text(encoding='utf-8'),encoding='utf-8')

if __name__ == '__main__':
    prepare()
    print('Prepared two offline Main-specific proposals; no DB connection')
