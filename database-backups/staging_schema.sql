--
-- PostgreSQL database dump
--

\restrict o3byLYEzT84pYdIPyoRTDWZs9jNv4uEWpYltK3FiF2ZkqERb5bbwtgYR4JAqsWo

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: app_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.app_role AS ENUM (
    'super_admin',
    'admin',
    'teacher',
    'accountant',
    'receptionist',
    'librarian',
    'student',
    'parent',
    'content_editor'
);


--
-- Name: sai_admissions_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  changed jsonb := '[]'::jsonb;
  old_status text;
begin
  if tg_op = 'UPDATE' then
    old_status := old.status;
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed from jsonb_each(to_jsonb(new)) k
      where k.value is distinct from to_jsonb(old) -> k.key;
  end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), case when tg_op = 'UPDATE' and old.status is distinct from new.status
      then 'status_change' else lower(tg_op) end,
    'admissions_enquiries', new.id,
    jsonb_build_object('source', 'sai_admissions_trigger', 'branch_id', new.branch_id,
      'changed_columns', changed, 'old_status', old_status, 'new_status', new.status));
  return new;
end;
$$;


--
-- Name: sai_admissions_prepare(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_prepare() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(new.branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' or new.academic_session_id is distinct from old.academic_session_id then
    if not exists (select 1 from public.academic_sessions s
      where s.id = new.academic_session_id and s.is_active) then
      raise exception 'Active session is required' using errcode = '23514';
    end if;
  end if;
  if new.assigned_to is not null and (tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to) then
    if not exists (
      select 1 from public.branch_memberships m
      where m.user_id = new.assigned_to and m.branch_id = new.branch_id and m.is_active
        and exists (select 1 from public.user_roles r where r.user_id = m.user_id
          and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    ) then
      raise exception 'Assignee is not active staff in this branch';
    end if;
  end if;
  new.updated_at := now();
  if new.status in ('enrolled','rejected','withdrawn') then
    if tg_op = 'INSERT' then new.closed_at := now();
    elsif old.status not in ('enrolled','rejected','withdrawn') then new.closed_at := now();
    else new.closed_at := old.closed_at;
    end if;
  else
    new.closed_at := null;
  end if;
  return new;
end;
$$;


--
-- Name: sai_admissions_sessions(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_sessions(wanted_branch uuid) RETURNS TABLE(id uuid, name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if wanted_branch is null or not exists (select 1 from public.branches b where b.id = wanted_branch)
    or not (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(wanted_branch)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query select s.id, s.name from public.academic_sessions s
    where s.is_active order by s.name, s.id;
end;
$$;


--
-- Name: sai_admissions_staff(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_staff(wanted_branch uuid) RETURNS TABLE(user_id uuid, full_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(wanted_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query
    select m.user_id, p.full_name
    from public.branch_memberships m
    join public.profiles p on p.id = m.user_id
    where m.branch_id = wanted_branch and m.is_active
      and exists (select 1 from public.user_roles r where r.user_id = m.user_id
        and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    order by p.full_name, m.user_id;
end;
$$;


--
-- Name: sai_attendance_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare audit_action text;
begin
  if tg_table_name = 'attendance_sessions' then
    if tg_op = 'INSERT' then audit_action := 'create';
    elsif new.status = 'closed' then audit_action := 'close';
    elsif new.status = 'cancelled' then audit_action := 'cancel';
    else audit_action := 'update'; end if;
  elsif tg_op = 'INSERT' then audit_action := 'mark';
  else audit_action := 'correct'; end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
    values (auth.uid(), audit_action, tg_table_name, new.id,
      jsonb_build_object('source', 'sai_attendance_trigger'));
  return new;
end;
$$;


--
-- Name: sai_attendance_classes(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_classes() RETURNS TABLE(id uuid, name text, branch_id uuid, academic_session_id uuid, teacher_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select c.id, c.name, c.branch_id, c.session_id, c.teacher_id
  from public.classes c where public.sai_attendance_manage_class(c.id)
    or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(c.branch_id))
    or public.sai_security_can_read_class(c.id)
  order by c.name, c.id;
$$;


--
-- Name: sai_attendance_manage_class(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_manage_class(wanted_class uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.classes c where c.id = wanted_class and (
      public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(c.branch_id) and (
        public.sai_security_has_role('admin')
        or (public.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid()))
      ))
    )
  );
$$;


--
-- Name: sai_attendance_prepare_record(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_prepare_record() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare session_row public.attendance_sessions%rowtype;
begin
  select * into session_row from public.attendance_sessions a
    where a.id = new.attendance_session_id for update;
  if not found then raise exception 'Attendance session not found' using errcode = '23503'; end if;
  if not (public.sai_attendance_manage_class(session_row.class_id)
    or (tg_op = 'UPDATE' and public.sai_security_has_role('receptionist')
      and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for this attendance' using errcode = '42501';
  end if;
  if session_row.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' then
    perform 1 from public.students s where s.id = new.student_id
      and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id for share;
    if not found then
      raise exception 'Student does not belong to this class' using errcode = '23514';
    end if;
  end if;
  new.marked_by := auth.uid();
  new.marked_at := now();
  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: sai_attendance_prepare_session(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_prepare_session() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.sai_attendance_manage_class(new.class_id) then
    raise exception 'Not authorized for this class' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and old.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if new.attendance_date > (now() at time zone 'Asia/Aden')::date then
    raise exception 'Future attendance date is not permitted' using errcode = '23514';
  end if;
  if not exists (select 1 from public.classes c where c.id = new.class_id
    and c.branch_id = new.branch_id and c.session_id = new.academic_session_id) then
    raise exception 'Class, branch and academic session do not match' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: sai_attendance_roster(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_roster(wanted_session uuid) RETURNS TABLE(student_id uuid, full_name text, record_id uuid, attendance_status text, note text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare session_row public.attendance_sessions%rowtype; manager boolean;
begin
  select * into session_row from public.attendance_sessions where id = wanted_session;
  if not found then raise exception 'Attendance session not found' using errcode = '42501'; end if;
  manager := public.sai_attendance_manage_class(session_row.class_id);
  if not (manager or (public.sai_security_has_role('receptionist')
    and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for roster' using errcode = '42501';
  end if;
  return query select s.id, s.full_name, r.id, r.status, r.note
    from public.students s
    left join public.attendance_records r on r.student_id = s.id and r.attendance_session_id = wanted_session
    where (manager and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id)
      or r.id is not null
    order by s.full_name, s.id;
end;
$$;


--
-- Name: sai_attendance_view_record(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_view_record(wanted_session uuid, wanted_student uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.attendance_sessions a
    join public.students s on s.id = wanted_student
    where a.id = wanted_session and (
      public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id))
      or (public.sai_security_has_role('student') and s.user_id = (select auth.uid()))
      or (public.sai_security_has_role('parent') and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
      ))
    )
  );
$$;


--
-- Name: sai_attendance_view_session(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_attendance_view_session(wanted_session uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.attendance_sessions a where a.id = wanted_session and (
      public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id))
      or exists (select 1 from public.attendance_records r
        where r.attendance_session_id = a.id and public.sai_attendance_view_record(a.id, r.student_id))
    )
  );
$$;


--
-- Name: sai_finance_assign(uuid, uuid, numeric, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_assign(wanted_group uuid, wanted_student uuid, wanted_discount numeric, wanted_due date) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_assignments(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_assignments() RETURNS TABLE(id uuid, fee_group_id uuid, student_id uuid, branch_id uuid, academic_session_id uuid, class_id uuid, original_amount numeric, discount_amount numeric, final_amount numeric, due_date date, status text, balance numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_audit(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_audit(wanted_branch uuid) RETURNS TABLE(id bigint, actor_id uuid, action text, entity_id uuid, details jsonb, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$ select l.id, l.actor_id, l.action, l.entity_id, l.details, l.created_at
  from sai_finance.audit_log l where l.branch_id = wanted_branch order by l.id desc $$;


--
-- Name: sai_finance_cancel(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_cancel(wanted_assignment uuid, wanted_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_groups(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_groups() RETURNS TABLE(id uuid, branch_id uuid, academic_session_id uuid, name text, description text, amount numeric, currency text, due_date date, is_active boolean, created_by uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$ select g.id, g.branch_id, g.academic_session_id, g.name, g.description, g.amount,
  g.currency, g.due_date, g.is_active, g.created_by, g.created_at, g.updated_at
  from sai_finance.fee_groups g order by g.created_at desc, g.id $$;


--
-- Name: sai_finance_pay(uuid, numeric, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_pay(wanted_assignment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_key uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_payments(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_payments(wanted_assignment uuid) RETURNS TABLE(id uuid, assignment_id uuid, amount numeric, currency text, method text, transaction_reference text, receipt_number text, posted_by uuid, posted_at timestamp with time zone, voided_at timestamp with time zone, voided_by uuid, void_reason text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$ select p.id, p.assignment_id, p.amount, p.currency, p.method, p.transaction_reference,
  p.receipt_number, p.posted_by, p.posted_at, p.voided_at, p.voided_by, p.void_reason
  from sai_finance.payments p where p.assignment_id = wanted_assignment order by p.posted_at desc, p.id $$;


--
-- Name: sai_finance_refund(uuid, numeric, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_refund(wanted_payment uuid, wanted_amount numeric, wanted_method text, wanted_reference text, wanted_reason text, wanted_key uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_refunds(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_refunds(wanted_payment uuid) RETURNS TABLE(id uuid, payment_id uuid, amount numeric, method text, reference text, refund_number text, reason text, issued_by uuid, issued_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$ select r.id, r.payment_id, r.amount, r.method, r.reference, r.refund_number, r.reason, r.issued_by, r.issued_at
  from sai_finance.refunds r where r.payment_id = wanted_payment order by r.issued_at desc, r.id $$;


--
-- Name: sai_finance_save_group(uuid, uuid, uuid, text, text, numeric, date, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_save_group(wanted_id uuid, wanted_branch uuid, wanted_session uuid, wanted_name text, wanted_description text, wanted_amount numeric, wanted_due date, wanted_active boolean) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_void(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_void(wanted_payment uuid, wanted_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_finance_waive(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_finance_waive(wanted_assignment uuid, wanted_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public', 'auth'
    AS $$
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


--
-- Name: sai_management_audit_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_management_audit_mutation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  new_row jsonb := to_jsonb(new);
  old_row jsonb;
  changed_columns jsonb;
  target_id uuid;
begin
  if tg_op = 'UPDATE' then
    old_row := to_jsonb(old);
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed_columns
      from jsonb_each(new_row) as k
      where k.value is distinct from old_row -> k.key;
  else
    changed_columns := '[]'::jsonb;
  end if;
  target_id := case when tg_table_name = 'branch_memberships'
    then (new_row ->> 'branch_id')::uuid else (new_row ->> 'id')::uuid end;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(), lower(tg_op), tg_table_name, target_id,
    jsonb_build_object('source', 'sai_management_trigger',
      'changed_columns', changed_columns,
      'branch_id', case when tg_table_name = 'branches' then new_row -> 'id'
        else new_row -> 'branch_id' end,
      'membership_user_id', case when tg_table_name = 'branch_memberships'
        then new_row -> 'user_id' else null end)
  );
  return new;
end;
$$;


--
-- Name: sai_management_validate_student_class(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_management_validate_student_class() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(new.branch_id))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if new.class_id is not null and not exists (
    select 1 from public.classes c
    where c.id = new.class_id and c.branch_id = new.branch_id
  ) then
    raise exception 'Invalid class or branch';
  end if;
  return new;
end;
$$;


--
-- Name: sai_security_branch_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_branch_member(wanted_branch uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$$;


--
-- Name: sai_security_can_read_branch(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_branch(wanted_branch uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.sai_security_has_role('super_admin')
    or (
      public.sai_security_branch_member(wanted_branch)
      and exists (
        select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and r.role in (
            'admin', 'teacher', 'accountant', 'receptionist',
            'librarian', 'content_editor'
          )
      )
    )
    or exists (
      select 1 from public.students s
      where s.branch_id = wanted_branch
        and (
          (public.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            public.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$$;


--
-- Name: sai_security_can_read_class(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_class(wanted_class uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(c.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and public.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (public.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                public.sai_security_has_role('parent')
                and exists (
                  select 1 from public.parent_student_links l
                  where l.student_id = s.id
                    and l.parent_user_id = (select auth.uid())
                    and l.verified_at is not null
                )
              )
            )
        )
      )
  );
$$;


--
-- Name: sai_security_can_read_session(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_session(wanted_session uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and public.sai_security_can_read_class(c.id)
    );
$$;


--
-- Name: sai_security_can_read_student(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_student(wanted_student uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(s.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and public.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          public.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          public.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$$;


--
-- Name: sai_security_has_role(public.app_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_has_role(wanted_role public.app_role) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    CONSTRAINT academic_sessions_check CHECK ((ends_on > starts_on))
);


--
-- Name: admissions_enquiries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admissions_enquiries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id uuid NOT NULL,
    academic_session_id uuid NOT NULL,
    application_no text DEFAULT ('ADM-'::text || (gen_random_uuid())::text) NOT NULL,
    applicant_full_name text NOT NULL,
    guardian_name text,
    phone text,
    email text,
    preferred_program text,
    preferred_level text,
    source text,
    notes text,
    status text DEFAULT 'new'::text NOT NULL,
    assigned_to uuid,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    CONSTRAINT admissions_enquiries_applicant_full_name_check CHECK ((length(btrim(applicant_full_name)) > 0)),
    CONSTRAINT admissions_enquiries_status_check CHECK ((status = ANY (ARRAY['new'::text, 'contacted'::text, 'assessment'::text, 'accepted'::text, 'enrolled'::text, 'rejected'::text, 'withdrawn'::text])))
);


--
-- Name: attendance_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    attendance_session_id uuid NOT NULL,
    student_id uuid NOT NULL,
    status text NOT NULL,
    note text,
    marked_by uuid DEFAULT auth.uid() NOT NULL,
    marked_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attendance_records_status_check CHECK ((status = ANY (ARRAY['present'::text, 'absent'::text, 'late'::text, 'excused'::text])))
);


--
-- Name: attendance_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id uuid NOT NULL,
    academic_session_id uuid NOT NULL,
    class_id uuid NOT NULL,
    attendance_date date NOT NULL,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    status text DEFAULT 'open'::text NOT NULL,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attendance_sessions_check CHECK (((start_time IS NULL) OR (end_time IS NULL) OR (end_time >= start_time))),
    CONSTRAINT attendance_sessions_status_check CHECK ((status = ANY (ARRAY['open'::text, 'closed'::text, 'cancelled'::text])))
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_user_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: branch_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_memberships (
    user_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    address text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id uuid NOT NULL,
    session_id uuid NOT NULL,
    name text NOT NULL,
    program text NOT NULL,
    capacity integer DEFAULT 20 NOT NULL,
    teacher_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT classes_capacity_check CHECK ((capacity > 0))
);


--
-- Name: parent_student_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parent_student_links (
    parent_user_id uuid NOT NULL,
    student_id uuid NOT NULL,
    verified_at timestamp with time zone,
    verified_by uuid
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    preferred_locale text DEFAULT 'ar'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    branch_id uuid NOT NULL,
    admission_no text NOT NULL,
    full_name text NOT NULL,
    date_of_birth date,
    class_id uuid,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT students_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'graduated'::text, 'withdrawn'::text])))
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    role public.app_role NOT NULL,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: academic_sessions academic_sessions_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_sessions
    ADD CONSTRAINT academic_sessions_name_key UNIQUE (name);


--
-- Name: academic_sessions academic_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_sessions
    ADD CONSTRAINT academic_sessions_pkey PRIMARY KEY (id);


--
-- Name: admissions_enquiries admissions_enquiries_application_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_application_no_key UNIQUE (application_no);


--
-- Name: admissions_enquiries admissions_enquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_pkey PRIMARY KEY (id);


--
-- Name: attendance_records attendance_records_attendance_session_id_student_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_attendance_session_id_student_id_key UNIQUE (attendance_session_id, student_id);


--
-- Name: attendance_records attendance_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_pkey PRIMARY KEY (id);


--
-- Name: attendance_sessions attendance_sessions_class_id_attendance_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_class_id_attendance_date_key UNIQUE (class_id, attendance_date);


--
-- Name: attendance_sessions attendance_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: branch_memberships branch_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_pkey PRIMARY KEY (user_id, branch_id);


--
-- Name: branches branches_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_code_key UNIQUE (code);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- Name: parent_student_links parent_student_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_pkey PRIMARY KEY (parent_user_id, student_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: students students_admission_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_admission_no_key UNIQUE (admission_no);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role);


--
-- Name: admissions_assignee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admissions_assignee_idx ON public.admissions_enquiries USING btree (assigned_to, branch_id);


--
-- Name: admissions_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admissions_scope_idx ON public.admissions_enquiries USING btree (branch_id, academic_session_id, status, created_at DESC);


--
-- Name: attendance_records_student_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attendance_records_student_idx ON public.attendance_records USING btree (student_id, attendance_session_id);


--
-- Name: attendance_sessions_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attendance_sessions_scope_idx ON public.attendance_sessions USING btree (branch_id, academic_session_id, attendance_date DESC);


--
-- Name: classes_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classes_scope_idx ON public.classes USING btree (branch_id, session_id);


--
-- Name: parent_links_student_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parent_links_student_idx ON public.parent_student_links USING btree (student_id);


--
-- Name: students_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX students_scope_idx ON public.students USING btree (branch_id, class_id);


--
-- Name: admissions_enquiries admissions_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admissions_audit AFTER INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION public.sai_admissions_audit();


--
-- Name: admissions_enquiries admissions_prepare; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admissions_prepare BEFORE INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION public.sai_admissions_prepare();


--
-- Name: attendance_records attendance_record_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER attendance_record_audit AFTER INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION public.sai_attendance_audit();


--
-- Name: attendance_records attendance_record_prepare; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER attendance_record_prepare BEFORE INSERT OR UPDATE ON public.attendance_records FOR EACH ROW EXECUTE FUNCTION public.sai_attendance_prepare_record();


--
-- Name: attendance_sessions attendance_session_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER attendance_session_audit AFTER INSERT OR UPDATE ON public.attendance_sessions FOR EACH ROW EXECUTE FUNCTION public.sai_attendance_audit();


--
-- Name: attendance_sessions attendance_session_prepare; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER attendance_session_prepare BEFORE INSERT OR UPDATE ON public.attendance_sessions FOR EACH ROW EXECUTE FUNCTION public.sai_attendance_prepare_session();


--
-- Name: branches audit_branches_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_branches_management AFTER INSERT OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: classes audit_classes_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_classes_management AFTER INSERT OR UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: branch_memberships audit_memberships_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_memberships_management AFTER INSERT OR UPDATE ON public.branch_memberships FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: academic_sessions audit_sessions_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_sessions_management AFTER INSERT OR UPDATE ON public.academic_sessions FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: students audit_students_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_students_management AFTER INSERT OR UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: students students_validate_class_branch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER students_validate_class_branch BEFORE INSERT OR UPDATE OF class_id, branch_id ON public.students FOR EACH ROW EXECUTE FUNCTION public.sai_management_validate_student_class();


--
-- Name: admissions_enquiries admissions_enquiries_academic_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_academic_session_id_fkey FOREIGN KEY (academic_session_id) REFERENCES public.academic_sessions(id);


--
-- Name: admissions_enquiries admissions_enquiries_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id);


--
-- Name: admissions_enquiries admissions_enquiries_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: admissions_enquiries admissions_enquiries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: attendance_records attendance_records_attendance_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_attendance_session_id_fkey FOREIGN KEY (attendance_session_id) REFERENCES public.attendance_sessions(id);


--
-- Name: attendance_records attendance_records_marked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_marked_by_fkey FOREIGN KEY (marked_by) REFERENCES auth.users(id);


--
-- Name: attendance_records attendance_records_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_records
    ADD CONSTRAINT attendance_records_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id);


--
-- Name: attendance_sessions attendance_sessions_academic_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_academic_session_id_fkey FOREIGN KEY (academic_session_id) REFERENCES public.academic_sessions(id);


--
-- Name: attendance_sessions attendance_sessions_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: attendance_sessions attendance_sessions_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);


--
-- Name: attendance_sessions attendance_sessions_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance_sessions
    ADD CONSTRAINT attendance_sessions_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id);


--
-- Name: branch_memberships branch_memberships_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_memberships branch_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: classes classes_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: classes classes_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.academic_sessions(id);


--
-- Name: classes classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES auth.users(id);


--
-- Name: parent_student_links parent_student_links_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: parent_student_links parent_student_links_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: parent_student_links parent_student_links_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES auth.users(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: students students_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: students students_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES auth.users(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: academic_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_sessions academic_sessions_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_insert_super_admin ON public.academic_sessions FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: academic_sessions academic_sessions_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_select_authorized ON public.academic_sessions FOR SELECT TO authenticated USING (public.sai_security_can_read_session(id));


--
-- Name: academic_sessions academic_sessions_update_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_update_super_admin ON public.academic_sessions FOR UPDATE TO authenticated USING (public.sai_security_has_role('super_admin'::public.app_role)) WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: admissions_enquiries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admissions_enquiries ENABLE ROW LEVEL SECURITY;

--
-- Name: admissions_enquiries admissions_insert_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_insert_staff ON public.admissions_enquiries FOR INSERT TO authenticated WITH CHECK (((created_by = ( SELECT auth.uid() AS uid)) AND (status = 'new'::text) AND (public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role))))));


--
-- Name: admissions_enquiries admissions_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_select_authorized ON public.admissions_enquiries FOR SELECT TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role) OR (public.sai_security_has_role('teacher'::public.app_role) AND (assigned_to = ( SELECT auth.uid() AS uid)))))));


--
-- Name: admissions_enquiries admissions_update_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_update_staff ON public.admissions_enquiries FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role))))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role)))));


--
-- Name: attendance_records; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance_records attendance_records_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_records_insert ON public.attendance_records FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND public.sai_attendance_manage_class(a.class_id)))));


--
-- Name: attendance_records attendance_records_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_records_read ON public.attendance_records FOR SELECT TO authenticated USING (public.sai_attendance_view_record(attendance_session_id, student_id));


--
-- Name: attendance_records attendance_records_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_records_update ON public.attendance_records FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND (public.sai_attendance_manage_class(a.class_id) OR (public.sai_security_has_role('receptionist'::public.app_role) AND public.sai_security_branch_member(a.branch_id))))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.attendance_sessions a
  WHERE ((a.id = attendance_records.attendance_session_id) AND (public.sai_attendance_manage_class(a.class_id) OR (public.sai_security_has_role('receptionist'::public.app_role) AND public.sai_security_branch_member(a.branch_id)))))));


--
-- Name: attendance_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendance_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance_sessions attendance_sessions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_sessions_insert ON public.attendance_sessions FOR INSERT TO authenticated WITH CHECK ((public.sai_attendance_manage_class(class_id) AND (created_by = ( SELECT auth.uid() AS uid))));


--
-- Name: attendance_sessions attendance_sessions_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_sessions_read ON public.attendance_sessions FOR SELECT TO authenticated USING (public.sai_attendance_view_session(id));


--
-- Name: attendance_sessions attendance_sessions_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_sessions_update ON public.attendance_sessions FOR UPDATE TO authenticated USING (public.sai_attendance_manage_class(class_id)) WITH CHECK (public.sai_attendance_manage_class(class_id));


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_insert_self ON public.audit_logs FOR INSERT TO authenticated WITH CHECK ((actor_user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: audit_logs audit_logs_select_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_select_super_admin ON public.audit_logs FOR SELECT TO authenticated USING (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branch_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branch_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: branch_memberships branch_memberships_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_insert_super_admin ON public.branch_memberships FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branch_memberships branch_memberships_select_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_select_self_or_super_admin ON public.branch_memberships FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR public.sai_security_has_role('super_admin'::public.app_role)));


--
-- Name: branch_memberships branch_memberships_update_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_update_self_or_super_admin ON public.branch_memberships FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND public.sai_security_has_role('admin'::public.app_role))));


--
-- Name: branches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

--
-- Name: branches branches_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_insert_super_admin ON public.branches FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branches branches_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_select_authorized ON public.branches FOR SELECT TO authenticated USING (public.sai_security_can_read_branch(id));


--
-- Name: branches branches_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_update_scoped_admin ON public.branches FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(id))));


--
-- Name: classes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

--
-- Name: classes classes_insert_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_insert_scoped_admin ON public.classes FOR INSERT TO authenticated WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id) AND public.sai_security_can_read_session(session_id))));


--
-- Name: classes classes_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_select_authorized ON public.classes FOR SELECT TO authenticated USING (public.sai_security_can_read_class(id));


--
-- Name: classes classes_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_update_scoped_admin ON public.classes FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: classes finance_classes_lock; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_classes_lock ON public.classes FOR UPDATE TO sai_finance_owner USING ((EXISTS ( SELECT 1
   FROM public.user_roles r
  WHERE ((r.user_id = auth.uid()) AND ((r.role = 'super_admin'::public.app_role) OR ((r.role = ANY (ARRAY['admin'::public.app_role, 'accountant'::public.app_role])) AND (EXISTS ( SELECT 1
           FROM public.branch_memberships m
          WHERE ((m.user_id = auth.uid()) AND (m.branch_id = classes.branch_id) AND m.is_active))))))))) WITH CHECK (false);


--
-- Name: classes finance_classes_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_classes_read ON public.classes FOR SELECT TO sai_finance_owner USING ((EXISTS ( SELECT 1
   FROM public.user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::public.app_role) OR ((r.role = ANY (ARRAY['admin'::public.app_role, 'accountant'::public.app_role])) AND (EXISTS ( SELECT 1
           FROM public.branch_memberships m
          WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.branch_id = classes.branch_id) AND m.is_active)))))))));


--
-- Name: branch_memberships finance_memberships_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_memberships_read ON public.branch_memberships FOR SELECT TO sai_finance_owner USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: parent_student_links finance_parent_links_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_parent_links_read ON public.parent_student_links FOR SELECT TO sai_finance_owner USING (((parent_user_id = ( SELECT auth.uid() AS uid)) AND (verified_at IS NOT NULL)));


--
-- Name: user_roles finance_roles_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_roles_read ON public.user_roles FOR SELECT TO sai_finance_owner USING ((user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: students finance_students_lock; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_students_lock ON public.students FOR UPDATE TO sai_finance_owner USING ((EXISTS ( SELECT 1
   FROM public.user_roles r
  WHERE ((r.user_id = auth.uid()) AND ((r.role = 'super_admin'::public.app_role) OR ((r.role = ANY (ARRAY['admin'::public.app_role, 'accountant'::public.app_role])) AND (EXISTS ( SELECT 1
           FROM public.branch_memberships m
          WHERE ((m.user_id = auth.uid()) AND (m.branch_id = students.branch_id) AND m.is_active))))))))) WITH CHECK (false);


--
-- Name: students finance_students_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY finance_students_read ON public.students FOR SELECT TO sai_finance_owner USING (((user_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM public.parent_student_links l
  WHERE ((l.student_id = students.id) AND (l.parent_user_id = ( SELECT auth.uid() AS uid)) AND (l.verified_at IS NOT NULL)))) OR (EXISTS ( SELECT 1
   FROM public.user_roles r
  WHERE ((r.user_id = ( SELECT auth.uid() AS uid)) AND ((r.role = 'super_admin'::public.app_role) OR ((r.role = ANY (ARRAY['admin'::public.app_role, 'accountant'::public.app_role, 'receptionist'::public.app_role])) AND (EXISTS ( SELECT 1
           FROM public.branch_memberships m
          WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.branch_id = students.branch_id) AND m.is_active))))))))));


--
-- Name: parent_student_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

--
-- Name: parent_student_links parent_student_links_select_parent_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parent_student_links_select_parent_or_super_admin ON public.parent_student_links FOR SELECT TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('parent'::public.app_role) AND (parent_user_id = ( SELECT auth.uid() AS uid)) AND (verified_at IS NOT NULL))));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_insert_self ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles profiles_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_self ON public.profiles FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: students students_insert_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_insert_scoped_admin ON public.students FOR INSERT TO authenticated WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: students students_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_select_authorized ON public.students FOR SELECT TO authenticated USING (public.sai_security_can_read_student(id));


--
-- Name: students students_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_update_scoped_admin ON public.students FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles user_roles_select_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_select_self_or_super_admin ON public.user_roles FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR public.sai_security_has_role('super_admin'::public.app_role)));


--
-- PostgreSQL database dump complete
--

\unrestrict o3byLYEzT84pYdIPyoRTDWZs9jNv4uEWpYltK3FiF2ZkqERb5bbwtgYR4JAqsWo

