-- Module on/off toggles: super administrators can hide a module across the portal.
-- The table is readable by every authenticated user (navigation must respect it)
-- but writable only by super_admin. Every change is mirrored into audit_logs.

create table if not exists public.sai_module_toggles (
  module_id text primary key,
  enabled boolean not null default true,
  updated_by uuid default auth.uid(),
  updated_at timestamptz not null default now()
);

alter table public.sai_module_toggles enable row level security;

revoke all on public.sai_module_toggles from anon;
grant select on public.sai_module_toggles to authenticated;
grant insert, update, delete on public.sai_module_toggles to authenticated;
grant all on public.sai_module_toggles to service_role;

drop policy if exists sai_module_toggles_read on public.sai_module_toggles;
create policy sai_module_toggles_read on public.sai_module_toggles
  for select to authenticated using (true);

drop policy if exists sai_module_toggles_insert on public.sai_module_toggles;
create policy sai_module_toggles_insert on public.sai_module_toggles
  for insert to authenticated
  with check (private.sai_security_has_role('super_admin'::app_role));

drop policy if exists sai_module_toggles_update on public.sai_module_toggles;
create policy sai_module_toggles_update on public.sai_module_toggles
  for update to authenticated
  using (private.sai_security_has_role('super_admin'::app_role))
  with check (private.sai_security_has_role('super_admin'::app_role));

drop policy if exists sai_module_toggles_delete on public.sai_module_toggles;
create policy sai_module_toggles_delete on public.sai_module_toggles
  for delete to authenticated
  using (private.sai_security_has_role('super_admin'::app_role));

create or replace function private.sai_module_toggle_audit()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','private'
as $function$
begin
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values ((select auth.uid()),
    case when tg_op = 'INSERT' then 'module_toggle:create'
         when tg_op = 'DELETE' then 'module_toggle:delete'
         else 'module_toggle:update' end,
    'sai_module_toggles', null,
    jsonb_build_object('module_id', new.module_id, 'enabled', new.enabled));
  return new;
end;
$function$;

drop trigger if exists sai_module_toggle_audit on public.sai_module_toggles;
create trigger sai_module_toggle_audit
  after insert or update or delete on public.sai_module_toggles
  for each row execute function private.sai_module_toggle_audit();