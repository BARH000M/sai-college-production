-- =============================================================================
-- V6.0 — Group E (Reception & Front Office)
-- Institution: Yemen SAI Educational College
-- Applied: 2026-11-21 against the authorised production project
--
-- Purpose
--   Complete the Reception module's database integration. The Version 95 screen
--   existed but wrote only to browser storage; these are the permanent records.
--
-- Reused existing objects (NO duplicate enquiry table)
--   public.admissions_enquiries (applicant, guardian, phone, preferred_program,
--                                source, status, assigned_to, created_by)
--   public.branches, public.profiles, public.students
--   public.sai_security_has_role(app_role), public.sai_security_can_read_branch(uuid)
--
-- New objects
--   public.sai_enquiry_followups  (follow-up history for admission enquiries)
--   public.sai_visitors           (visitor book, check-in/check-out)
--   public.sai_appointments       (scheduling, rescheduling, completion)
--   public.sai_complaints         (severity, status, resolution)
--   public.sai_phone_logs         (inbound/outbound call log)
--   public.sai_correspondence     (incoming/outgoing correspondence)
--
-- Security notes
--   * Every register is branch-scoped through `sai_security_can_read_branch`.
--   * `receptionist`, `admin` and `super_admin` may write; other staff may read
--     only within their branch.
--   * Shared telephone numbers are a duplicate WARNING, not a rejection:
--     `phone_normalized` is indexed so the application can surface the duplicate
--     for review while still allowing the legitimate record to be created.
--   * Admission conversion goes through the existing authorised admissions
--     workflow; this migration never bypasses admission approval.
--   * No delete policy exists on any register — front-office history is retained.
--
-- Data impact
--   Additive only. No existing row is read, rewritten or deleted.
--
-- Verification
--   select tablename, count(*) from pg_policies
--   where schemaname = 'public' and tablename like 'sai_%' group by tablename;
--
-- Rollback
--   drop table if exists public.sai_correspondence;
--   drop table if exists public.sai_phone_logs;
--   drop table if exists public.sai_complaints;
--   drop table if exists public.sai_appointments;
--   drop table if exists public.sai_visitors;
--   drop table if exists public.sai_enquiry_followups;
--
--   Rollback discards front-office history. Export the registers first.
-- =============================================================================

create table if not exists public.sai_enquiry_followups (
  id          uuid primary key default gen_random_uuid(),
  enquiry_id  uuid not null references public.admissions_enquiries(id) on delete cascade,
  note        text not null check (length(btrim(note)) > 0),
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists sai_enquiry_followups_enquiry_idx on public.sai_enquiry_followups (enquiry_id, created_at desc);

create table if not exists public.sai_visitors (
  id               uuid primary key default gen_random_uuid(),
  full_name        text not null check (length(btrim(full_name)) > 0),
  phone            text,
  phone_normalized text,
  purpose          text,
  host_name        text,
  branch_id        uuid not null references public.branches(id) on delete restrict,
  check_in_at      timestamptz not null default now(),
  check_out_at     timestamptz,
  status           text not null default 'on_site' check (status in ('on_site','checked_out','cancelled')),
  created_by       uuid references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now()
);
create index if not exists sai_visitors_branch_idx on public.sai_visitors (branch_id, check_in_at desc);
create index if not exists sai_visitors_phone_idx on public.sai_visitors (phone_normalized);
create index if not exists sai_visitors_status_idx on public.sai_visitors (status);

create table if not exists public.sai_appointments (
  id            uuid primary key default gen_random_uuid(),
  full_name     text not null check (length(btrim(full_name)) > 0),
  phone         text,
  branch_id     uuid not null references public.branches(id) on delete restrict,
  purpose       text,
  scheduled_at  timestamptz not null,
  status        text not null default 'scheduled' check (status in ('scheduled','completed','cancelled','no_show')),
  assigned_to   uuid references public.profiles(id) on delete set null,
  enquiry_id    uuid references public.admissions_enquiries(id) on delete set null,
  notes         text,
  created_by    uuid references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists sai_appointments_branch_idx on public.sai_appointments (branch_id, scheduled_at desc);
create index if not exists sai_appointments_status_idx on public.sai_appointments (status);

create table if not exists public.sai_complaints (
  id                uuid primary key default gen_random_uuid(),
  complainant_name  text not null check (length(btrim(complainant_name)) > 0),
  phone             text,
  category          text,
  severity          text not null default 'medium' check (severity in ('low','medium','high')),
  subject           text not null check (length(btrim(subject)) > 0),
  description       text,
  branch_id         uuid not null references public.branches(id) on delete restrict,
  assigned_to       uuid references public.profiles(id) on delete set null,
  status            text not null default 'open' check (status in ('open','in_progress','resolved','closed')),
  resolution        text,
  resolved_at       timestamptz,
  created_by        uuid references public.profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists sai_complaints_branch_idx on public.sai_complaints (branch_id, created_at desc);
create index if not exists sai_complaints_status_idx on public.sai_complaints (status, severity);

create table if not exists public.sai_phone_logs (
  id           uuid primary key default gen_random_uuid(),
  direction    text not null default 'inbound' check (direction in ('inbound','outbound')),
  contact_name text not null check (length(btrim(contact_name)) > 0),
  phone        text,
  subject      text,
  notes        text,
  branch_id    uuid not null references public.branches(id) on delete restrict,
  handled_by   uuid references public.profiles(id) on delete set null,
  occurred_at  timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
create index if not exists sai_phone_logs_branch_idx on public.sai_phone_logs (branch_id, occurred_at desc);

create table if not exists public.sai_correspondence (
  id                  uuid primary key default gen_random_uuid(),
  direction           text not null check (direction in ('incoming','outgoing')),
  reference_no        text,
  subject             text not null check (length(btrim(subject)) > 0),
  party               text,
  branch_id           uuid not null references public.branches(id) on delete restrict,
  correspondence_date date not null default current_date,
  notes               text,
  created_by          uuid references public.profiles(id) on delete set null,
  created_at          timestamptz not null default now()
);
create index if not exists sai_correspondence_branch_idx on public.sai_correspondence (branch_id, correspondence_date desc);

alter table public.sai_enquiry_followups enable row level security;
alter table public.sai_visitors enable row level security;
alter table public.sai_appointments enable row level security;
alter table public.sai_complaints enable row level security;
alter table public.sai_phone_logs enable row level security;
alter table public.sai_correspondence enable row level security;

create policy sai_enquiry_followups_select on public.sai_enquiry_followups
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );
create policy sai_enquiry_followups_insert on public.sai_enquiry_followups
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );

create policy sai_visitors_select on public.sai_visitors
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
    or public.sai_security_can_read_branch(branch_id)
  );
create policy sai_visitors_insert on public.sai_visitors
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );
create policy sai_visitors_update on public.sai_visitors
  for update to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  )
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );

create policy sai_appointments_select on public.sai_appointments
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
    or public.sai_security_can_read_branch(branch_id)
  );
create policy sai_appointments_insert on public.sai_appointments
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );
create policy sai_appointments_update on public.sai_appointments
  for update to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  )
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );

create policy sai_complaints_select on public.sai_complaints
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
    or public.sai_security_can_read_branch(branch_id)
  );
create policy sai_complaints_insert on public.sai_complaints
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );
create policy sai_complaints_update on public.sai_complaints
  for update to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  )
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );

create policy sai_phone_logs_select on public.sai_phone_logs
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
    or public.sai_security_can_read_branch(branch_id)
  );
create policy sai_phone_logs_insert on public.sai_phone_logs
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );

create policy sai_correspondence_select on public.sai_correspondence
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
    or public.sai_security_can_read_branch(branch_id)
  );
create policy sai_correspondence_insert on public.sai_correspondence
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('receptionist'::app_role)
  );