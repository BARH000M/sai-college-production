-- Phase 7-M Main-only forward proposal. No historical private ledger replay.
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
create or replace function private.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and (
      r.role = 'super_admin'
      or (r.role in ('admin', 'accountant') and exists (
        select 1 from public.branch_memberships m
        where m.user_id = (select auth.uid()) and m.branch_id = wanted_branch and m.is_active
      ))
    )
  ) or exists (
    select 1 from public.students s where s.id = wanted_student and (
      (s.user_id = (select auth.uid()) and private.sai_finance_has_role(array['student']))
      or (private.sai_finance_has_role(array['parent']) and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
      ))
    )
  );
$$;
alter policy fee_groups_read on public.fee_groups
  using (private.sai_finance_staff(branch_id, array['admin', 'accountant']));
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
create or replace function public.sai_finance_groups()
returns table (id uuid, branch_id uuid, academic_session_id uuid, name text, description text,
  amount numeric, currency text, due_date date, is_active boolean, created_by uuid,
  created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select g.id, g.branch_id, g.academic_session_id, g.name, g.description, g.amount, g.currency,
    g.due_date, g.is_active, g.created_by, g.created_at, g.updated_at
  from public.fee_groups g
  where public.sai_finance_staff(g.branch_id, array['admin', 'accountant'])
  order by g.created_at desc, g.id;
$$;

create or replace function public.sai_finance_pay(
  wanted_assignment uuid, wanted_amount numeric, wanted_method text,
  wanted_reference text, wanted_key uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a public.fee_assignments%rowtype; p public.fee_payments%rowtype; result uuid;
  amount numeric; ref text := nullif(btrim(wanted_reference), '');
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or a.cancelled_at is not null then
    raise exception 'Assignment unavailable' using errcode = '42501';
  end if;
  if not public.sai_finance_staff(a.branch_id, array['admin', 'accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_amount is null or wanted_amount <= 0 or wanted_method is null
    or wanted_method not in ('cash', 'bank_transfer', 'wallet', 'card') or wanted_key is null
    or (wanted_method <> 'cash' and ref is null) then
    raise exception 'Invalid payment' using errcode = '23514';
  end if;
  amount := round(wanted_amount, 2);
  if amount <= 0 then
    raise exception 'Invalid payment amount' using errcode = '23514';
  end if;
  select * into p from public.fee_payments where idempotency_key = wanted_key;
  if found then
    if p.assignment_id <> wanted_assignment or p.amount <> amount or p.method <> wanted_method
      or p.transaction_reference is distinct from ref then
      raise exception 'Idempotency key conflict' using errcode = '23505';
    end if;
    return p.id;
  end if;
  if amount > public.sai_finance_balance(a.id) then
    raise exception 'Payment exceeds outstanding balance' using errcode = '23514';
  end if;
  insert into public.fee_payments(assignment_id, branch_id, amount, method, transaction_reference,
    idempotency_key, receipt_number, posted_by)
  values (a.id, a.branch_id, amount, wanted_method, ref, wanted_key,
    'SAI-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
      lpad(nextval('public.finance_receipt_seq')::text, 6, '0'), auth.uid())
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'payment_post', result,
    jsonb_build_object('amount', amount, 'assignment_id', a.id));
  return result;
end;
$$;

commit;
