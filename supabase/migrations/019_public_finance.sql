-- Fees and receipts, deployable in the public schema on managed Supabase.
-- Design: the ledger is append-only. Browser roles can only SELECT what their
-- role and branch allow; every mutation goes through a SECURITY DEFINER
-- function that re-checks the caller, locks the assignment row, and writes an
-- audit entry in the same transaction. Amounts are numeric(12,2) in YER.

create sequence if not exists public.finance_receipt_seq;
create sequence if not exists public.finance_refund_seq;

create table if not exists public.fee_groups (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  name text not null check (length(btrim(name)) > 0),
  description text,
  amount numeric(12,2) not null check (amount >= 0),
  currency text not null default 'YER' check (currency = 'YER'),
  due_date date not null,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fee_assignments (
  id uuid primary key default gen_random_uuid(),
  fee_group_id uuid not null references public.fee_groups(id),
  student_id uuid not null references public.students(id),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  class_id uuid references public.classes(id),
  original_amount numeric(12,2) not null check (original_amount >= 0),
  discount_amount numeric(12,2) not null check (discount_amount >= 0 and discount_amount <= original_amount),
  final_amount numeric(12,2) generated always as (original_amount - discount_amount) stored,
  due_date date not null,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id),
  cancellation_reason text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (fee_group_id, student_id),
  check ((cancelled_at is null and cancelled_by is null and cancellation_reason is null)
    or (cancelled_at is not null and cancelled_by is not null and length(btrim(cancellation_reason)) > 0))
);

create table if not exists public.fee_payments (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.fee_assignments(id),
  branch_id uuid not null references public.branches(id),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'YER' check (currency = 'YER'),
  method text not null check (method in ('cash', 'bank_transfer', 'wallet', 'card')),
  transaction_reference text,
  idempotency_key uuid not null unique,
  receipt_number text not null unique,
  posted_by uuid not null references auth.users(id),
  posted_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid references auth.users(id),
  void_reason text,
  check (method = 'cash' or (transaction_reference is not null and length(btrim(transaction_reference)) > 0)),
  check ((voided_at is null and voided_by is null and void_reason is null)
    or (voided_at is not null and voided_by is not null and length(btrim(void_reason)) >= 10))
);

create unique index if not exists fee_payment_reference_unique
  on public.fee_payments(branch_id, method, transaction_reference)
  where transaction_reference is not null;

create table if not exists public.fee_waivers (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.fee_assignments(id),
  amount numeric(12,2) not null check (amount > 0),
  reason text not null check (length(btrim(reason)) > 0),
  waived_by uuid not null references auth.users(id),
  waived_at timestamptz not null default now()
);

create table if not exists public.fee_refunds (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null unique,
  payment_id uuid not null references public.fee_payments(id),
  branch_id uuid not null references public.branches(id),
  amount numeric(12,2) not null check (amount > 0),
  method text not null check (method in ('cash', 'bank_transfer', 'wallet', 'card')),
  reference text,
  refund_number text not null unique,
  reason text not null check (length(btrim(reason)) > 0),
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now()
);

create unique index if not exists fee_refund_reference_unique
  on public.fee_refunds(branch_id, method, reference)
  where reference is not null;

create table if not exists public.finance_audit_log (
  id bigint generated always as identity primary key,
  branch_id uuid not null references public.branches(id),
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_id uuid not null,
  details jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists fee_assignments_student_idx on public.fee_assignments(student_id);
create index if not exists fee_assignments_branch_idx on public.fee_assignments(branch_id);
create index if not exists fee_payments_assignment_idx on public.fee_payments(assignment_id);
create index if not exists fee_waivers_assignment_idx on public.fee_waivers(assignment_id);
create index if not exists finance_audit_branch_idx on public.finance_audit_log(branch_id, created_at desc);

alter table public.fee_groups enable row level security;
alter table public.fee_assignments enable row level security;
alter table public.fee_payments enable row level security;
alter table public.fee_waivers enable row level security;
alter table public.fee_refunds enable row level security;
alter table public.finance_audit_log enable row level security;

-- Read-only grants: every write happens inside a checked function.
revoke all on public.fee_groups, public.fee_assignments, public.fee_payments,
  public.fee_waivers, public.fee_refunds, public.finance_audit_log from anon, authenticated;
grant select on public.fee_groups, public.fee_assignments, public.fee_payments,
  public.fee_waivers, public.fee_refunds, public.finance_audit_log to authenticated;

-- ---------------------------------------------------------------- helpers

create or replace function public.sai_finance_has_role(wanted text[])
returns boolean language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select exists (select 1 from public.user_roles r
    where r.user_id = auth.uid() and r.role::text = any(wanted));
$$;

create or replace function public.sai_finance_staff(wanted_branch uuid, wanted text[])
returns boolean language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select public.sai_finance_has_role(array['super_admin'])
    or (public.sai_finance_has_role(wanted) and public.sai_security_branch_member(wanted_branch));
$$;

create or replace function public.sai_finance_can_read_student(wanted_student uuid, wanted_branch uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select public.sai_finance_staff(wanted_branch, array['admin', 'accountant', 'receptionist'])
    or exists (
      select 1 from public.students s
      where s.id = wanted_student
        and (
          (s.user_id = auth.uid() and public.sai_finance_has_role(array['student']))
          or (public.sai_finance_has_role(array['parent'])
            and exists (select 1 from public.parent_student_links l
              where l.student_id = s.id and l.parent_user_id = auth.uid() and l.verified_at is not null))
        )
    );
$$;

create or replace function public.sai_finance_balance(wanted uuid)
returns numeric language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select a.final_amount
    - coalesce((select sum(p.amount) from public.fee_payments p
        where p.assignment_id = a.id and p.voided_at is null), 0)
    - coalesce((select sum(w.amount) from public.fee_waivers w
        where w.assignment_id = a.id), 0)
  from public.fee_assignments a where a.id = wanted;
$$;

revoke all on function public.sai_finance_has_role(text[]) from public, anon, authenticated;
revoke all on function public.sai_finance_staff(uuid, text[]) from public, anon, authenticated;
revoke all on function public.sai_finance_can_read_student(uuid, uuid) from public, anon, authenticated;
revoke all on function public.sai_finance_balance(uuid) from public, anon, authenticated;
-- RLS policy expressions run with the caller's privileges, so the three
-- read-scope helpers must be executable by signed-in users. They only answer
-- questions about the caller's own identity and branch membership.
grant execute on function public.sai_finance_has_role(text[]) to authenticated;
grant execute on function public.sai_finance_staff(uuid, text[]) to authenticated;
grant execute on function public.sai_finance_can_read_student(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------- read policies

drop policy if exists fee_groups_read on public.fee_groups;
create policy fee_groups_read on public.fee_groups for select to authenticated
  using (public.sai_finance_staff(branch_id, array['admin', 'accountant', 'receptionist']));

drop policy if exists fee_assignments_read on public.fee_assignments;
create policy fee_assignments_read on public.fee_assignments for select to authenticated
  using (public.sai_finance_can_read_student(student_id, branch_id));

drop policy if exists fee_payments_read on public.fee_payments;
create policy fee_payments_read on public.fee_payments for select to authenticated
  using (exists (select 1 from public.fee_assignments a
    where a.id = fee_payments.assignment_id
      and public.sai_finance_can_read_student(a.student_id, a.branch_id)));

drop policy if exists fee_waivers_read on public.fee_waivers;
create policy fee_waivers_read on public.fee_waivers for select to authenticated
  using (exists (select 1 from public.fee_assignments a
    where a.id = fee_waivers.assignment_id
      and public.sai_finance_can_read_student(a.student_id, a.branch_id)));

drop policy if exists fee_refunds_read on public.fee_refunds;
create policy fee_refunds_read on public.fee_refunds for select to authenticated
  using (public.sai_finance_staff(branch_id, array['accountant']));

drop policy if exists finance_audit_read on public.finance_audit_log;
create policy finance_audit_read on public.finance_audit_log for select to authenticated
  using (public.sai_finance_staff(branch_id, array['accountant']));

-- ---------------------------------------------------------------- read functions

create or replace function public.sai_finance_groups()
returns table (id uuid, branch_id uuid, academic_session_id uuid, name text, description text,
  amount numeric, currency text, due_date date, is_active boolean, created_by uuid,
  created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select g.id, g.branch_id, g.academic_session_id, g.name, g.description, g.amount, g.currency,
    g.due_date, g.is_active, g.created_by, g.created_at, g.updated_at
  from public.fee_groups g
  where public.sai_finance_staff(g.branch_id, array['admin', 'accountant', 'receptionist'])
  order by g.created_at desc, g.id;
$$;

create or replace function public.sai_finance_assignments()
returns table (id uuid, fee_group_id uuid, student_id uuid, branch_id uuid, academic_session_id uuid,
  class_id uuid, original_amount numeric, discount_amount numeric, final_amount numeric,
  due_date date, status text, balance numeric)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select a.id, a.fee_group_id, a.student_id, a.branch_id, a.academic_session_id, a.class_id,
    a.original_amount, a.discount_amount, a.final_amount, a.due_date,
    case
      when a.cancelled_at is not null then 'cancelled'
      when public.sai_finance_balance(a.id) <= 0
        and exists (select 1 from public.fee_waivers w where w.assignment_id = a.id) then 'waived'
      when public.sai_finance_balance(a.id) <= 0 then 'paid'
      when exists (select 1 from public.fee_payments p
        where p.assignment_id = a.id and p.voided_at is null) then 'partial'
      else 'unpaid'
    end,
    case when a.cancelled_at is not null then 0 else greatest(public.sai_finance_balance(a.id), 0) end
  from public.fee_assignments a
  where public.sai_finance_can_read_student(a.student_id, a.branch_id)
  order by a.created_at desc, a.id;
$$;

create or replace function public.sai_finance_payments(wanted_assignment uuid)
returns table (id uuid, assignment_id uuid, amount numeric, currency text, method text,
  transaction_reference text, receipt_number text, posted_by uuid, posted_at timestamptz,
  voided_at timestamptz, voided_by uuid, void_reason text)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select p.id, p.assignment_id, p.amount, p.currency, p.method, p.transaction_reference,
    p.receipt_number, p.posted_by, p.posted_at, p.voided_at, p.voided_by, p.void_reason
  from public.fee_payments p
  join public.fee_assignments a on a.id = p.assignment_id
  where p.assignment_id = wanted_assignment
    and public.sai_finance_can_read_student(a.student_id, a.branch_id)
  order by p.posted_at desc, p.id;
$$;

create or replace function public.sai_finance_refunds(wanted_payment uuid)
returns table (id uuid, payment_id uuid, amount numeric, method text, reference text,
  refund_number text, reason text, issued_by uuid, issued_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select r.id, r.payment_id, r.amount, r.method, r.reference, r.refund_number, r.reason,
    r.issued_by, r.issued_at
  from public.fee_refunds r
  join public.fee_payments p on p.id = r.payment_id
  where r.payment_id = wanted_payment
    and public.sai_finance_staff(r.branch_id, array['accountant'])
  order by r.issued_at desc, r.id;
$$;

create or replace function public.sai_finance_audit(wanted_branch uuid)
returns table (id bigint, actor_id uuid, action text, entity_id uuid, details jsonb, created_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select l.id, l.actor_id, l.action, l.entity_id, l.details, l.created_at
  from public.finance_audit_log l
  where l.branch_id = wanted_branch
    and public.sai_finance_staff(wanted_branch, array['accountant'])
  order by l.id desc;
$$;

-- ---------------------------------------------------------------- mutations

create or replace function public.sai_finance_save_group(
  wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text,
  wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean
) returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare group_row public.fee_groups%rowtype; group_amount numeric;
begin
  if auth.uid() is null
    or not public.sai_finance_staff(wanted_branch, array['admin', 'accountant']) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if wanted_name is null or btrim(wanted_name) = '' or wanted_amount is null
    or wanted_amount < 0 or wanted_due is null or wanted_active is null or wanted_session is null then
    raise exception 'Invalid fee group' using errcode = '23514';
  end if;
  group_amount := round(wanted_amount, 2);
  if wanted_id is null then
    insert into public.fee_groups(branch_id, academic_session_id, name, description, amount,
      due_date, is_active, created_by)
    values (wanted_branch, wanted_session, btrim(wanted_name), nullif(btrim(wanted_description), ''),
      group_amount, wanted_due, wanted_active, auth.uid())
    returning * into group_row;
  else
    update public.fee_groups
      set name = btrim(wanted_name), description = nullif(btrim(wanted_description), ''),
        amount = group_amount, due_date = wanted_due, is_active = wanted_active, updated_at = now()
      where id = wanted_id and branch_id = wanted_branch and academic_session_id = wanted_session
      returning * into group_row;
    if not found then
      raise exception 'Fee group not found or scope changed' using errcode = '42501';
    end if;
  end if;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (group_row.branch_id, auth.uid(),
    case when wanted_id is null then 'group_create' else 'group_update' end,
    group_row.id,
    jsonb_build_object('amount', group_row.amount, 'due_date', group_row.due_date,
      'is_active', group_row.is_active));
  return group_row.id;
end;
$$;

create or replace function public.sai_finance_assign(
  wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date
) returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare g public.fee_groups%rowtype; student_class uuid; student_branch uuid;
  result uuid; discount numeric;
begin
  select * into g from public.fee_groups where id = wanted_group and is_active for share;
  if not found or not public.sai_finance_staff(g.branch_id, array['admin', 'accountant']) then
    raise exception 'Fee group unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_discount is null or wanted_discount < 0 then
    raise exception 'Invalid discount' using errcode = '23514';
  end if;
  discount := round(wanted_discount, 2);
  if discount > g.amount then
    raise exception 'Invalid discount' using errcode = '23514';
  end if;
  select s.class_id, s.branch_id into student_class, student_branch
  from public.students s where s.id = wanted_student;
  if not found or student_branch <> g.branch_id then
    raise exception 'Student is not enrolled in this branch' using errcode = '23514';
  end if;
  if student_class is not null then
    perform 1 from public.classes c
    where c.id = student_class and c.branch_id = g.branch_id
      and c.session_id = g.academic_session_id;
    if not found then
      raise exception 'Student class session does not match the fee group' using errcode = '23514';
    end if;
  end if;
  insert into public.fee_assignments(fee_group_id, student_id, branch_id, academic_session_id,
    class_id, original_amount, discount_amount, due_date, created_by)
  values (g.id, wanted_student, g.branch_id, g.academic_session_id, student_class, g.amount,
    discount, coalesce(wanted_due, g.due_date), auth.uid())
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (g.branch_id, auth.uid(), 'assign', result,
    jsonb_build_object('group_id', g.id, 'original_amount', g.amount, 'discount', discount));
  return result;
end;
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
  if not public.sai_finance_staff(a.branch_id, array['admin', 'accountant', 'receptionist']) then
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

create or replace function public.sai_finance_void(wanted_payment uuid, wanted_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare p public.fee_payments%rowtype; a public.fee_assignments%rowtype;
begin
  select * into p from public.fee_payments where id = wanted_payment;
  if not found or not public.sai_finance_staff(p.branch_id, array['accountant']) then
    raise exception 'Payment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_reason is null or length(btrim(wanted_reason)) < 10 then
    raise exception 'Void reason must have at least 10 characters' using errcode = '23514';
  end if;
  select * into a from public.fee_assignments where id = p.assignment_id for update;
  update public.fee_payments
    set voided_at = now(), voided_by = auth.uid(), void_reason = btrim(wanted_reason)
    where id = p.id and voided_at is null;
  if not found then
    raise exception 'Payment already voided' using errcode = '23514';
  end if;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (p.branch_id, auth.uid(), 'payment_void', p.id,
    jsonb_build_object('reason', btrim(wanted_reason)));
end;
$$;

create or replace function public.sai_finance_waive(wanted_assignment uuid, wanted_reason text)
returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a public.fee_assignments%rowtype; amount numeric; result uuid;
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or not public.sai_finance_staff(a.branch_id, array['accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  amount := public.sai_finance_balance(a.id);
  if a.cancelled_at is not null or amount <= 0 or wanted_reason is null or btrim(wanted_reason) = '' then
    raise exception 'Waiver requires an outstanding balance and reason' using errcode = '23514';
  end if;
  insert into public.fee_waivers(assignment_id, amount, reason, waived_by)
  values (a.id, amount, btrim(wanted_reason), auth.uid()) returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'waive', result,
    jsonb_build_object('assignment_id', a.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$$;

create or replace function public.sai_finance_cancel(wanted_assignment uuid, wanted_reason text)
returns void language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a public.fee_assignments%rowtype;
begin
  select * into a from public.fee_assignments where id = wanted_assignment for update;
  if not found or not public.sai_finance_staff(a.branch_id, array['admin', 'accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if a.cancelled_at is not null or wanted_reason is null or btrim(wanted_reason) = ''
    or exists (select 1 from public.fee_payments p
      where p.assignment_id = a.id and p.voided_at is null) then
    raise exception 'Cancellation requires a reason and no posted payment' using errcode = '23514';
  end if;
  update public.fee_assignments
    set cancelled_at = now(), cancelled_by = auth.uid(), cancellation_reason = btrim(wanted_reason)
    where id = a.id;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (a.branch_id, auth.uid(), 'cancel', a.id, jsonb_build_object('reason', btrim(wanted_reason)));
end;
$$;

create or replace function public.sai_finance_refund(
  wanted_payment uuid, wanted_amount numeric, wanted_method text,
  wanted_reference text, wanted_reason text, wanted_key uuid
) returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare p public.fee_payments%rowtype; r public.fee_refunds%rowtype; amount numeric;
  ref text := nullif(btrim(wanted_reference), ''); result uuid; already numeric;
begin
  if not public.sai_finance_has_role(array['super_admin']) then
    raise exception 'Only a super admin may issue refunds' using errcode = '42501';
  end if;
  select * into p from public.fee_payments where id = wanted_payment;
  if not found then
    raise exception 'Payment not found' using errcode = '23503';
  end if;
  if wanted_key is null then
    raise exception 'Refund key required' using errcode = '23514';
  end if;
  amount := round(wanted_amount, 2);
  select * into r from public.fee_refunds where idempotency_key = wanted_key;
  if found then
    if r.payment_id is distinct from wanted_payment or r.amount is distinct from amount
      or r.method is distinct from wanted_method or r.reference is distinct from ref
      or r.reason is distinct from btrim(wanted_reason) then
      raise exception 'Refund idempotency key conflict' using errcode = '23505';
    end if;
    return r.id;
  end if;
  select coalesce(sum(x.amount), 0) into already
  from public.fee_refunds x where x.payment_id = p.id;
  if p.voided_at is null or amount is null or amount <= 0
    or wanted_method is null or wanted_method not in ('cash', 'bank_transfer', 'wallet', 'card')
    or (wanted_method <> 'cash' and ref is null)
    or wanted_reason is null or btrim(wanted_reason) = ''
    or amount > p.amount - already then
    raise exception 'Invalid refund or refund exceeds remaining amount' using errcode = '23514';
  end if;
  insert into public.fee_refunds(payment_id, branch_id, amount, method, reference, refund_number,
    reason, issued_by, idempotency_key)
  values (p.id, p.branch_id, amount, wanted_method, ref,
    'SAI-R-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
      lpad(nextval('public.finance_refund_seq')::text, 6, '0'),
    btrim(wanted_reason), auth.uid(), wanted_key)
  returning id into result;
  insert into public.finance_audit_log(branch_id, actor_id, action, entity_id, details)
  values (p.branch_id, auth.uid(), 'refund', result,
    jsonb_build_object('payment_id', p.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$$;

-- ---------------------------------------------------------------- execute grants

revoke all on function public.sai_finance_groups(),
  public.sai_finance_assignments(),
  public.sai_finance_payments(uuid),
  public.sai_finance_refunds(uuid),
  public.sai_finance_audit(uuid),
  public.sai_finance_save_group(uuid, uuid, uuid, text, text, numeric, date, boolean),
  public.sai_finance_assign(uuid, uuid, numeric, date),
  public.sai_finance_pay(uuid, numeric, text, text, uuid),
  public.sai_finance_void(uuid, text),
  public.sai_finance_waive(uuid, text),
  public.sai_finance_cancel(uuid, text),
  public.sai_finance_refund(uuid, numeric, text, text, text, uuid)
  from public, anon, authenticated;

grant execute on function public.sai_finance_groups(),
  public.sai_finance_assignments(),
  public.sai_finance_payments(uuid),
  public.sai_finance_refunds(uuid),
  public.sai_finance_audit(uuid),
  public.sai_finance_save_group(uuid, uuid, uuid, text, text, numeric, date, boolean),
  public.sai_finance_assign(uuid, uuid, numeric, date),
  public.sai_finance_pay(uuid, numeric, text, text, uuid),
  public.sai_finance_void(uuid, text),
  public.sai_finance_waive(uuid, text),
  public.sai_finance_cancel(uuid, text),
  public.sai_finance_refund(uuid, numeric, text, text, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------- announcement delivery log

create table if not exists public.announcement_deliveries (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  recipient_email text not null,
  status text not null check (status in ('sent', 'failed', 'skipped')),
  provider_message_id text,
  error text,
  attempted_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (announcement_id, recipient_user_id)
);

create index if not exists announcement_deliveries_announcement_idx
  on public.announcement_deliveries(announcement_id, status);

alter table public.announcement_deliveries enable row level security;

revoke all on public.announcement_deliveries from anon, authenticated;
grant select on public.announcement_deliveries to authenticated;
grant select, insert, update, delete on public.announcement_deliveries to service_role;

drop policy if exists announcement_deliveries_read on public.announcement_deliveries;
create policy announcement_deliveries_read on public.announcement_deliveries for select to authenticated
  using (exists (
    select 1 from public.announcements a
    where a.id = announcement_deliveries.announcement_id
      and exists (select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and (r.role = 'super_admin'
            or (r.role in ('admin', 'content_editor')
              and (a.branch_id is null or public.sai_security_branch_member(a.branch_id)))))
  ));