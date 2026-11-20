-- Backup & Disaster Recovery: run/audit ledger for database and storage backups.
-- Reads are limited to super_admin; all writes are performed via the service role
-- (backup-manager Edge Function and the external pg_dump worker).

create table if not exists public.sai_backup_runs (
  id uuid primary key default gen_random_uuid(),
  provider text not null default 'manual',
  kind text not null default 'full',
  status text not null default 'requested',
  retention_class text not null default 'daily',
  size_bytes bigint,
  checksum text,
  location text,
  external_ref text,
  manifest jsonb,
  requested_by uuid,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  error text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists sai_backup_runs_created_idx on public.sai_backup_runs (created_at desc);
create index if not exists sai_backup_runs_status_idx on public.sai_backup_runs (status);

alter table public.sai_backup_runs enable row level security;

revoke all on public.sai_backup_runs from anon;
revoke all on public.sai_backup_runs from authenticated;
grant select on public.sai_backup_runs to authenticated;
grant all on public.sai_backup_runs to service_role;

drop policy if exists sai_backup_runs_select on public.sai_backup_runs;
create policy sai_backup_runs_select on public.sai_backup_runs
  for select to authenticated
  using (private.sai_security_has_role('super_admin'::app_role));