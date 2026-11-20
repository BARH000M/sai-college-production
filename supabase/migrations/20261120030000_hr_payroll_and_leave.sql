-- Phase 5A second slice: HR payroll entries and leave requests.
-- Branch-scoped, staff-authorized, audited via created_by/updated_by columns.
-- Payroll and leave remain non-public: only branch admins (and super admin /
-- accountant for payroll) can read them.

create table if not exists public.sai_hr_payroll_entries (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  employee_id uuid not null references public.sai_hr_employees(id) on delete cascade,
  period_month date not null,
  base_salary numeric(12,2) not null default 0,
  allowances numeric(12,2) not null default 0,
  deductions numeric(12,2) not null default 0,
  net_amount numeric(12,2) generated always as (base_salary + allowances - deductions) stored,
  status text not null default 'draft',
  note text,
  created_by uuid not null default auth.uid(),
  updated_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, period_month),
  constraint sai_hr_payroll_amounts_ck
    check (base_salary >= 0 and allowances >= 0 and deductions >= 0 and base_salary + allowances >= deductions),
  constraint sai_hr_payroll_status_ck check (status in ('draft','approved','paid')),
  constraint sai_hr_payroll_period_ck check (date_trunc('month', period_month) = period_month)
);

create index if not exists sai_hr_payroll_branch_period_idx
  on public.sai_hr_payroll_entries(branch_id, period_month desc, status);

alter table public.sai_hr_payroll_entries enable row level security;
revoke all on public.sai_hr_payroll_entries from public, anon;
grant select on public.sai_hr_payroll_entries to authenticated;
grant insert (branch_id, employee_id, period_month, base_salary, allowances, deductions, status, note, created_by, updated_by)
  on public.sai_hr_payroll_entries to authenticated;
grant update (base_salary, allowances, deductions, status, note, updated_by, updated_at)
  on public.sai_hr_payroll_entries to authenticated;

create policy sai_hr_payroll_read on public.sai_hr_payroll_entries
  for select to authenticated
  using (public.sai_security_has_role('super_admin')
    or ((public.sai_security_has_role('admin') or public.sai_security_has_role('accountant'))
      and public.sai_security_branch_member(branch_id)));

create policy sai_hr_payroll_insert on public.sai_hr_payroll_entries
  for insert to authenticated
  with check (created_by = (select auth.uid()) and updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))));

create policy sai_hr_payroll_update on public.sai_hr_payroll_entries
  for update to authenticated
  using (public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)))
  with check (updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))));

create table if not exists public.sai_hr_leave_requests (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  employee_id uuid not null references public.sai_hr_employees(id) on delete cascade,
  leave_type text not null,
  starts_on date not null,
  ends_on date not null,
  days integer generated always as ((ends_on - starts_on) + 1) stored,
  reason text,
  status text not null default 'pending',
  decision_note text,
  decided_by uuid,
  decided_at timestamptz,
  created_by uuid not null default auth.uid(),
  updated_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sai_hr_leave_type_ck check (leave_type in ('annual','sick','unpaid','maternity','emergency','other')),
  constraint sai_hr_leave_status_ck check (status in ('pending','approved','rejected','cancelled')),
  constraint sai_hr_leave_range_ck check (ends_on >= starts_on)
);

create index if not exists sai_hr_leave_branch_status_idx
  on public.sai_hr_leave_requests(branch_id, status, starts_on desc);

alter table public.sai_hr_leave_requests enable row level security;
revoke all on public.sai_hr_leave_requests from public, anon;
grant select on public.sai_hr_leave_requests to authenticated;
grant insert (branch_id, employee_id, leave_type, starts_on, ends_on, reason, created_by, updated_by)
  on public.sai_hr_leave_requests to authenticated;
grant update (status, decision_note, decided_by, decided_at, updated_by, updated_at)
  on public.sai_hr_leave_requests to authenticated;

create policy sai_hr_leave_read on public.sai_hr_leave_requests
  for select to authenticated
  using (public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)));

create policy sai_hr_leave_insert on public.sai_hr_leave_requests
  for insert to authenticated
  with check (created_by = (select auth.uid()) and updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))));

create policy sai_hr_leave_update on public.sai_hr_leave_requests
  for update to authenticated
  using (public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)))
  with check (updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))));