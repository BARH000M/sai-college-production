-- Disposable isolated database only; the payment sequence is not rolled back.
begin;
do $$
begin
  if current_setting('sai.finance_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing';
  end if;
end;
$$;
do $$
declare
  supervisor uuid := gen_random_uuid(); admin_id uuid := gen_random_uuid(); accountant uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid(); teacher uuid := gen_random_uuid(); receptionist uuid := gen_random_uuid();
  learner uuid := gen_random_uuid(); parent uuid := gen_random_uuid();
  unverified uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid(); branch_b uuid := gen_random_uuid();
  academic uuid := gen_random_uuid(); class_a uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid(); student_b uuid := gen_random_uuid();
  fee uuid; assignment uuid; payment uuid; key uuid := gen_random_uuid();
  balance numeric; n integer; denied boolean; prefix text := gen_random_uuid()::text;
  other_role text; other_user uuid;
begin
  insert into auth.users (id, email_confirmed_at) values
    (supervisor, now()), (admin_id, now()), (accountant, now()), (outsider, now()), (teacher, now()), (receptionist, now()),
    (learner, now()), (parent, now()), (unverified, now());
  insert into public.user_roles (user_id, role) values
    (supervisor, 'super_admin'), (admin_id, 'admin'), (accountant, 'accountant'), (outsider, 'accountant'),
    (teacher, 'teacher'), (receptionist, 'receptionist'), (learner, 'student'), (parent, 'parent'), (unverified, 'parent');
  perform set_config('request.jwt.claim.sub', supervisor::text, true);
  insert into public.branches (id, name, code) values
    (branch_a, prefix || 'a', prefix || 'a'), (branch_b, prefix || 'b', prefix || 'b');
  insert into public.branch_memberships (user_id, branch_id) values
    (admin_id, branch_a), (accountant, branch_a), (outsider, branch_b), (teacher, branch_a), (receptionist, branch_a);
  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
    values (academic, prefix, current_date, current_date + 10, true);
  insert into public.classes (id, branch_id, session_id, name, program)
    values (class_a, branch_a, academic, prefix, 'test');
  insert into public.students (id, branch_id, class_id, full_name, admission_no) values
    (student_a, branch_a, class_a, prefix || 'a', prefix || 'a'),
    (student_b, branch_b, null, prefix || 'b', prefix || 'b');
  execute 'set local role authenticated';
  perform public.admissions_link_student_account(student_a, learner);
  perform public.admissions_verify_parent_student(student_a, parent);
  execute 'reset role';
  alter table public.parent_student_links disable trigger parent_student_links_guard_verification;
  insert into public.parent_student_links (parent_user_id, student_id) values (unverified, student_a);
  alter table public.parent_student_links enable trigger parent_student_links_guard_verification;
  perform set_config('request.jwt.claim.sub', accountant::text, true);
  execute 'set local role authenticated';
  select count(*) into n from public.sai_finance_students() where id in (student_a, student_b);
  if n <> 1 or not exists (select 1 from public.sai_finance_students() where id = student_a and session_id = academic)
    then raise exception 'Accountant directory is not branch scoped'; end if;
  if not exists (select 1 from public.sai_finance_sessions() where id = academic)
    then raise exception 'Accountant cannot select academic session'; end if;
  fee := public.sai_finance_save_group(null, branch_a, academic, prefix, null, 100, current_date, true);
  denied := false;
  begin perform public.sai_finance_save_group(null, branch_a, academic, prefix, null, 'NaN'::numeric, current_date, true);
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'NaN fee accepted'; end if;
  denied := false;
  begin perform public.sai_finance_assign(fee, student_b, 0, null);
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Cross-branch fee assignment accepted'; end if;
  assignment := public.sai_finance_assign(fee, student_a, 10, null);
  payment := public.sai_finance_pay(assignment, 30, 'cash', null, key);
  if payment <> public.sai_finance_pay(assignment, 30, 'cash', null, key)
    then raise exception 'Payment retry not idempotent'; end if;
  denied := false;
  begin perform public.sai_finance_pay(assignment, 31, 'cash', null, key);
  exception when unique_violation then denied := true; end;
  if not denied then raise exception 'Conflicting payment retry accepted'; end if;
  denied := false;
  begin perform public.sai_finance_pay(assignment, 61, 'cash', null, gen_random_uuid());
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Overpayment accepted'; end if;
  select a.balance into balance from public.sai_finance_assignments() a where a.id = assignment;
  if balance <> 60 then raise exception 'Incorrect outstanding balance %', balance; end if;
  if not exists (select 1 from public.sai_finance_payments(assignment) p where p.id = payment and p.receipt_number <> '')
    then raise exception 'Receipt missing'; end if;
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  if not exists (select 1 from public.sai_finance_students() where id = student_a)
    or exists (select 1 from public.sai_finance_students() where id = student_b)
    then raise exception 'Admin finance scope incorrect'; end if;
  perform set_config('request.jwt.claim.sub', outsider::text, true);
  if exists (select 1 from public.sai_finance_students() where id = student_a)
    or exists (select 1 from public.sai_finance_assignments() where id = assignment)
    or exists (select 1 from public.sai_finance_group_labels() where id = fee)
    then raise exception 'Cross-branch finance disclosure'; end if;
  denied := false;
  begin perform public.sai_finance_pay(assignment, 1, 'cash', null, gen_random_uuid());
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Cross-branch payment accepted'; end if;
  perform set_config('request.jwt.claim.sub', receptionist::text, true);
  if exists (select 1 from public.sai_finance_assignments() where id = assignment)
    or exists (select 1 from public.fee_groups where id = fee)
    or exists (select 1 from public.sai_finance_group_labels() where id = fee)
    then raise exception 'Receptionist can view finance data'; end if;
  denied := false;
  begin perform public.sai_finance_pay(assignment, 1, 'cash', null, gen_random_uuid());
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Receptionist posted a payment'; end if;
  perform set_config('request.jwt.claim.sub', learner::text, true);
  if not exists (select 1 from public.sai_finance_assignments() where id = assignment)
    or not exists (select 1 from public.sai_finance_students() where id = student_a)
    or not exists (select 1 from public.sai_finance_group_labels() where id = fee)
    or not exists (select 1 from public.sai_finance_payments(assignment) where id = payment)
    or exists (select 1 from public.sai_finance_students() where id = student_b)
    then raise exception 'Student finance visibility incorrect'; end if;
  denied := false;
  begin perform public.sai_finance_pay(assignment, 1, 'cash', null, gen_random_uuid());
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student posted a payment'; end if;
  perform set_config('request.jwt.claim.sub', parent::text, true);
  if not exists (select 1 from public.sai_finance_assignments() where id = assignment)
    or not exists (select 1 from public.sai_finance_group_labels() where id = fee)
    then raise exception 'Verified parent cannot view child fees'; end if;
  perform set_config('request.jwt.claim.sub', unverified::text, true);
  if exists (select 1 from public.sai_finance_assignments() where id = assignment)
    or exists (select 1 from public.sai_finance_students() where id = student_a)
    or exists (select 1 from public.sai_finance_group_labels() where id = fee)
    then raise exception 'Unverified parent can view child fees'; end if;
  perform set_config('request.jwt.claim.sub', teacher::text, true);
  if exists (select 1 from public.sai_finance_students())
    or exists (select 1 from public.sai_finance_sessions())
    or exists (select 1 from public.sai_finance_assignments())
    then raise exception 'Teacher has finance access'; end if;
  execute 'reset role';
  foreach other_role in array array['librarian', 'content_editor'] loop
    other_user := gen_random_uuid();
    insert into auth.users (id) values (other_user);
    insert into public.user_roles (user_id, role) values (other_user, other_role::public.app_role);
    insert into public.branch_memberships (user_id, branch_id) values (other_user, branch_a);
    perform set_config('request.jwt.claim.sub', other_user::text, true);
    execute 'set local role authenticated';
    if exists (select 1 from public.sai_finance_students())
      or exists (select 1 from public.sai_finance_assignments())
      then raise exception '% has finance access', other_role; end if;
    execute 'reset role';
  end loop;
  if has_function_privilege('anon', 'public.sai_finance_students()', 'EXECUTE')
    or has_function_privilege('anon', 'public.sai_finance_group_labels()', 'EXECUTE')
    or has_function_privilege('anon', 'public.sai_finance_sessions()', 'EXECUTE')
    then raise exception 'Anonymous finance directory access'; end if;
  if has_table_privilege('authenticated', 'public.fee_payments', 'INSERT,UPDATE,DELETE')
    or exists (select 1 from pg_roles where rolname='sai_finance_owner'
      and pg_has_role('authenticated', oid, 'MEMBER'))
    then raise exception 'Client can bypass the finance workflow'; end if;
end;
$$;
rollback;
