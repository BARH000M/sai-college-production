-- Role-scoped verification for the eight write paths.
--
-- Purpose: as soon as the write grants from 021 land, this script proves that
-- each of the eight modules can write the rows it is supposed to write — and,
-- just as important, that every other role still cannot. It is scoped by role
-- and by branch, not just "does the insert work".
--
-- Run only against a database you are allowed to write to in a rolled-back
-- transaction. It creates fixtures and rolls everything back:
--
--     supabase db query --local --file supabase/tests/write_path_verification.sql
--
-- If the grants have not been applied yet, it stops immediately with a BLOCKED
-- message naming the tables, instead of a cascade of permission errors.
--
-- Covered paths (nine tables, eight modules):
--   1. profiles             self-service insert/update, no cross-user write
--   2. branches             super_admin insert, branch-scoped admin update
--   3. academic_sessions    super_admin only
--   4. classes              branch-scoped admin insert
--   5. students             branch-scoped admin insert, no teacher insert
--   6. branch_memberships   super_admin insert, admin self-update only
--   7. admissions_enquiries staff insert with created_by = self
--   8. attendance           teacher session + record for own class only

begin;

create temp table sai_wp (
  k text primary key,
  id uuid not null
) on commit drop;

-- Precondition: the 021 grants must be in place.
do $$
declare
  v_missing text;
begin
  select string_agg(t || ' (' || missing || ')', ', ' order by t)
    into v_missing
  from (
    select t,
           concat_ws(', ',
             case when not has_table_privilege('authenticated', 'public.' || t, 'INSERT') then 'INSERT' end,
             case when not has_table_privilege('authenticated', 'public.' || t, 'UPDATE') then 'UPDATE' end
           ) as missing
    from unnest(array[
      'academic_sessions','admissions_enquiries','attendance_records','attendance_sessions',
      'branch_memberships','branches','classes','profiles','students'
    ]) as t
  ) s
  where s.missing <> '';

  if v_missing is not null then
    raise exception
      'BLOCKED: write grants are missing for %. Run supabase/migrations/021_restore_write_grants.sql in the Dashboard SQL Editor, re-run its verification query until it shows INSERT, SELECT, UPDATE for all nine tables, then re-run this script.',
      v_missing;
  end if;
  raise notice 'PRECHECK OK: authenticated holds INSERT and UPDATE on all nine write-path tables';
end;
$$;

-- Fixtures (as the session owner, before any role switch).
do $$
declare
  v_super uuid := gen_random_uuid();
  v_admin_a uuid := gen_random_uuid();
  v_admin_b uuid := gen_random_uuid();
  v_teacher_a uuid := gen_random_uuid();
  v_reception_a uuid := gen_random_uuid();
  v_student_user uuid := gen_random_uuid();
  v_parent uuid := gen_random_uuid();
  v_branch_a uuid := gen_random_uuid();
  v_branch_b uuid := gen_random_uuid();
  v_session uuid := gen_random_uuid();
  v_class_a uuid := gen_random_uuid();
  v_class_b uuid := gen_random_uuid();
  v_student_a uuid := gen_random_uuid();
  v_student_b uuid := gen_random_uuid();
  v_run text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 10);
begin
  insert into sai_wp (k, id) values
    ('super', v_super), ('admin_a', v_admin_a), ('admin_b', v_admin_b),
    ('teacher_a', v_teacher_a), ('reception_a', v_reception_a),
    ('student_user', v_student_user), ('parent', v_parent),
    ('branch_a', v_branch_a), ('branch_b', v_branch_b),
    ('session', v_session), ('class_a', v_class_a), ('class_b', v_class_b),
    ('student_a', v_student_a), ('student_b', v_student_b);

  insert into auth.users (id) values
    (v_super), (v_admin_a), (v_admin_b), (v_teacher_a), (v_reception_a), (v_student_user), (v_parent);

  insert into public.profiles (id, full_name)
  select u, 'WP TEST ' || u::text from unnest(array[
    v_super, v_admin_a, v_admin_b, v_teacher_a, v_reception_a, v_student_user, v_parent
  ]) as u
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role) values
    (v_super, 'super_admin'), (v_admin_a, 'admin'), (v_admin_b, 'admin'),
    (v_teacher_a, 'teacher'), (v_reception_a, 'receptionist'),
    (v_student_user, 'student'), (v_parent, 'parent');

  insert into public.branches (id, name, code) values
    (v_branch_a, 'WP TEST A ' || v_run, 'WP-A-' || v_run),
    (v_branch_b, 'WP TEST B ' || v_run, 'WP-B-' || v_run);

  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
    values (v_session, 'WP TEST ' || v_run, current_date - 30, current_date + 120, true);

  insert into public.branch_memberships (user_id, branch_id, is_active) values
    (v_admin_a, v_branch_a, true),
    (v_admin_b, v_branch_b, true),
    (v_teacher_a, v_branch_a, true),
    (v_reception_a, v_branch_a, true);

  insert into public.classes (id, branch_id, session_id, name, program, teacher_id) values
    (v_class_a, v_branch_a, v_session, 'WP TEST A ' || v_run, 'test', v_teacher_a),
    (v_class_b, v_branch_b, v_session, 'WP TEST B ' || v_run, 'test', null);

  insert into public.students (id, user_id, branch_id, admission_no, full_name, class_id) values
    (v_student_a, v_student_user, v_branch_a, 'WP-' || v_run || '-A', 'WP TEST Student A', v_class_a),
    (v_student_b, null, v_branch_b, 'WP-' || v_run || '-B', 'WP TEST Student B', v_class_b);

  insert into public.parent_student_links (parent_user_id, student_id, verified_at)
    values (v_parent, v_student_a, now());
end;
$$;

-- 1. profiles — self-service only.
do $$
declare
  v_me uuid := (select id from sai_wp where k = 'admin_a');
  v_other uuid := (select id from sai_wp where k = 'admin_b');
  v_affected integer;
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', v_me::text, true);
  execute 'set local role authenticated';

  update public.profiles set full_name = 'WP TEST self edit' where id = v_me;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 1 FAIL: own profile update affected % rows', v_affected; end if;

  update public.profiles set full_name = 'WP TEST hijack' where id = v_other;
  get diagnostics v_affected = row_count;
  if v_affected <> 0 then raise exception 'PATH 1 FAIL: updated another user profile'; end if;

  begin
    insert into public.profiles (id, full_name) values (v_other, 'WP TEST injected');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 1 FAIL: inserted a profile for another user'; end if;

  execute 'reset role';
  raise notice 'PASS path 1: profiles self-service writes, no cross-user write';
end;
$$;

-- 2. branches — super_admin inserts, branch-scoped admin updates.
do $$
declare
  v_super uuid := (select id from sai_wp where k = 'super');
  v_admin uuid := (select id from sai_wp where k = 'admin_a');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_b uuid := (select id from sai_wp where k = 'branch_b');
  v_affected integer;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';

  update public.branches set name = 'WP TEST A renamed' where id = v_a;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 2 FAIL: scoped admin could not update own branch'; end if;

  update public.branches set name = 'WP TEST B renamed' where id = v_b;
  get diagnostics v_affected = row_count;
  if v_affected <> 0 then raise exception 'PATH 2 FAIL: admin updated a foreign branch'; end if;

  v_denied := false;
  begin
    insert into public.branches (name, code) values ('WP TEST X', 'WP-X-' || substr(v_super::text, 1, 8));
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 2 FAIL: non-super_admin inserted a branch'; end if;

  execute 'reset role';
  perform set_config('request.jwt.claim.sub', v_super::text, true);
  execute 'set local role authenticated';
  insert into public.branches (name, code) values ('WP TEST SUPER', 'WP-S-' || substr(v_super::text, 1, 8));
  execute 'reset role';
  raise notice 'PASS path 2: branches insert super_admin-only, update branch-scoped';
end;
$$;

-- 3. academic_sessions — super_admin only.
do $$
declare
  v_super uuid := (select id from sai_wp where k = 'super');
  v_admin uuid := (select id from sai_wp where k = 'admin_a');
  v_denied boolean := false;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';
  begin
    insert into public.academic_sessions (name, starts_on, ends_on, is_active)
      values ('WP TEST ADMIN SESSION', current_date, current_date + 30, false);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 3 FAIL: admin inserted an academic session'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  execute 'set local role authenticated';
  insert into public.academic_sessions (name, starts_on, ends_on, is_active)
    values ('WP TEST SUPER SESSION', current_date, current_date + 30, false);
  execute 'reset role';
  raise notice 'PASS path 3: academic_sessions super_admin-only';
end;
$$;

-- 4. classes — branch-scoped admin insert.
do $$
declare
  v_admin uuid := (select id from sai_wp where k = 'admin_a');
  v_teacher uuid := (select id from sai_wp where k = 'teacher_a');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_b uuid := (select id from sai_wp where k = 'branch_b');
  v_session uuid := (select id from sai_wp where k = 'session');
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';

  insert into public.classes (branch_id, session_id, name, program)
    values (v_a, v_session, 'WP TEST CLASS OK', 'test');

  v_denied := false;
  begin
    insert into public.classes (branch_id, session_id, name, program)
      values (v_b, v_session, 'WP TEST CLASS FOREIGN', 'test');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 4 FAIL: admin inserted a class in another branch'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_teacher::text, true);
  execute 'set local role authenticated';
  v_denied := false;
  begin
    insert into public.classes (branch_id, session_id, name, program)
      values (v_a, v_session, 'WP TEST CLASS TEACHER', 'test');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 4 FAIL: teacher inserted a class'; end if;
  execute 'reset role';
  raise notice 'PASS path 4: classes branch-scoped admin insert';
end;
$$;

-- 5. students — branch-scoped admin insert, no teacher insert.
do $$
declare
  v_admin uuid := (select id from sai_wp where k = 'admin_a');
  v_teacher uuid := (select id from sai_wp where k = 'teacher_a');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_b uuid := (select id from sai_wp where k = 'branch_b');
  v_class_a uuid := (select id from sai_wp where k = 'class_a');
  v_student_b uuid := (select id from sai_wp where k = 'student_b');
  v_run text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_affected integer;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';

  insert into public.students (branch_id, admission_no, full_name, class_id)
    values (v_a, 'WP-' || v_run || '-OK', 'WP TEST Student OK', v_class_a);

  v_denied := false;
  begin
    insert into public.students (branch_id, admission_no, full_name)
      values (v_b, 'WP-' || v_run || '-BAD', 'WP TEST Student Bad');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 5 FAIL: admin inserted a student in another branch'; end if;

  update public.students set full_name = 'WP TEST hijack' where id = v_student_b;
  get diagnostics v_affected = row_count;
  if v_affected <> 0 then raise exception 'PATH 5 FAIL: admin updated a foreign-branch student'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_teacher::text, true);
  execute 'set local role authenticated';
  v_denied := false;
  begin
    insert into public.students (branch_id, admission_no, full_name)
      values (v_a, 'WP-' || v_run || '-T', 'WP TEST Student Teacher');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 5 FAIL: teacher inserted a student'; end if;
  execute 'reset role';
  raise notice 'PASS path 5: students branch-scoped admin insert';
end;
$$;

-- 6. branch_memberships — super_admin insert, admin self-update only.
do $$
declare
  v_super uuid := (select id from sai_wp where k = 'super');
  v_admin uuid := (select id from sai_wp where k = 'admin_a');
  v_admin_b uuid := (select id from sai_wp where k = 'admin_b');
  v_parent uuid := (select id from sai_wp where k = 'parent');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_affected integer;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  execute 'set local role authenticated';

  v_denied := false;
  begin
    insert into public.branch_memberships (user_id, branch_id, is_active)
      values (v_parent, v_a, true);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 6 FAIL: admin inserted a membership'; end if;

  update public.branch_memberships set is_active = false
    where user_id = v_admin and branch_id = v_a;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 6 FAIL: admin could not update own membership'; end if;

  update public.branch_memberships set is_active = false
    where user_id = v_admin_b and branch_id in (select id from sai_wp where k = 'branch_b');
  get diagnostics v_affected = row_count;
  if v_affected <> 0 then raise exception 'PATH 6 FAIL: admin updated another membership'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_super::text, true);
  execute 'set local role authenticated';
  insert into public.branch_memberships (user_id, branch_id, is_active)
    values (v_parent, v_a, true);
  execute 'reset role';
  raise notice 'PASS path 6: branch_memberships super_admin insert, admin self-update';
end;
$$;

-- 7. admissions_enquiries — staff insert with created_by = self.
do $$
declare
  v_reception uuid := (select id from sai_wp where k = 'reception_a');
  v_teacher uuid := (select id from sai_wp where k = 'teacher_a');
  v_student_user uuid := (select id from sai_wp where k = 'student_user');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_session uuid := (select id from sai_wp where k = 'session');
  v_run text := substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
  v_id uuid;
  v_affected integer;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_reception::text, true);
  execute 'set local role authenticated';

  insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name, created_by, status)
    values (v_a, v_session, 'WP TEST Applicant', v_reception, 'new')
    returning id into v_id;

  v_denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name, created_by, status)
      values (v_a, v_session, 'WP TEST Spoofed', v_teacher, 'new');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 7 FAIL: inserted an enquiry attributed to another user'; end if;

  update public.admissions_enquiries set status = 'contacted' where id = v_id;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 7 FAIL: receptionist could not update an enquiry'; end if;

  update public.admissions_enquiries set status = 'closed' where id = v_id;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 7 FAIL: receptionist status change rejected'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_teacher::text, true);
  execute 'set local role authenticated';
  update public.admissions_enquiries set assigned_to = v_teacher where id = v_id;
  get diagnostics v_affected = row_count;
  if v_affected <> 0 then raise exception 'PATH 7 FAIL: teacher updated an unassigned enquiry'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_student_user::text, true);
  execute 'set local role authenticated';
  v_denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
      values (v_a, v_session, 'WP TEST Student');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 7 FAIL: student inserted an enquiry'; end if;
  execute 'reset role';
  raise notice 'PASS path 7: admissions staff insert with created_by = self';
end;
$$;

-- 8. attendance — teacher session and record for own class only.
do $$
declare
  v_teacher uuid := (select id from sai_wp where k = 'teacher_a');
  v_reception uuid := (select id from sai_wp where k = 'reception_a');
  v_student_user uuid := (select id from sai_wp where k = 'student_user');
  v_a uuid := (select id from sai_wp where k = 'branch_a');
  v_b uuid := (select id from sai_wp where k = 'branch_b');
  v_session uuid := (select id from sai_wp where k = 'session');
  v_class_a uuid := (select id from sai_wp where k = 'class_a');
  v_class_b uuid := (select id from sai_wp where k = 'class_b');
  v_student_a uuid := (select id from sai_wp where k = 'student_a');
  v_att uuid;
  v_rec uuid;
  v_affected integer;
  v_denied boolean;
begin
  perform set_config('request.jwt.claim.sub', v_teacher::text, true);
  execute 'set local role authenticated';

  insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date, created_by)
    values (v_a, v_session, v_class_a, current_date, v_teacher)
    returning id into v_att;

  v_denied := false;
  begin
    insert into public.attendance_sessions (branch_id, academic_session_id, class_id, attendance_date, created_by)
      values (v_b, v_session, v_class_b, current_date, v_teacher);
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 8 FAIL: teacher opened a session for a foreign class'; end if;

  insert into public.attendance_records (attendance_session_id, student_id, status)
    values (v_att, v_student_a, 'present')
    returning id into v_rec;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_student_user::text, true);
  execute 'set local role authenticated';
  v_denied := false;
  begin
    insert into public.attendance_records (attendance_session_id, student_id, status)
      values (v_att, v_student_a, 'absent');
  exception when insufficient_privilege then v_denied := true;
  end;
  if not v_denied then raise exception 'PATH 8 FAIL: student marked attendance'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', v_reception::text, true);
  execute 'set local role authenticated';
  update public.attendance_records set status = 'late' where id = v_rec;
  get diagnostics v_affected = row_count;
  if v_affected <> 1 then raise exception 'PATH 8 FAIL: receptionist could not correct attendance'; end if;
  execute 'reset role';

  raise notice 'PASS path 8: attendance teacher-scoped session and record';
end;
$$;

do $$ begin
  raise notice 'ALL 8 WRITE PATHS PASS — grants are in place and role scoping holds';
end; $$;

rollback;