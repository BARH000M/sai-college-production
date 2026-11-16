// Local artifact generator only. Never connects to a database or deploys code.
const fs = require('node:fs');
const path = require('node:path');
const { stripTypeScriptTypes } = require('node:module');
const root = path.resolve(__dirname, '..');
const migrations = path.join(root, 'supabase/migrations');
async function main() {
  const source = fs.readFileSync(path.join(root, 'src/portal/lib/systemSettings.ts'), 'utf8')
    .replace('import { supabase } from "./supabase";', 'const supabase = {};');
  const { settingsSections } = await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source, { mode: 'strip' })).toString('base64')}`);
  const definitions = Object.fromEntries(settingsSections.map(section => [section.category,
    Object.fromEntries(section.fields.map(field => [field.key, { type: field.type ?? 'text', sensitive: !!section.superOnly, ...(field.options ? { options: field.options } : {}) }]))]));
  const proposals = fs.readdirSync(migrations).filter(f => /_phase2b_(service_permissions|system_settings)\.sql$/.test(f)).sort();
  if (proposals.length !== 2) throw Error('Create exactly two proposals with supabase migration new first.');
  // The CLI host clock is behind the latest checked-in migration. Preserve CLI
  // creation, but advance proposal versions deterministically past the baseline.
  let latest = fs.readdirSync(migrations).filter(f => !f.includes('_phase2b_')).map(f => f.split('_')[0]).sort().at(-1);
  const names = [];
  for (const oldName of proposals) {
    const suffix = oldName.slice(oldName.indexOf('_'));
    const version = oldName.split('_')[0] > latest ? oldName.split('_')[0] : String(BigInt(latest) + 1n);
    const newName = version + suffix;
    if (newName !== oldName) fs.renameSync(path.join(migrations, oldName), path.join(migrations, newName));
    latest = version; names.push(newName);
  }
  const service = names.find(f => f.endsWith('_service_permissions.sql'));
  const settings = names.find(f => f.endsWith('_system_settings.sql'));
  fs.writeFileSync(path.join(migrations, service), `-- REVIEW PROPOSAL ONLY: do not apply without Phase 2C approval.
-- Baseline: 36 migrations through 20261116013950. No role assignments.
begin;
-- Public schema USAGE already exists. Authenticated RPC EXECUTE already exists.
grant select (user_id, role) on public.user_roles to service_role;
grant select (id, full_name, email) on public.profiles to service_role;
grant select (id, name, is_active) on public.branches to service_role;
grant select (user_id, branch_id, is_active) on public.branch_memberships to service_role;
grant select (id, full_name, admission_no, class_id, user_id, status, branch_id) on public.students to service_role;
grant select (parent_user_id, student_id, verified_at) on public.parent_student_links to service_role;
grant select (id, name, program, branch_id, teacher_id, is_active) on public.classes to service_role;
grant select (id) on public.academic_sessions to service_role;
grant select (id, class_id, teacher_id, title, is_active, branch_id) on public.learning_courses to service_role;
grant select (id, is_published, content_path, content_body, content_url, content_kind) on public.learning_lessons to service_role;
grant select (lesson_id, status) on public.learning_lesson_progress to service_role;
grant select (id, course_id) on public.learning_homework to service_role;
grant select (id, homework_id, status) on public.learning_homework_submissions to service_role;
grant select (id, status) on public.admissions_enquiries to service_role;
-- Exact service payload columns; no student, parent-link or fee writes.
grant insert (id, full_name, email), update (id, full_name, email)
  on public.profiles to service_role;
-- Role upserts use ignoreDuplicates (ON CONFLICT DO NOTHING), not UPDATE.
grant insert (user_id, role, assigned_by), delete on public.user_roles to service_role;
grant insert (user_id, branch_id, is_active),
  update (user_id, branch_id, is_active), delete on public.branch_memberships to service_role;
grant update (teacher_id) on public.classes, public.learning_courses to service_role;
grant insert (actor_user_id, action, entity_type, entity_id, metadata)
  on public.audit_logs to service_role;
commit;
`);
  fs.writeFileSync(path.join(migrations, settings), `-- REVIEW PROPOSAL ONLY: no application or database execution in Phase 2B.
-- Uses the existing private.sai_security_has_role(app_role) authorization contract.
-- All settings are GLOBAL non-secret preferences. No branch inheritance or activation.
begin;
create function private.sai_setting_definition(p_category text, p_key text)
returns jsonb language sql immutable security invoker set search_path = pg_catalog
as $definition$ select '${JSON.stringify(definitions).replaceAll("'", "''")}'::jsonb -> p_category -> p_key $definition$;
revoke all on function private.sai_setting_definition(text,text) from public, anon, authenticated, service_role;
grant execute on function private.sai_setting_definition(text,text) to authenticated;

create table public.sai_system_settings (
  category text not null,
  setting_key text not null,
  value_text text not null check (char_length(value_text) <= 2000),
  value_type text not null,
  scope text not null default 'global' check (scope = 'global'),
  updated_at timestamptz not null,
  updated_by uuid not null references auth.users(id),
  primary key (category, setting_key),
  check (private.sai_setting_definition(category, setting_key) is not null)
);
alter table public.sai_system_settings enable row level security;
revoke all on public.sai_system_settings from public, anon, authenticated, service_role;
grant select on public.sai_system_settings to authenticated;
-- Includes PK columns for PostgREST merge-duplicate upserts. Trigger forbids changes.
grant insert (category, setting_key, value_text), update (category, setting_key, value_text)
  on public.sai_system_settings to authenticated;
create policy settings_authorized_read on public.sai_system_settings for select to authenticated
using ((select private.sai_security_has_role('super_admin'::public.app_role))
  or ((select private.sai_security_has_role('admin'::public.app_role))
    and not (private.sai_setting_definition(category,setting_key)->>'sensitive')::boolean));
create policy settings_super_insert on public.sai_system_settings for insert to authenticated
with check ((select private.sai_security_has_role('super_admin'::public.app_role)));
create policy settings_super_update on public.sai_system_settings for update to authenticated
using ((select private.sai_security_has_role('super_admin'::public.app_role)))
with check ((select private.sai_security_has_role('super_admin'::public.app_role)));

create function private.validate_system_setting()
returns trigger language plpgsql security invoker set search_path = pg_catalog
as $$
declare d jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if tg_op='UPDATE' and (new.category,new.setting_key,new.scope) is distinct from (old.category,old.setting_key,old.scope) then
    raise exception 'Setting identity is immutable' using errcode='22023';
  end if;
  d := private.sai_setting_definition(new.category,new.setting_key);
  if d is null then raise exception 'Unknown setting' using errcode='22023'; end if;
  new.value_text := btrim(new.value_text);
  new.value_type := d->>'type';
  if new.value_text ~* '(Bearer[[:space:]]|sb_secret_|sbp_|-----BEGIN|eyJ[A-Za-z0-9_-]+[.])' then
    raise exception 'Credentials are not settings' using errcode='22023';
  end if;
  if (new.value_type='boolean' and new.value_text not in ('true','false'))
    or (new.value_type='select' and not ((d->'options') ? new.value_text))
    or (new.value_type='number' and (new.value_text !~ '^[0-9]{1,4}$')) then
    raise exception 'Invalid setting value' using errcode='22023';
  end if;
  -- Guard the cast procedurally; do not rely on SQL boolean evaluation order.
  if new.value_type='number' then
    if new.value_text::integer > 3650 then
      raise exception 'Invalid number' using errcode='22023';
    end if;
  end if;
  if new.value_type='email' and new.value_text<>'' and new.value_text !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then
    raise exception 'Invalid email' using errcode='22023'; end if;
  if new.setting_key='website_url' and new.value_text<>'' and new.value_text !~ '^https://[^[:space:]@/?#]+([/?#][^[:space:]]*)?$' then
    raise exception 'HTTPS website required' using errcode='22023'; end if;
  new.updated_at := clock_timestamp(); new.updated_by := auth.uid();
  return new;
end;
$$;
revoke all on function private.validate_system_setting() from public, anon, authenticated, service_role;
create trigger validate_system_setting before insert or update on public.sai_system_settings
for each row execute function private.validate_system_setting();

-- Trusted, append-only audit. Ordinary browser audit_logs inserts are not evidence.
create table private.sai_system_settings_audit (
  id uuid primary key default gen_random_uuid(),
  category text not null, setting_key text not null,
  old_value text, new_value text not null, actor_user_id uuid not null,
  occurred_at timestamptz not null default clock_timestamp()
);
create index settings_audit_history on private.sai_system_settings_audit(category,setting_key,occurred_at,id);
alter table private.sai_system_settings_audit enable row level security;
revoke all on private.sai_system_settings_audit from public, anon, authenticated, service_role;
grant select on private.sai_system_settings_audit to authenticated;
create policy settings_audit_super_read on private.sai_system_settings_audit for select to authenticated
using ((select private.sai_security_has_role('super_admin'::public.app_role)));
create role sai_settings_audit_writer nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
do $$ begin execute format('grant sai_settings_audit_writer to %I with set true, inherit false',current_user); end $$;
grant usage on schema private, auth to sai_settings_audit_writer;
grant execute on function auth.uid() to sai_settings_audit_writer;
grant insert on private.sai_system_settings_audit to sai_settings_audit_writer;
create policy settings_audit_trigger_insert on private.sai_system_settings_audit for insert to sai_settings_audit_writer
with check (actor_user_id = (select auth.uid()));
create function private.audit_system_setting()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
begin
  if tg_table_schema<>'public' or tg_table_name<>'sai_system_settings' or tg_when<>'AFTER' or tg_level<>'ROW' then
    raise exception 'Settings row trigger required'; end if;
  if tg_op='INSERT' then
    insert into private.sai_system_settings_audit(category,setting_key,new_value,actor_user_id)
      values(new.category,new.setting_key,new.value_text,auth.uid());
  elsif old.value_text is distinct from new.value_text then
    insert into private.sai_system_settings_audit(category,setting_key,old_value,new_value,actor_user_id)
      values(new.category,new.setting_key,old.value_text,new.value_text,auth.uid());
  end if;
  return new;
end;
$$;
revoke all on function private.audit_system_setting() from public, anon, authenticated, service_role;
create trigger audit_system_setting after insert or update on public.sai_system_settings
for each row execute function private.audit_system_setting();
grant create on schema private to sai_settings_audit_writer;
alter function private.audit_system_setting() owner to sai_settings_audit_writer;
revoke create on schema private from sai_settings_audit_writer;
do $$ begin execute format('revoke sai_settings_audit_writer from %I',current_user); end $$;
-- No seeded values: absence is unconfigured, never permission or feature activation.
commit;
`);
  console.log(JSON.stringify({ service, settings, categories: settingsSections.length, keys: Object.values(definitions).reduce((n, x) => n + Object.keys(x).length, 0) }));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
