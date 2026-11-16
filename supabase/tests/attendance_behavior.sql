-- Run only against a disposable database with the full completion migration chain.
-- Set sai.attendance_isolated_test = 'yes' in the same connection before execution.
begin;
do $$
begin
  if current_setting('sai.attendance_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated staging test marker missing';
  end if;
end;
$$;
do $$
declare
  super_id uuid := gen_random_uuid(); admin_id uuid := gen_random_uuid();
  teacher_id uuid := gen_random_uuid(); other_teacher_id uuid := gen_random_uuid(); reception_id uuid := gen_random_uuid();
  student_user uuid := gen_random_uuid(); parent_id uuid := gen_random_uuid(); unverified_parent_id uuid := gen_random_uuid();
  other_user uuid; role_name text;
  branch_a uuid := gen_random_uuid(); branch_b uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid(); class_a uuid := gen_random_uuid(); class_b uuid := gen_random_uuid();
  class_unassigned uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid(); student_b uuid := gen_random_uuid(); other_student uuid := gen_random_uuid();
  attendance_id uuid; cancelled_id uuid; record_a uuid; found_count integer; affected integer; denied boolean; failed_constraint text;
  run_id text := replace(gen_random_uuid()::text, '-', '');
  today date := (now() at time zone 'Asia/Aden')::date;
begin
  insert into auth.users (id) values (super_id), (admin_id), (teacher_id), (other_teacher_id), (reception_id), (student_user), (parent_id), (unverified_parent_id);
  update auth.users set email_confirmed_at = now() where id in (parent_id, student_user);
  insert into public.user_roles (user_id, role) values (super_id, 'super_admin'), (admin_id, 'admin'),
    (teacher_id, 'teacher'), (other_teacher_id, 'teacher'), (reception_id, 'receptionist'),
    (parent_id, 'parent'), (unverified_parent_id, 'parent');
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  insert into public.branches (id, name, code) values
    (branch_a, 'WAVE1_TEST_a', 'WAVE1_TEST_' || run_id || '_a'),
    (branch_b, 'WAVE1_TEST_b', 'WAVE1_TEST_' || run_id || '_b');
  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
    values (session_id, 'WAVE1_TEST_' || run_id, today, today + 10, true);
  insert into public.branch_memberships (user_id, branch_id, is_active)
    values (admin_id, branch_a, true), (teacher_id, branch_a, true), (other_teacher_id, branch_a, true), (reception_id, branch_a, true);
  insert into public.classes (id, branch_id, session_id, name, program, teacher_id)
    values (class_a, branch_a, session_id, 'WAVE1_TEST_a', 'test', teacher_id),
      (class_b, branch_b, session_id, 'WAVE1_TEST_b', 'test', null),
      (class_unassigned, branch_a, session_id, 'WAVE1_TEST_unassigned', 'test', null);
  insert into public.students (id, branch_id, admission_no, full_name, class_id)
    values (student_a, branch_a, 'WAVE1_TEST_' || run_id || '_a', 'WAVE1_TEST_a', class_a),
      (student_b, branch_a, 'WAVE1_TEST_' || run_id || '_b', 'WAVE1_TEST_b', null),
      (other_student, branch_b, 'WAVE1_TEST_' || run_id || '_c', 'WAVE1_TEST_c', class_b);
  denied := false;
  begin
    update public.students set user_id = student_user where id = student_a;
  exception when insufficient_privilege then
    if sqlerrm <> 'Use the authorized student-account linking workflow' then raise; end if;
    denied := true;
  end;
  if not denied then raise exception 'Direct student account link bypassed the guard'; end if;
  execute 'set local role authenticated';
  denied := false;
  begin
    update public.students set user_id = student_user where id = student_a;
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Authenticated direct student account link succeeded'; end if;
  perform public.admissions_link_student_account(student_a, student_user);
  perform public.admissions_verify_parent_student(student_a, parent_id);
  execute 'reset role';
  if not exists (select 1 from public.students where id = student_a and user_id = student_user)
    or not exists (select 1 from public.user_roles where user_id = student_user and role = 'student')
    or not exists (select 1 from public.parent_student_links
      where student_id = student_a and parent_user_id = parent_id
        and verified_at is not null and verified_by = super_id) then
    raise exception 'Authorized student or parent account setup failed';
  end if;
  -- Model a legacy unverified link predating the Admissions verification guard.
  if exists (select 1 from pg_trigger where tgrelid = 'public.parent_student_links'::regclass
      and tgname = 'parent_student_links_guard_verification' and not tgisinternal) then
    execute 'alter table public.parent_student_links disable trigger parent_student_links_guard_verification';
  end if;
  insert into public.parent_student_links (parent_user_id, student_id)
    values (unverified_parent_id, student_a);
  if exists (select 1 from pg_trigger where tgrelid = 'public.parent_student_links'::regclass
      and tgname = 'parent_student_links_guard_verification' and not tgisinternal) then
    execute 'alter table public.parent_student_links enable trigger parent_student_links_guard_verification';
  end if;
  alter table public.audit_logs add constraint wave1_attendance_audit_failure
    check (current_setting('sai.attendance_block_audit', true) is distinct from 'yes');
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  update public.students set class_id = class_a where id = student_b;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin class assignment failed'; end if;
  denied := false;
  begin
    update public.students set class_id = class_b where id = student_b;
  exception when others then
    if sqlerrm <> 'Invalid class or branch' then raise; end if;
    denied := true;
  end;
  if not denied then raise exception 'Cross-branch class assignment accepted'; end if;
  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
      values (branch_a, session_id, class_a, today + 1);
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Future date accepted'; end if;
  denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
      values (branch_b, session_id, class_b, today);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Teacher managed unassigned class'; end if;
  denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
      values (branch_a, session_id, class_unassigned, today);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Teacher managed another class in own branch'; end if;
  insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
    values (branch_a, session_id, class_a, today);
  select id into strict attendance_id from public.attendance_sessions
    where class_id = class_a and attendance_date = today;
  insert into public.attendance_records (attendance_session_id, student_id, status)
    values (attendance_id, student_a, 'present') returning id into record_a;
  update public.attendance_records set status = 'late' where id = record_a;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Assigned teacher could not update attendance'; end if;
  insert into public.attendance_records (attendance_session_id, student_id, status)
    values (attendance_id, student_b, 'absent');
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, other_student, 'present');
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Student/class mismatch accepted'; end if;
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, student_a, 'late');
  exception when unique_violation then denied := true; end;
  if not denied then raise exception 'Duplicate record accepted'; end if;
  denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
      values (branch_a, session_id, class_a, today);
  exception when unique_violation then denied := true; end;
  if not denied then raise exception 'Duplicate session accepted'; end if;

  perform set_config('request.jwt.claim.sub', other_teacher_id::text, true);
  update public.attendance_records set status = 'absent' where id = record_a;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Unassigned teacher updated attendance'; end if;
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, student_a, 'absent');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Unassigned teacher marked attendance'; end if;

  perform set_config('request.jwt.claim.sub', student_user::text, true);
  select count(*) into found_count from public.attendance_records where attendance_session_id = attendance_id;
  if found_count <> 1 then raise exception 'Student visibility not private'; end if;
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, student_a, 'absent');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student marked attendance'; end if;
  perform set_config('request.jwt.claim.sub', parent_id::text, true);
  select count(*) into found_count from public.attendance_records where attendance_session_id = attendance_id;
  if found_count <> 1 then raise exception 'Parent visibility not link-scoped'; end if;
  update public.attendance_records set status = 'late' where id = record_a;
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Parent updated attendance'; end if;
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, student_a, 'absent');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Parent marked attendance'; end if;
  perform set_config('request.jwt.claim.sub', unverified_parent_id::text, true);
  select count(*) into found_count from public.attendance_records where attendance_session_id = attendance_id;
  if found_count <> 0 then raise exception 'Unverified parent read attendance'; end if;

  perform set_config('request.jwt.claim.sub', reception_id::text, true);
  update public.attendance_records set status = 'late' where id = record_a;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Receptionist correction failed'; end if;
  perform set_config('sai.attendance_block_audit', 'yes', true);
  denied := false;
  begin
    update public.attendance_records set status = 'excused' where id = record_a;
  exception when check_violation then
    get stacked diagnostics failed_constraint = constraint_name;
    if failed_constraint <> 'wave1_attendance_audit_failure' then raise; end if;
    denied := true;
  end;
  perform set_config('sai.attendance_block_audit', 'no', true);
  if not denied or not exists (select 1 from public.attendance_records where id = record_a and status = 'late') then
    raise exception 'Audit failure did not roll back attendance correction';
  end if;
  denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (attendance_id, student_a, 'absent');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Receptionist marked a new record'; end if;

  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
      values (branch_b, session_id, class_b, today);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Admin managed another branch'; end if;
  insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date)
    values (branch_a, session_id, class_a, today - 1);
  select id into strict cancelled_id from public.attendance_sessions
    where class_id = class_a and attendance_date = today - 1;
  update public.attendance_sessions set status = 'cancelled' where id = cancelled_id;
  update public.attendance_sessions set status = 'closed' where id = attendance_id;
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'Admin could not close session'; end if;
  denied := false;
  begin
    update public.attendance_records set status = 'absent' where id = record_a;
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Closed session record writable'; end if;
  denied := false;
  begin
    update public.attendance_sessions set status = 'open' where id = attendance_id;
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Closed session reopened'; end if;
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  select count(*) into found_count from public.audit_logs
    where metadata ->> 'source' = 'sai_attendance_trigger'
      and ((entity_id = attendance_id and action in ('create', 'close'))
        or (entity_id = record_a and action in ('mark', 'correct')));
  if found_count <> 5 then raise exception 'Expected atomic attendance audit entries missing'; end if;
  select count(*) into found_count from public.audit_logs
    where entity_id = cancelled_id and action = 'cancel' and metadata ->> 'source' = 'sai_attendance_trigger';
  if found_count <> 1 then raise exception 'Cancellation audit missing'; end if;
  execute 'reset role';

  foreach role_name in array array['accountant','librarian','content_editor']
  loop
    other_user := gen_random_uuid();
    insert into auth.users (id) values (other_user);
    insert into public.user_roles (user_id, role) values (other_user, role_name::public.app_role);
    insert into public.branch_memberships (user_id, branch_id, is_active) values (other_user, branch_a, true);
    perform set_config('request.jwt.claim.sub', other_user::text, true);
    execute 'set local role authenticated';
    select count(*) into found_count from public.attendance_records where attendance_session_id = attendance_id;
    if found_count <> 0 then raise exception '% read attendance', role_name; end if;
    denied := false;
    begin
      insert into public.attendance_records (attendance_session_id, student_id, status)
        values (attendance_id, student_a, 'present');
    exception when insufficient_privilege then denied := true; end;
    if not denied then raise exception '% marked attendance', role_name; end if;
    execute 'reset role';
  end loop;
end;
$$;
rollback;
