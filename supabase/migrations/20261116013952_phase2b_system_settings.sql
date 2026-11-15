-- REVIEW PROPOSAL ONLY: no application or database execution in Phase 2B.
-- Uses the existing private.sai_security_has_role(app_role) authorization contract.
-- All settings are GLOBAL non-secret preferences. No branch inheritance or activation.
begin;
create function private.sai_setting_definition(p_category text, p_key text)
returns jsonb language sql immutable security invoker set search_path = pg_catalog
as $definition$ select '{"general":{"college_name":{"type":"text","sensitive":false},"website_url":{"type":"text","sensitive":false},"contact_email":{"type":"email","sensitive":false},"contact_phone":{"type":"text","sensitive":false},"address":{"type":"text","sensitive":false}},"sessions":{"default_session_id":{"type":"text","sensitive":false},"registration_open":{"type":"boolean","sensitive":false}},"notifications":{"push_enabled":{"type":"boolean","sensitive":false},"digest_enabled":{"type":"boolean","sensitive":false},"quiet_hours":{"type":"text","sensitive":false}},"sms":{"enabled":{"type":"boolean","sensitive":false},"provider_name":{"type":"text","sensitive":false},"sender_name":{"type":"text","sensitive":false}},"whatsapp":{"enabled":{"type":"boolean","sensitive":false},"business_number":{"type":"text","sensitive":false},"template_namespace":{"type":"text","sensitive":false}},"email":{"enabled":{"type":"boolean","sensitive":false},"sender_address":{"type":"email","sensitive":false},"sender_name":{"type":"text","sensitive":false}},"payments":{"default_currency":{"type":"text","sensitive":false},"invoice_prefix":{"type":"text","sensitive":false},"enabled_methods":{"type":"text","sensitive":false}},"printing":{"paper_size":{"type":"select","sensitive":false,"options":["A4","Letter"]},"header_text":{"type":"text","sensitive":false},"footer_text":{"type":"text","sensitive":false}},"cms":{"site_title":{"type":"text","sensitive":false},"default_locale":{"type":"select","sensitive":false,"options":["ar","en","zh"]},"public_notice":{"type":"text","sensitive":false}},"backups":{"retention_days":{"type":"number","sensitive":true},"alert_email":{"type":"email","sensitive":true}},"languages":{"default_locale":{"type":"select","sensitive":false,"options":["ar","en","zh"]},"enabled_locales":{"type":"text","sensitive":false},"timezone":{"type":"select","sensitive":false,"options":["Asia/Aden","UTC"]}},"currencies":{"base_currency":{"type":"text","sensitive":false},"enabled_currencies":{"type":"text","sensitive":false}},"extensions":{"enabled_module_ids":{"type":"text","sensitive":true},"enabled_plugin_ids":{"type":"text","sensitive":true}},"custom_fields":{"student_form_schema":{"type":"text","sensitive":false},"admissions_form_schema":{"type":"text","sensitive":false}},"verification":{"certificate_verification_enabled":{"type":"boolean","sensitive":true},"guardian_check_required":{"type":"boolean","sensitive":true}},"updates":{"release_channel":{"type":"select","sensitive":true,"options":["stable","beta"]},"maintenance_notice":{"type":"text","sensitive":true}}}'::jsonb -> p_category -> p_key $definition$;
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
