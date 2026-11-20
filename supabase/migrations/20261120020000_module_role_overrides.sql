-- Per-role module overrides.
-- A module can be enabled globally (sai_module_toggles) yet switched off for a
-- specific role, e.g. on for teachers and off for students. Effective state for a
-- user = enabled if ANY of the user's roles resolves to enabled.
--
-- Read is open to all authenticated sessions (non-sensitive configuration);
-- writes are restricted to super_admin and every change is audited.

create table if not exists public.sai_module_role_overrides (
  module_id text not null,
  role app_role not null,
  enabled boolean not null,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  constraint sai_module_role_overrides_pkey primary key (module_id, role)
);

alter table public.sai_module_role_overrides enable row level security;

grant select, insert, update, delete on public.sai_module_role_overrides to authenticated;

drop policy if exists sai_module_role_overrides_read on public.sai_module_role_overrides;
create policy sai_module_role_overrides_read on public.sai_module_role_overrides
  for select using (true);

drop policy if exists sai_module_role_overrides_insert on public.sai_module_role_overrides;
create policy sai_module_role_overrides_insert on public.sai_module_role_overrides
  for insert with check (private.sai_security_has_role('super_admin'::app_role));

drop policy if exists sai_module_role_overrides_update on public.sai_module_role_overrides;
create policy sai_module_role_overrides_update on public.sai_module_role_overrides
  for update using (private.sai_security_has_role('super_admin'::app_role))
  with check (private.sai_security_has_role('super_admin'::app_role));

drop policy if exists sai_module_role_overrides_delete on public.sai_module_role_overrides;
create policy sai_module_role_overrides_delete on public.sai_module_role_overrides
  for delete using (private.sai_security_has_role('super_admin'::app_role));

create or replace function private.sai_module_role_override_audit()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'private'
as $function$
begin
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values ((select auth.uid()),
    case when tg_op = 'INSERT' then 'module_role_override:create'
         when tg_op = 'DELETE' then 'module_role_override:delete'
         else 'module_role_override:update' end,
    'sai_module_role_overrides', null,
    jsonb_build_object(
      'module_id', case when tg_op = 'DELETE' then old.module_id else new.module_id end,
      'role', case when tg_op = 'DELETE' then old.role else new.role end,
      'enabled', case when tg_op = 'DELETE' then old.enabled else new.enabled end));
  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;

drop trigger if exists sai_module_role_override_audit on public.sai_module_role_overrides;
create trigger sai_module_role_override_audit
  after insert or update or delete on public.sai_module_role_overrides
  for each row execute function private.sai_module_role_override_audit();