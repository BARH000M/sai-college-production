-- Migration 019 replaced the ledger functions but retained their restricted
-- owner from 007. Give only that NOLOGIN owner the public-ledger access they
-- need, and keep row scope enforced independently of the function checks.
grant usage on schema private to sai_finance_owner;
grant execute on function private.sai_finance_staff(uuid, text[]), private.sai_finance_has_role(text[]),
  private.sai_finance_can_read_student(uuid, uuid) to sai_finance_owner;
grant execute on function public.sai_finance_staff(uuid, text[]),
  public.sai_finance_has_role(text[]), public.sai_finance_can_read_student(uuid, uuid),
  public.sai_finance_balance(uuid) to sai_finance_owner;
grant select, insert, update on public.fee_groups, public.fee_assignments, public.fee_payments to sai_finance_owner;
grant select, insert on public.fee_waivers, public.fee_refunds, public.finance_audit_log to sai_finance_owner;
grant usage on sequence public.finance_receipt_seq, public.finance_refund_seq,
  public.finance_audit_log_id_seq to sai_finance_owner;

create policy finance_owner_groups_read on public.fee_groups for select to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']));
create policy finance_owner_groups_write on public.fee_groups for all to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['admin', 'accountant']))
  with check (private.sai_finance_staff(branch_id, array['admin', 'accountant']));
create policy finance_owner_assignments_read on public.fee_assignments for select to sai_finance_owner
  using (private.sai_finance_can_read_student(student_id, branch_id));
create policy finance_owner_assignments_insert on public.fee_assignments for insert to sai_finance_owner
  with check (private.sai_finance_staff(branch_id, array['admin', 'accountant']));
create policy finance_owner_assignments_update on public.fee_assignments for update to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']))
  with check (private.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']));
create policy finance_owner_payments_read on public.fee_payments for select to sai_finance_owner
  using (exists (select 1 from public.fee_assignments a where a.id = assignment_id
    and private.sai_finance_can_read_student(a.student_id, a.branch_id)));
create policy finance_owner_payments_insert on public.fee_payments for insert to sai_finance_owner
  with check (private.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']));
create policy finance_owner_payments_update on public.fee_payments for update to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['accountant']))
  with check (private.sai_finance_staff(branch_id, array['accountant']));
create policy finance_owner_waivers_read on public.fee_waivers for select to sai_finance_owner
  using (exists (select 1 from public.fee_assignments a where a.id = assignment_id
    and private.sai_finance_can_read_student(a.student_id, a.branch_id)));
create policy finance_owner_waivers_insert on public.fee_waivers for insert to sai_finance_owner
  with check (exists (select 1 from public.fee_assignments a where a.id = assignment_id
    and private.sai_finance_staff(a.branch_id, array['accountant'])));
create policy finance_owner_refunds_read on public.fee_refunds for select to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['accountant']));
create policy finance_owner_refunds_insert on public.fee_refunds for insert to sai_finance_owner
  with check (private.sai_finance_has_role(array['super_admin']));
create policy finance_owner_audit_read on public.finance_audit_log for select to sai_finance_owner
  using (private.sai_finance_staff(branch_id, array['accountant']));
create policy finance_owner_audit_insert on public.finance_audit_log for insert to sai_finance_owner
  with check (actor_id = (select auth.uid())
    and private.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']));

alter table public.fee_groups add constraint fee_groups_amount_finite check (amount <> 'NaN'::numeric);
alter table public.fee_assignments add constraint fee_assignments_amounts_finite
  check (original_amount <> 'NaN'::numeric and discount_amount <> 'NaN'::numeric);
alter table public.fee_payments add constraint fee_payments_amount_finite check (amount <> 'NaN'::numeric);
alter table public.fee_waivers add constraint fee_waivers_amount_finite check (amount <> 'NaN'::numeric);
alter table public.fee_refunds add constraint fee_refunds_amount_finite check (amount <> 'NaN'::numeric);

-- Minimal finance directory: do not broaden direct student-table privileges.
create function public.sai_finance_students()
returns table (id uuid, full_name text, admission_no text, branch_id uuid,
  class_id uuid, session_id uuid, status text)
language sql stable security definer
set search_path = pg_catalog, public, private, auth
as $$
  select s.id, s.full_name, s.admission_no, s.branch_id, s.class_id, c.session_id, s.status
  from public.students s
  left join public.classes c on c.id = s.class_id and c.branch_id = s.branch_id
  where (select auth.uid()) is not null and (
    private.sai_finance_staff(s.branch_id, array['admin', 'accountant'])
    or (private.sai_finance_has_role(array['student']) and s.user_id = (select auth.uid()))
    or (private.sai_finance_has_role(array['parent']) and exists (
      select 1 from public.parent_student_links l
      where l.student_id = s.id and l.parent_user_id = (select auth.uid())
        and l.verified_at is not null
    ))
  )
  order by s.full_name, s.id;
$$;

create function public.sai_finance_group_labels()
returns table (id uuid, name text)
language sql stable security definer
set search_path = pg_catalog, public, private, auth
as $$
  select g.id, g.name from public.fee_groups g
  where (select auth.uid()) is not null and exists (
    select 1 from public.fee_assignments a
    where a.fee_group_id = g.id
      and private.sai_finance_can_read_student(a.student_id, a.branch_id)
  )
  order by g.name, g.id;
$$;

create function public.sai_finance_sessions()
returns table (id uuid, name text)
language sql stable security definer
set search_path = pg_catalog, public, private, auth
as $$
  select s.id, s.name from public.academic_sessions s
  where s.is_active and (select auth.uid()) is not null and (
    private.sai_finance_has_role(array['super_admin'])
    or (private.sai_finance_has_role(array['admin', 'accountant']) and exists (
      select 1 from public.branch_memberships m
      where m.user_id = (select auth.uid()) and m.is_active
    ))
  )
  order by s.name, s.id;
$$;

revoke all on function public.sai_finance_students(), public.sai_finance_group_labels(),
  public.sai_finance_sessions()
  from public, anon, authenticated;
grant execute on function public.sai_finance_students(), public.sai_finance_group_labels(),
  public.sai_finance_sessions()
  to authenticated;