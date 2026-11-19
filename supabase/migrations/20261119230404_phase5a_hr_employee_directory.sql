-- Phase 5A first slice: branch-scoped, non-financial employee directory.
-- Contracts, personal documents, attendance and payroll use separate contracts.
create table public.sai_hr_employees (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  title text not null check (length(btrim(title)) between 1 and 200),
  description text,
  employee_code text not null check (length(btrim(employee_code)) between 1 and 40),
  department text not null check (length(btrim(department)) between 1 and 120),
  designation text not null check (length(btrim(designation)) between 1 and 120),
  contact_phone text,
  contact_email text,
  hired_on date,
  employment_status text not null default 'active'
    check (employment_status in ('active', 'on_leave', 'suspended', 'terminated')),
  created_by uuid not null default auth.uid() references auth.users(id),
  updated_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, employee_code)
);

create index sai_hr_employees_branch_status_idx
  on public.sai_hr_employees(branch_id, employment_status, title);

alter table public.sai_hr_employees enable row level security;
revoke all on public.sai_hr_employees from public, anon, authenticated;
grant select on public.sai_hr_employees to authenticated;
grant insert (branch_id, title, description, employee_code, department, designation,
  contact_phone, contact_email, hired_on, employment_status)
  on public.sai_hr_employees to authenticated;
grant update (title, description, employee_code, department, designation,
  contact_phone, contact_email, hired_on, employment_status)
  on public.sai_hr_employees to authenticated;

create policy sai_hr_employees_read on public.sai_hr_employees
  for select to authenticated
  using (public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin')
      and public.sai_security_branch_member(branch_id)));

create policy sai_hr_employees_insert on public.sai_hr_employees
  for insert to authenticated
  with check (created_by = (select auth.uid())
    and updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin')
        and public.sai_security_branch_member(branch_id))));

create policy sai_hr_employees_update on public.sai_hr_employees
  for update to authenticated
  using (public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin')
      and public.sai_security_branch_member(branch_id)))
  with check (updated_by = (select auth.uid())
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_has_role('admin')
        and public.sai_security_branch_member(branch_id))));

create function public.sai_hr_set_employee_audit_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.title := btrim(new.title);
  new.employee_code := btrim(new.employee_code);
  new.department := btrim(new.department);
  new.designation := btrim(new.designation);
  if new.description is not null then
    new.description := nullif(btrim(new.description), '');
  end if;
  if new.contact_phone is not null then
    new.contact_phone := nullif(btrim(new.contact_phone), '');
  end if;
  if new.contact_email is not null then
    new.contact_email := nullif(btrim(new.contact_email), '');
  end if;
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
  end if;
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public.sai_hr_set_employee_audit_fields() from public, anon, authenticated;
create trigger sai_hr_employee_audit_fields
  before insert or update on public.sai_hr_employees
  for each row execute function public.sai_hr_set_employee_audit_fields();