-- Prepared for review and isolated testing only. Do not apply automatically.
-- All finance mutations go through authorized functions; the owner is NOLOGIN
-- and is not granted to browser roles.
do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
  if exists (select 1 from pg_roles where rolname = 'sai_finance_owner') then
    raise exception 'Finance owner already exists; review before proceeding';
  end if;
end;
$$;

create role sai_finance_owner nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;
do $$
begin
  execute format('grant sai_finance_owner to %I with set true, inherit true', current_user);
end;
$$;
create schema sai_finance authorization sai_finance_owner;
revoke all on schema sai_finance from public, anon, authenticated;
grant usage on schema public, auth to sai_finance_owner;
grant execute on function auth.uid() to sai_finance_owner;
grant select on public.user_roles, public.branch_memberships, public.students,
  public.classes, public.parent_student_links to sai_finance_owner;
grant update (class_id) on public.students to sai_finance_owner;
grant update (session_id) on public.classes to sai_finance_owner;

-- These narrowly scoped policies allow the non-bypass finance role to check
-- the caller's memberships and enrollment without using bypass-RLS helpers.
create policy finance_roles_read on public.user_roles for select to sai_finance_owner
  using (user_id = (select auth.uid()));
create policy finance_memberships_read on public.branch_memberships for select to sai_finance_owner
  using (user_id = (select auth.uid()));
create policy finance_students_read on public.students for select to sai_finance_owner
  using (
    user_id = (select auth.uid())
    or exists (select 1 from public.parent_student_links l where l.student_id = id
      and l.parent_user_id = (select auth.uid()) and l.verified_at is not null)
    or exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin','accountant','receptionist')
        and exists (select 1 from public.branch_memberships m where m.user_id = (select auth.uid())
          and m.branch_id = students.branch_id and m.is_active))))
  );
create policy finance_parent_links_read on public.parent_student_links for select to sai_finance_owner
  using (parent_user_id = (select auth.uid()) and verified_at is not null);
create policy finance_classes_read on public.classes for select to sai_finance_owner
  using (exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
    and (r.role = 'super_admin' or (r.role in ('admin','accountant')
      and exists (select 1 from public.branch_memberships m where m.user_id = (select auth.uid())
        and m.branch_id = classes.branch_id and m.is_active)))));
create policy finance_students_lock on public.students for update to sai_finance_owner
  using (exists (select 1 from public.user_roles r where r.user_id = auth.uid()
    and (r.role = 'super_admin' or (r.role in ('admin','accountant')
      and exists (select 1 from public.branch_memberships m where m.user_id = auth.uid()
        and m.branch_id = students.branch_id and m.is_active)))))
  with check (false);
create policy finance_classes_lock on public.classes for update to sai_finance_owner
  using (exists (select 1 from public.user_roles r where r.user_id = auth.uid()
    and (r.role = 'super_admin' or (r.role in ('admin','accountant')
      and exists (select 1 from public.branch_memberships m where m.user_id = auth.uid()
        and m.branch_id = classes.branch_id and m.is_active)))))
  with check (false);

create table sai_finance.fee_groups (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  name text not null check (length(btrim(name)) > 0),
  description text,
  amount numeric(12,2) not null check (amount >= 0 and amount <> 'NaN'::numeric),
  currency text not null default 'YER' check (currency = 'YER'),
  due_date date not null,
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table sai_finance.assignments (
  id uuid primary key default gen_random_uuid(),
  fee_group_id uuid not null references sai_finance.fee_groups(id),
  student_id uuid not null references public.students(id),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  class_id uuid not null references public.classes(id),
  original_amount numeric(12,2) not null check (original_amount >= 0 and original_amount <> 'NaN'::numeric),
  discount_amount numeric(12,2) not null check (discount_amount >= 0 and discount_amount <= original_amount and discount_amount <> 'NaN'::numeric),
  final_amount numeric(12,2) generated always as (original_amount - discount_amount) stored,
  due_date date not null,
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id),
  cancellation_reason text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (fee_group_id, student_id),
  check ((cancelled_at is null and cancelled_by is null and cancellation_reason is null)
    or (cancelled_at is not null and cancelled_by is not null and cancellation_reason is not null and length(btrim(cancellation_reason)) > 0))
);

create sequence sai_finance.receipt_sequence;
create sequence sai_finance.refund_sequence;
create table sai_finance.payments (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references sai_finance.assignments(id),
  branch_id uuid not null references public.branches(id),
  amount numeric(12,2) not null check (amount > 0 and amount <> 'NaN'::numeric),
  currency text not null default 'YER' check (currency = 'YER'),
  method text not null check (method in ('cash','bank_transfer','wallet','card')),
  transaction_reference text,
  idempotency_key uuid not null unique,
  receipt_number text not null unique,
  posted_by uuid not null references auth.users(id),
  posted_at timestamptz not null default now(),
  voided_at timestamptz,
  voided_by uuid references auth.users(id),
  void_reason text,
  check (method = 'cash' or (transaction_reference is not null and length(btrim(transaction_reference)) > 0)),
  check (transaction_reference is null or length(btrim(transaction_reference)) > 0),
  check ((voided_at is null and voided_by is null and void_reason is null)
    or (voided_at is not null and voided_by is not null and void_reason is not null and length(btrim(void_reason)) >= 10))
);
create unique index finance_payment_reference_unique
  on sai_finance.payments(branch_id, method, transaction_reference) where transaction_reference is not null;

create table sai_finance.waivers (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references sai_finance.assignments(id),
  amount numeric(12,2) not null check (amount > 0 and amount <> 'NaN'::numeric),
  reason text not null check (length(btrim(reason)) > 0),
  waived_by uuid not null references auth.users(id),
  waived_at timestamptz not null default now()
);
create table sai_finance.refunds (
  id uuid primary key default gen_random_uuid(),
  idempotency_key uuid not null unique,
  payment_id uuid not null references sai_finance.payments(id),
  branch_id uuid not null references public.branches(id),
  amount numeric(12,2) not null check (amount > 0 and amount <> 'NaN'::numeric),
  method text not null check (method in ('cash','bank_transfer','wallet','card')),
  reference text,
  refund_number text not null unique,
  reason text not null check (length(btrim(reason)) > 0),
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now(),
  check (method = 'cash' or (reference is not null and length(btrim(reference)) > 0)),
  check (reference is null or length(btrim(reference)) > 0)
);
create unique index finance_refund_reference_unique
  on sai_finance.refunds(branch_id, method, reference) where reference is not null;

create table sai_finance.audit_log (
  id bigint generated always as identity primary key,
  branch_id uuid not null references public.branches(id),
  actor_id uuid not null references auth.users(id),
  action text not null,
  entity_id uuid not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table sai_finance.fee_groups owner to sai_finance_owner;
alter table sai_finance.assignments owner to sai_finance_owner;
alter table sai_finance.payments owner to sai_finance_owner;
alter table sai_finance.waivers owner to sai_finance_owner;
alter table sai_finance.refunds owner to sai_finance_owner;
alter table sai_finance.audit_log owner to sai_finance_owner;
alter sequence sai_finance.receipt_sequence owner to sai_finance_owner;
alter sequence sai_finance.refund_sequence owner to sai_finance_owner;

create function sai_finance.has_role(wanted text[]) returns boolean
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select exists (select 1 from public.user_roles r
  where r.user_id = auth.uid() and r.role::text = any(wanted)); $$;
create function sai_finance.can_staff(wanted_branch uuid, wanted text[]) returns boolean
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select sai_finance.has_role(array['super_admin']) or
  (sai_finance.has_role(wanted) and exists (select 1 from public.branch_memberships m
    where m.user_id = auth.uid() and m.branch_id = wanted_branch and m.is_active)); $$;
create function sai_finance.can_read_student(wanted_student uuid, wanted_branch uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select sai_finance.can_staff(wanted_branch, array['admin','accountant','receptionist'])
  or exists (select 1 from public.students s where s.id = wanted_student
    and ((s.user_id = auth.uid() and sai_finance.has_role(array['student']))
      or (sai_finance.has_role(array['parent']) and exists
        (select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = auth.uid() and l.verified_at is not null)))); $$;
alter function sai_finance.has_role(text[]) owner to sai_finance_owner;
alter function sai_finance.can_staff(uuid,text[]) owner to sai_finance_owner;
alter function sai_finance.can_read_student(uuid,uuid) owner to sai_finance_owner;
revoke all on all functions in schema sai_finance from public, anon, authenticated;

alter table sai_finance.fee_groups enable row level security;
alter table sai_finance.fee_groups force row level security;
alter table sai_finance.assignments enable row level security;
alter table sai_finance.assignments force row level security;
alter table sai_finance.payments enable row level security;
alter table sai_finance.payments force row level security;
alter table sai_finance.waivers enable row level security;
alter table sai_finance.waivers force row level security;
alter table sai_finance.refunds enable row level security;
alter table sai_finance.refunds force row level security;
alter table sai_finance.audit_log enable row level security;
alter table sai_finance.audit_log force row level security;

create policy finance_groups_read on sai_finance.fee_groups for select to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['admin','accountant','receptionist']));
create policy finance_groups_insert on sai_finance.fee_groups for insert to sai_finance_owner
  with check (sai_finance.can_staff(branch_id, array['admin','accountant']));
create policy finance_groups_update on sai_finance.fee_groups for update to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['admin','accountant']))
  with check (sai_finance.can_staff(branch_id, array['admin','accountant']));
create policy finance_assignments_read on sai_finance.assignments for select to sai_finance_owner
  using (sai_finance.can_read_student(student_id, branch_id));
create policy finance_assignments_insert on sai_finance.assignments for insert to sai_finance_owner
  with check (sai_finance.can_staff(branch_id, array['admin','accountant']));
create policy finance_assignments_update on sai_finance.assignments for update to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['admin','accountant','receptionist']))
  with check (sai_finance.can_staff(branch_id, array['admin','accountant']));
create policy finance_payments_read on sai_finance.payments for select to sai_finance_owner
  using (exists (select 1 from sai_finance.assignments a where a.id = assignment_id
    and sai_finance.can_read_student(a.student_id, a.branch_id)));
create policy finance_payments_insert on sai_finance.payments for insert to sai_finance_owner
  with check (sai_finance.can_staff(branch_id, array['admin','accountant','receptionist']));
create policy finance_payments_update on sai_finance.payments for update to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['accountant']))
  with check (sai_finance.can_staff(branch_id, array['accountant']));
create policy finance_waivers_read on sai_finance.waivers for select to sai_finance_owner
  using (exists (select 1 from sai_finance.assignments a where a.id = assignment_id
    and sai_finance.can_read_student(a.student_id, a.branch_id)));
create policy finance_waivers_insert on sai_finance.waivers for insert to sai_finance_owner
  with check (exists (select 1 from sai_finance.assignments a where a.id = assignment_id
    and sai_finance.can_staff(a.branch_id, array['accountant'])));
create policy finance_refunds_read on sai_finance.refunds for select to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['accountant']));
create policy finance_refunds_insert on sai_finance.refunds for insert to sai_finance_owner
  with check (sai_finance.has_role(array['super_admin']));
create policy finance_audit_read on sai_finance.audit_log for select to sai_finance_owner
  using (sai_finance.can_staff(branch_id, array['accountant']));
create policy finance_audit_insert on sai_finance.audit_log for insert to sai_finance_owner
  with check (actor_id = auth.uid() and sai_finance.can_staff(branch_id, array['admin','accountant','receptionist']));

-- Browser roles have no direct finance schema, table, or sequence privileges.
revoke all on all tables in schema sai_finance from public, anon, authenticated;
revoke all on all sequences in schema sai_finance from public, anon, authenticated;

-- A common lock on the assignment serializes payments, waivers, and voids.
create function sai_finance.balance(wanted uuid) returns numeric
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select a.final_amount
    - coalesce((select sum(p.amount) from sai_finance.payments p where p.assignment_id = a.id and p.voided_at is null), 0)
    - coalesce((select sum(w.amount) from sai_finance.waivers w where w.assignment_id = a.id), 0)
  from sai_finance.assignments a where a.id = wanted
$$;
alter function sai_finance.balance(uuid) owner to sai_finance_owner;
revoke all on function sai_finance.balance(uuid) from public, anon, authenticated;

create function public.sai_finance_groups() returns table (
  id uuid, branch_id uuid, academic_session_id uuid, name text, description text,
  amount numeric, currency text, due_date date, is_active boolean, created_by uuid,
  created_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select g.id, g.branch_id, g.academic_session_id, g.name, g.description, g.amount,
  g.currency, g.due_date, g.is_active, g.created_by, g.created_at, g.updated_at
  from sai_finance.fee_groups g order by g.created_at desc, g.id $$;

create function public.sai_finance_save_group(
  wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text,
  wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean
) returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare group_row sai_finance.fee_groups%rowtype;
begin
  if auth.uid() is null or not sai_finance.can_staff(wanted_branch, array['admin','accountant']) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if wanted_name is null or btrim(wanted_name) = '' or wanted_amount is null
    or wanted_amount < 0 or wanted_amount = 'NaN'::numeric or wanted_due is null or wanted_active is null then
    raise exception 'Invalid fee group' using errcode = '23514';
  end if;
  if wanted_id is null then
    insert into sai_finance.fee_groups(branch_id, academic_session_id, name, description, amount, due_date, is_active, created_by)
      values (wanted_branch, wanted_session, btrim(wanted_name), nullif(btrim(wanted_description), ''),
        round(wanted_amount, 2), wanted_due, wanted_active, auth.uid()) returning * into group_row;
  else
    update sai_finance.fee_groups set name = btrim(wanted_name), description = nullif(btrim(wanted_description), ''),
      amount = round(wanted_amount, 2), due_date = wanted_due, is_active = wanted_active, updated_at = now()
      where id = wanted_id and branch_id = wanted_branch and academic_session_id = wanted_session
      returning * into group_row;
    if not found then raise exception 'Fee group not found or scope changed' using errcode = '42501'; end if;
  end if;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (group_row.branch_id, auth.uid(), case when wanted_id is null then 'group_create' else 'group_update' end,
      group_row.id, jsonb_build_object('amount', group_row.amount, 'due_date', group_row.due_date, 'is_active', group_row.is_active));
  return group_row.id;
end;
$$;

create function public.sai_finance_assign(wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date)
returns uuid language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare g sai_finance.fee_groups%rowtype; student_class uuid; result uuid; discount numeric;
begin
  select * into g from sai_finance.fee_groups where id = wanted_group and is_active for share;
  if not found or not sai_finance.can_staff(g.branch_id, array['admin','accountant']) then
    raise exception 'Fee group unavailable or unauthorized' using errcode = '42501';
  end if;
  discount := round(wanted_discount, 2);
  if wanted_discount is null or wanted_discount < 0 or wanted_discount = 'NaN'::numeric or discount > g.amount then
    raise exception 'Invalid discount' using errcode = '23514';
  end if;
  select c.id into student_class from public.students s join public.classes c on c.id = s.class_id
    where s.id = wanted_student and s.branch_id = g.branch_id and c.branch_id = g.branch_id
      and c.session_id = g.academic_session_id for share of s, c;
  if not found then raise exception 'Student class, branch and session do not match' using errcode = '23514'; end if;
  insert into sai_finance.assignments(fee_group_id, student_id, branch_id, academic_session_id, class_id,
    original_amount, discount_amount, due_date, created_by)
    values (g.id, wanted_student, g.branch_id, g.academic_session_id, student_class, g.amount,
      discount, coalesce(wanted_due, g.due_date), auth.uid()) returning id into result;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (g.branch_id, auth.uid(), 'assign', result,
      jsonb_build_object('group_id', g.id, 'original_amount', g.amount, 'discount', discount));
  return result;
end;
$$;

create function public.sai_finance_assignments()
returns table (id uuid, fee_group_id uuid, student_id uuid, branch_id uuid, academic_session_id uuid,
  class_id uuid, original_amount numeric, discount_amount numeric, final_amount numeric,
  due_date date, status text, balance numeric)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$
  select a.id, a.fee_group_id, a.student_id, a.branch_id, a.academic_session_id,
    a.class_id, a.original_amount, a.discount_amount, a.final_amount, a.due_date,
    case when a.cancelled_at is not null then 'cancelled'
      when sai_finance.balance(a.id) = 0 and exists (select 1 from sai_finance.waivers w where w.assignment_id = a.id) then 'waived'
      when sai_finance.balance(a.id) = 0 then 'paid'
      when exists (select 1 from sai_finance.payments p where p.assignment_id = a.id and p.voided_at is null) then 'partial'
      else 'unpaid' end,
    case when a.cancelled_at is not null then 0 else sai_finance.balance(a.id) end
  from sai_finance.assignments a order by a.created_at desc, a.id
$$;

create function public.sai_finance_pay(wanted_assignment uuid, wanted_amount numeric, wanted_method text,
  wanted_reference text, wanted_key uuid) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a sai_finance.assignments%rowtype; p sai_finance.payments%rowtype; result uuid;
  amount numeric; ref text := nullif(btrim(wanted_reference), '');
begin
  select * into a from sai_finance.assignments where id = wanted_assignment for update;
  if not found or not sai_finance.can_staff(a.branch_id, array['admin','accountant','receptionist']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_amount is null or wanted_amount <= 0 or wanted_amount = 'NaN'::numeric or wanted_method is null
    or wanted_method not in ('cash','bank_transfer','wallet','card') or wanted_key is null
    or (wanted_method <> 'cash' and ref is null) then
    raise exception 'Invalid payment' using errcode = '23514';
  end if;
  amount := round(wanted_amount, 2);
  if amount <= 0 then raise exception 'Invalid payment amount' using errcode = '23514'; end if;
  select * into p from sai_finance.payments where idempotency_key = wanted_key;
  if found then
    if p.assignment_id <> wanted_assignment or p.amount <> amount or p.method <> wanted_method
      or p.transaction_reference is distinct from ref then
      raise exception 'Idempotency key conflict' using errcode = '23505';
    end if;
    return p.id;
  end if;
  if a.cancelled_at is not null or amount > sai_finance.balance(a.id) then
    raise exception 'Payment exceeds outstanding balance or assignment is cancelled' using errcode = '23514';
  end if;
  insert into sai_finance.payments(assignment_id, branch_id, amount, method, transaction_reference,
    idempotency_key, receipt_number, posted_by)
    values (a.id, a.branch_id, amount, wanted_method, ref, wanted_key,
      'SAI-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
        to_char(nextval('sai_finance.receipt_sequence'), 'FM00000000000000000000'), auth.uid()) returning id into result;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (a.branch_id, auth.uid(), 'payment_post', result, jsonb_build_object('amount', amount, 'assignment_id', a.id));
  return result;
end;
$$;

create function public.sai_finance_void(wanted_payment uuid, wanted_reason text) returns void
language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare p sai_finance.payments%rowtype; a sai_finance.assignments%rowtype;
begin
  select * into p from sai_finance.payments where id = wanted_payment;
  if not found or not sai_finance.can_staff(p.branch_id, array['accountant']) then
    raise exception 'Payment unavailable or unauthorized' using errcode = '42501';
  end if;
  if wanted_reason is null or length(btrim(wanted_reason)) < 10 then
    raise exception 'Void reason must have at least 10 characters' using errcode = '23514';
  end if;
  select * into a from sai_finance.assignments where id = p.assignment_id for update;
  update sai_finance.payments set voided_at = now(), voided_by = auth.uid(), void_reason = btrim(wanted_reason)
    where id = p.id and voided_at is null;
  if not found then raise exception 'Payment already voided' using errcode = '23514'; end if;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (p.branch_id, auth.uid(), 'payment_void', p.id, jsonb_build_object('reason', btrim(wanted_reason)));
end;
$$;

create function public.sai_finance_waive(wanted_assignment uuid, wanted_reason text) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a sai_finance.assignments%rowtype; amount numeric; result uuid;
begin
  select * into a from sai_finance.assignments where id = wanted_assignment for update;
  if not found or not sai_finance.can_staff(a.branch_id, array['accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  amount := sai_finance.balance(a.id);
  if a.cancelled_at is not null or amount <= 0 or wanted_reason is null or btrim(wanted_reason) = '' then
    raise exception 'Waiver requires an outstanding balance and reason' using errcode = '23514';
  end if;
  insert into sai_finance.waivers(assignment_id, amount, reason, waived_by)
    values (a.id, amount, btrim(wanted_reason), auth.uid()) returning id into result;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (a.branch_id, auth.uid(), 'waive', result,
      jsonb_build_object('assignment_id', a.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$$;

create function public.sai_finance_cancel(wanted_assignment uuid, wanted_reason text) returns void
language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare a sai_finance.assignments%rowtype;
begin
  select * into a from sai_finance.assignments where id = wanted_assignment for update;
  if not found or not sai_finance.can_staff(a.branch_id, array['admin','accountant']) then
    raise exception 'Assignment unavailable or unauthorized' using errcode = '42501';
  end if;
  if a.cancelled_at is not null or wanted_reason is null or btrim(wanted_reason) = ''
    or exists (select 1 from sai_finance.payments p where p.assignment_id = a.id and p.voided_at is null) then
    raise exception 'Cancellation requires a reason and no posted payment' using errcode = '23514';
  end if;
  update sai_finance.assignments set cancelled_at = now(), cancelled_by = auth.uid(), cancellation_reason = btrim(wanted_reason)
    where id = a.id;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (a.branch_id, auth.uid(), 'cancel', a.id, jsonb_build_object('reason', btrim(wanted_reason)));
end;
$$;

create function public.sai_finance_refund(wanted_payment uuid, wanted_amount numeric, wanted_method text,
  wanted_reference text, wanted_reason text, wanted_key uuid) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, auth
as $$
declare p sai_finance.payments%rowtype; a sai_finance.assignments%rowtype; r sai_finance.refunds%rowtype; amount numeric;
  ref text := nullif(btrim(wanted_reference), ''); result uuid;
begin
  if not sai_finance.has_role(array['super_admin']) then
    raise exception 'Only a super admin may issue refunds' using errcode = '42501';
  end if;
  select * into p from sai_finance.payments where id = wanted_payment;
  if not found then raise exception 'Payment not found' using errcode = '23503'; end if;
  select * into a from sai_finance.assignments where id = p.assignment_id for update;
  select * into p from sai_finance.payments where id = wanted_payment;
  amount := round(wanted_amount, 2);
  if wanted_key is null then raise exception 'Refund key required' using errcode = '23514'; end if;
  select * into r from sai_finance.refunds where idempotency_key = wanted_key;
  if found then
    if r.payment_id is distinct from wanted_payment or r.amount is distinct from amount
      or r.method is distinct from wanted_method or r.reference is distinct from ref
      or r.reason is distinct from btrim(wanted_reason) then
      raise exception 'Refund idempotency key conflict' using errcode = '23505';
    end if;
    return r.id;
  end if;
  if p.voided_at is null or wanted_amount is null or wanted_amount <= 0 or wanted_amount = 'NaN'::numeric or amount <= 0
    or wanted_method is null or wanted_method not in ('cash','bank_transfer','wallet','card')
    or (wanted_method <> 'cash' and ref is null) or wanted_reason is null or btrim(wanted_reason) = ''
    or amount > p.amount - coalesce((select sum(r.amount) from sai_finance.refunds r where r.payment_id = p.id), 0) then
    raise exception 'Invalid refund or refund exceeds remaining amount' using errcode = '23514';
  end if;
  insert into sai_finance.refunds(payment_id, branch_id, amount, method, reference, refund_number, reason, issued_by, idempotency_key)
    values (p.id, p.branch_id, amount, wanted_method, ref,
      'SAI-R-' || to_char(now() at time zone 'Asia/Aden', 'YYYY') || '-' ||
        to_char(nextval('sai_finance.refund_sequence'), 'FM00000000000000000000'), btrim(wanted_reason), auth.uid(), wanted_key)
    returning id into result;
  insert into sai_finance.audit_log(branch_id, actor_id, action, entity_id, details)
    values (p.branch_id, auth.uid(), 'refund', result,
      jsonb_build_object('payment_id', p.id, 'amount', amount, 'reason', btrim(wanted_reason)));
  return result;
end;
$$;

create function public.sai_finance_payments(wanted_assignment uuid)
returns table (id uuid, assignment_id uuid, amount numeric, currency text, method text,
  transaction_reference text, receipt_number text, posted_by uuid, posted_at timestamptz,
  voided_at timestamptz, voided_by uuid, void_reason text)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select p.id, p.assignment_id, p.amount, p.currency, p.method, p.transaction_reference,
  p.receipt_number, p.posted_by, p.posted_at, p.voided_at, p.voided_by, p.void_reason
  from sai_finance.payments p where p.assignment_id = wanted_assignment order by p.posted_at desc, p.id $$;

create function public.sai_finance_refunds(wanted_payment uuid)
returns table (id uuid, payment_id uuid, amount numeric, method text, reference text,
  refund_number text, reason text, issued_by uuid, issued_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select r.id, r.payment_id, r.amount, r.method, r.reference, r.refund_number, r.reason, r.issued_by, r.issued_at
  from sai_finance.refunds r where r.payment_id = wanted_payment order by r.issued_at desc, r.id $$;

create function public.sai_finance_audit(wanted_branch uuid)
returns table (id bigint, actor_id uuid, action text, entity_id uuid, details jsonb, created_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, auth
as $$ select l.id, l.actor_id, l.action, l.entity_id, l.details, l.created_at
  from sai_finance.audit_log l where l.branch_id = wanted_branch order by l.id desc $$;

-- PostgreSQL requires the new owner to have CREATE on the containing schema.
grant create on schema public to sai_finance_owner;
alter function public.sai_finance_groups() owner to sai_finance_owner;
alter function public.sai_finance_save_group(uuid,uuid,uuid,text,text,numeric,date,boolean) owner to sai_finance_owner;
alter function public.sai_finance_assign(uuid,uuid,numeric,date) owner to sai_finance_owner;
alter function public.sai_finance_assignments() owner to sai_finance_owner;
alter function public.sai_finance_pay(uuid,numeric,text,text,uuid) owner to sai_finance_owner;
alter function public.sai_finance_void(uuid,text) owner to sai_finance_owner;
alter function public.sai_finance_waive(uuid,text) owner to sai_finance_owner;
alter function public.sai_finance_cancel(uuid,text) owner to sai_finance_owner;
alter function public.sai_finance_refund(uuid,numeric,text,text,text,uuid) owner to sai_finance_owner;
alter function public.sai_finance_payments(uuid) owner to sai_finance_owner;
alter function public.sai_finance_refunds(uuid) owner to sai_finance_owner;
alter function public.sai_finance_audit(uuid) owner to sai_finance_owner;
revoke create on schema public from sai_finance_owner;

revoke all on function public.sai_finance_groups(),
  public.sai_finance_save_group(uuid,uuid,uuid,text,text,numeric,date,boolean),
  public.sai_finance_assign(uuid,uuid,numeric,date), public.sai_finance_assignments(),
  public.sai_finance_pay(uuid,numeric,text,text,uuid), public.sai_finance_void(uuid,text),
  public.sai_finance_waive(uuid,text), public.sai_finance_cancel(uuid,text),
  public.sai_finance_refund(uuid,numeric,text,text,text,uuid), public.sai_finance_payments(uuid),
  public.sai_finance_refunds(uuid), public.sai_finance_audit(uuid)
  from public, anon, authenticated;
grant execute on function public.sai_finance_groups(),
  public.sai_finance_save_group(uuid,uuid,uuid,text,text,numeric,date,boolean),
  public.sai_finance_assign(uuid,uuid,numeric,date), public.sai_finance_assignments(),
  public.sai_finance_pay(uuid,numeric,text,text,uuid), public.sai_finance_void(uuid,text),
  public.sai_finance_waive(uuid,text), public.sai_finance_cancel(uuid,text),
  public.sai_finance_refund(uuid,numeric,text,text,text,uuid), public.sai_finance_payments(uuid),
  public.sai_finance_refunds(uuid), public.sai_finance_audit(uuid) to authenticated;

do $$
begin
  execute format('revoke sai_finance_owner from %I', current_user);
end;
$$;
