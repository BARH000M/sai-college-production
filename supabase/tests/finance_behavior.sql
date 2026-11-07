-- ISOLATED TEST DATABASE ONLY. Apply migrations 001-007 there first.
-- Rollback does not restore receipt, refund, or audit sequences.
-- Run only against a verified disposable database, never shared staging or production.
begin;
do $$
begin
  if current_setting('sai.finance_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated finance test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  super_id uuid := gen_random_uuid(); admin_id uuid := gen_random_uuid();
  accountant_id uuid := gen_random_uuid(); reception_id uuid := gen_random_uuid();
  student_user uuid := gen_random_uuid(); parent_id uuid := gen_random_uuid();
  teacher_id uuid := gen_random_uuid(); outsider_id uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid(); branch_b uuid := gen_random_uuid();
  session_a uuid := gen_random_uuid(); session_b uuid := gen_random_uuid();
  class_a uuid := gen_random_uuid(); class_b uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid(); student_b uuid := gen_random_uuid();
  group_a uuid; assignment_a uuid; payment_a uuid; payment_b uuid; refund_a uuid;
  key_a uuid := gen_random_uuid(); refund_key uuid := gen_random_uuid(); result uuid; balance numeric; status_value text;
  rejected boolean; amount_value numeric; audit_count bigint; role_row record;
  run_id text := replace(gen_random_uuid()::text, '-', '');
begin
  for role_row in select rolname, rolsuper, rolbypassrls, rolcanlogin from pg_roles where rolname = 'sai_finance_owner' loop
    if role_row.rolsuper or role_row.rolbypassrls or role_row.rolcanlogin then
      raise exception 'Finance owner has unsafe attributes';
    end if;
  end loop;
  if not exists (select 1 from pg_roles where rolname = 'sai_finance_owner') then raise exception 'Owner missing'; end if;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'sai_finance' and c.relkind = 'r' and (not c.relrowsecurity or not c.relforcerowsecurity)) then
    raise exception 'Finance table missing forced RLS';
  end if;
  if has_schema_privilege('authenticated', 'sai_finance', 'USAGE')
    or has_table_privilege('authenticated', 'sai_finance.audit_log', 'INSERT,UPDATE,DELETE') then
    raise exception 'Browser role has direct finance access';
  end if;

  insert into auth.users(id) values (super_id), (admin_id), (accountant_id), (reception_id),
    (student_user), (parent_id), (teacher_id), (outsider_id);
  insert into public.user_roles(user_id, role) values
    (super_id,'super_admin'),(admin_id,'admin'),(accountant_id,'accountant'),
    (reception_id,'receptionist'),(student_user,'student'),(parent_id,'parent'),
    (teacher_id,'teacher'),(outsider_id,'accountant');
  insert into public.branches(id,name,code) values
    (branch_a,'WAVE1_FINANCE_TEST_a','WAVE1_FINANCE_TEST_' || run_id || '_a'),
    (branch_b,'WAVE1_FINANCE_TEST_b','WAVE1_FINANCE_TEST_' || run_id || '_b');
  insert into public.academic_sessions(id,name,starts_on,ends_on,is_active) values
    (session_a,'WAVE1_FINANCE_TEST_' || run_id || '_a','2031-01-01','2031-12-31',true),
    (session_b,'WAVE1_FINANCE_TEST_' || run_id || '_b','2032-01-01','2032-12-31',true);
  insert into public.branch_memberships(user_id,branch_id) values
    (admin_id,branch_a),(accountant_id,branch_a),(reception_id,branch_a),(teacher_id,branch_a),(outsider_id,branch_b);
  insert into public.classes(id,branch_id,session_id,name,program) values
    (class_a,branch_a,session_a,'WAVE1_FINANCE_TEST_class_a','test'),
    (class_b,branch_b,session_b,'WAVE1_FINANCE_TEST_class_b','test');
  perform set_config('request.jwt.claim.sub',super_id::text,true);
  insert into public.students(id,user_id,branch_id,admission_no,full_name,class_id) values
    (student_a,student_user,branch_a,'WAVE1_FINANCE_TEST_' || run_id || '_a','WAVE1_FINANCE_TEST_student_a',class_a),
    (student_b,null,branch_b,'WAVE1_FINANCE_TEST_' || run_id || '_b','WAVE1_FINANCE_TEST_student_b',class_b);
  insert into public.parent_student_links(parent_user_id,student_id,verified_at)
    values (parent_id,student_a,now());
  execute 'set local role authenticated';

  group_a := public.sai_finance_save_group(null,branch_a,session_a,'WAVE1_FINANCE_TEST_group',null,100.005,'2031-03-01',true);
  rejected := false;
  begin perform public.sai_finance_save_group(null,branch_a,session_a,'WAVE1_FINANCE_TEST_nan',null,'NaN'::numeric,'2031-03-01',true);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'NaN fee allowed'; end if;
  rejected := false;
  begin perform public.sai_finance_assign(group_a,student_b,0,null);
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'Cross-branch assignment allowed'; end if;
  assignment_a := public.sai_finance_assign(group_a,student_a,10,null);
  select a.balance into balance from public.sai_finance_assignments() a where a.id = assignment_a;
  if balance <> 90.01 then raise exception 'Invalid rounded amount or balance: %', balance; end if;
  rejected := false;
  begin perform public.sai_finance_pay(assignment_a,90.02,'cash',null,gen_random_uuid());
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'Overpayment allowed'; end if;
  rejected := false;
  begin perform public.sai_finance_pay(assignment_a,1,'card',null,gen_random_uuid());
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'Card payment without reference allowed'; end if;
  payment_a := public.sai_finance_pay(assignment_a,30,'cash',null,key_a);
  perform public.sai_finance_save_group(group_a,branch_a,session_a,'WAVE1_FINANCE_TEST_group_updated',null,200,'2031-04-01',true);
  select a.original_amount into amount_value from public.sai_finance_assignments() a where a.id = assignment_a;
  if amount_value <> 100.01 then raise exception 'Group edit changed existing assignment'; end if;
  result := public.sai_finance_pay(assignment_a,30,'cash',null,key_a);
  if result <> payment_a then raise exception 'Idempotent retry created payment'; end if;
  rejected := false;
  begin perform public.sai_finance_pay(assignment_a,31,'cash',null,key_a);
  exception when unique_violation then rejected := true; end;
  if not rejected then raise exception 'Conflicting idempotency key accepted'; end if;
  select a.balance,a.status into balance,status_value from public.sai_finance_assignments() a where a.id = assignment_a;
  if balance <> 60.01 or status_value <> 'partial' then raise exception 'Partial balance incorrect'; end if;

  perform set_config('request.jwt.claim.sub',reception_id::text,true);
  payment_b := public.sai_finance_pay(assignment_a,5,'bank_transfer','WAVE1_FINANCE_TEST_ref',gen_random_uuid());
  if (select count(distinct p.receipt_number) from public.sai_finance_payments(assignment_a) p) <> 2 then
    raise exception 'Receipts not unique';
  end if;
  rejected := false;
  begin perform public.sai_finance_pay(assignment_a,5,'bank_transfer','WAVE1_FINANCE_TEST_ref',gen_random_uuid());
  exception when unique_violation then rejected := true; end;
  if not rejected then raise exception 'Duplicate transaction reference accepted'; end if;
  rejected := false;
  begin perform public.sai_finance_void(payment_b,'WAVE1_FINANCE_TEST_reason');
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Receptionist void allowed'; end if;
  rejected := false;
  begin perform public.sai_finance_waive(assignment_a,'WAVE1_FINANCE_TEST_reason');
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Receptionist waiver allowed'; end if;

  perform set_config('request.jwt.claim.sub',accountant_id::text,true);
  rejected := false;
  begin perform public.sai_finance_void(payment_a,'short');
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'Short void reason accepted'; end if;
  perform public.sai_finance_waive(assignment_a,'WAVE1_FINANCE_TEST_waiver');
  select a.balance,a.status into balance,status_value from public.sai_finance_assignments() a where a.id = assignment_a;
  if balance <> 0 or status_value <> 'waived' then raise exception 'Waiver failed'; end if;
  perform public.sai_finance_void(payment_a,'WAVE1_FINANCE_TEST_void');
  select a.balance into balance from public.sai_finance_assignments() a where a.id = assignment_a;
  if balance <> 30 then raise exception 'Void did not restore balance'; end if;
  rejected := false;
  begin perform public.sai_finance_refund(payment_a,10,'cash',null,'WAVE1_FINANCE_TEST_refund',refund_key);
  exception when insufficient_privilege then rejected := true; end;
  if not rejected then raise exception 'Accountant refund allowed'; end if;

  perform set_config('request.jwt.claim.sub',super_id::text,true);
  refund_a := public.sai_finance_refund(payment_a,10,'cash',null,'WAVE1_FINANCE_TEST_refund',refund_key);
  result := public.sai_finance_refund(payment_a,10,'cash',null,'WAVE1_FINANCE_TEST_refund',refund_key);
  if result <> refund_a then raise exception 'Idempotent refund retry created another refund'; end if;
  rejected := false;
  begin perform public.sai_finance_refund(payment_a,11,'cash',null,'WAVE1_FINANCE_TEST_refund',refund_key);
  exception when unique_violation then rejected := true; end;
  if not rejected then raise exception 'Conflicting refund key accepted'; end if;
  select r.amount into amount_value from public.sai_finance_refunds(payment_a) r where r.id = refund_a;
  if amount_value <> 10 then raise exception 'Refund not found'; end if;
  rejected := false;
  begin perform public.sai_finance_refund(payment_a,21,'cash',null,'WAVE1_FINANCE_TEST_excess',gen_random_uuid());
  exception when check_violation then rejected := true; end;
  if not rejected then raise exception 'Excess refund allowed'; end if;
  select a.balance into balance from public.sai_finance_assignments() a where a.id = assignment_a;
  if balance <> 30 then raise exception 'Refund changed balance'; end if;
  select count(*) into audit_count from public.sai_finance_audit(branch_a);
  if audit_count < 7 then raise exception 'Missing finance audit entries'; end if;

  perform set_config('request.jwt.claim.sub',student_user::text,true);
  if not exists (select 1 from public.sai_finance_assignments() a where a.id = assignment_a) then
    raise exception 'Student cannot read own assignment';
  end if;
  perform set_config('request.jwt.claim.sub',parent_id::text,true);
  if not exists (select 1 from public.sai_finance_assignments() a where a.id = assignment_a) then
    raise exception 'Verified parent cannot read assignment';
  end if;
  perform set_config('request.jwt.claim.sub',outsider_id::text,true);
  if exists (select 1 from public.sai_finance_assignments() a where a.id = assignment_a) then
    raise exception 'Cross-branch disclosure';
  end if;
  perform set_config('request.jwt.claim.sub',teacher_id::text,true);
  if exists (select 1 from public.sai_finance_assignments() a where a.id = assignment_a) then
    raise exception 'Teacher has finance access';
  end if;
end;
$$;
rollback;
