-- Disposable isolated database only. Verifies the Chinese lesson workflow:
-- teacher lesson authoring, exercise-based completion provenance, and
-- student/parent/teacher visibility of learning progress.
begin;
do $$
begin
  if current_setting('sai.learning_completion_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  super_id uuid := gen_random_uuid(); teacher_id uuid := gen_random_uuid();
  other_teacher_id uuid := gen_random_uuid(); admin_b_id uuid := gen_random_uuid();
  student_user uuid := gen_random_uuid(); other_student_user uuid := gen_random_uuid();
  parent_id uuid := gen_random_uuid(); unverified_parent_id uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid(); branch_b uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid(); class_a uuid := gen_random_uuid(); class_b uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid(); student_b uuid := gen_random_uuid();
  course_a uuid := gen_random_uuid(); lesson_pub uuid := gen_random_uuid();
  lesson_draft uuid := gen_random_uuid(); lesson_teacher uuid; word_id uuid;
  denied boolean; n integer; basis text;
  run_id text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into auth.users (id, email_confirmed_at) values
    (super_id, now()), (teacher_id, now()), (other_teacher_id, now()), (admin_b_id, now()),
    (student_user, now()), (other_student_user, now()), (parent_id, now()), (unverified_parent_id, now());
  insert into public.user_roles (user_id, role) values
    (super_id, 'super_admin'), (teacher_id, 'teacher'), (other_teacher_id, 'teacher'),
    (admin_b_id, 'admin'), (student_user, 'student'), (other_student_user, 'student'),
    (parent_id, 'parent'), (unverified_parent_id, 'parent');
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  insert into public.branches (id, name, code) values
    (branch_a, 'LEARN_TEST_a', 'LEARN_TEST_' || run_id || '_a'),
    (branch_b, 'LEARN_TEST_b', 'LEARN_TEST_' || run_id || '_b');
  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
    values (session_id, 'LEARN_TEST_' || run_id, current_date, current_date + 30, true);
  insert into public.branch_memberships (user_id, branch_id, is_active) values
    (teacher_id, branch_a, true), (other_teacher_id, branch_a, true), (admin_b_id, branch_b, true);
  insert into public.classes (id, branch_id, session_id, name, program, teacher_id) values
    (class_a, branch_a, session_id, 'LEARN_TEST_a', 'chinese', teacher_id),
    (class_b, branch_b, session_id, 'LEARN_TEST_b', 'chinese', null);
  insert into public.students (id, branch_id, admission_no, full_name, class_id) values
    (student_a, branch_a, 'LEARN_TEST_' || run_id || '_a', 'LEARN_TEST_a', class_a),
    (student_b, branch_a, 'LEARN_TEST_' || run_id || '_b', 'LEARN_TEST_b', class_a);
  execute 'set local role authenticated';
  perform public.admissions_link_student_account(student_a, student_user);
  perform public.admissions_link_student_account(student_b, other_student_user);
  perform public.admissions_verify_parent_student(student_a, parent_id);
  execute 'reset role';

  -- Legacy unverified link predating the verification guard.
  alter table public.parent_student_links disable trigger parent_student_links_guard_verification;
  insert into public.parent_student_links (parent_user_id, student_id)
    values (unverified_parent_id, student_a);
  alter table public.parent_student_links enable trigger parent_student_links_guard_verification;

  insert into public.learning_courses (id, branch_id, session_id, class_id, title)
    values (course_a, branch_a, session_id, class_a, 'LEARN_TEST_' || run_id);
  insert into public.learning_lessons (id, course_id, title, kind, is_published) values
    (lesson_pub, course_a, 'LEARN_TEST_pub', 'lesson', true),
    (lesson_draft, course_a, 'LEARN_TEST_draft', 'reading', false);

  -- Teacher authors a lesson and vocabulary in their own class course.
  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  execute 'set local role authenticated';
  insert into public.learning_lessons (course_id, title, kind, position, duration_minutes, is_published)
    values (course_a, 'LEARN_TEST_teacher_lesson', 'listening', 3, 30, true)
    returning id into lesson_teacher;
  if lesson_teacher is null then raise exception 'Teacher lesson not created'; end if;
  insert into public.learning_vocabulary (course_id, lesson_id, hanzi, pinyin, meaning_ar)
    values (course_a, lesson_teacher, '你好', 'ni hao', 'LEARN_TEST_greeting')
    returning id into word_id;

  -- Another teacher in the same branch but a different class cannot author here.
  perform set_config('request.jwt.claim.sub', other_teacher_id::text, true);
  denied := false;
  begin
    insert into public.learning_lessons (course_id, title) values (course_a, 'LEARN_TEST_other');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Unassigned teacher created a lesson'; end if;

  -- An admin of another branch cannot author in this course either.
  perform set_config('request.jwt.claim.sub', admin_b_id::text, true);
  denied := false;
  begin
    insert into public.learning_lessons (course_id, title) values (course_a, 'LEARN_TEST_admin_b');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Cross-branch admin created a lesson'; end if;

  -- The enrolled student sees published lessons only.
  perform set_config('request.jwt.claim.sub', student_user::text, true);
  select count(*) into n from public.learning_lessons where course_id = course_a;
  if n <> 2 or exists (select 1 from public.learning_lessons where id = lesson_draft and not is_published) then
    raise exception 'Student sees a draft lesson or misses a published one';
  end if;
  denied := false;
  begin
    insert into public.learning_lessons (course_id, title) values (course_a, 'LEARN_TEST_student');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student created a lesson'; end if;

  -- A non-manager student cannot add vocabulary to the course bank.
  denied := false;
  begin
    insert into public.learning_vocabulary (course_id, hanzi, pinyin, meaning_ar)
      values (course_a, 'test', 'test', 'LEARN_TEST_denied');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student wrote to the vocabulary bank'; end if;

  -- Self-reported completion: the student's own account records progress.
  -- The basis only proves which flow wrote the row, not verified mastery.
  insert into public.learning_lesson_progress (lesson_id, student_id, status)
    values (lesson_teacher, student_a, 'in_progress');
  update public.learning_lesson_progress
    set status = 'completed', completion_basis = 'self_reported'
    where lesson_id = lesson_teacher and student_id = student_a;
  select completion_basis into basis from public.learning_lesson_progress
    where lesson_id = lesson_teacher and student_id = student_a;
  if basis <> 'self_reported' then raise exception 'Completion basis not recorded'; end if;

  -- Unknown provenance values are rejected.
  denied := false;
  begin
    update public.learning_lesson_progress set completion_basis = 'verified'
      where lesson_id = lesson_teacher and student_id = student_a;
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Unknown completion basis accepted'; end if;

  -- The student cannot write another student's progress or vocabulary review.
  denied := false;
  begin
    insert into public.learning_lesson_progress (lesson_id, student_id, status)
      values (lesson_teacher, student_b, 'completed');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student wrote another student''s progress'; end if;
  insert into public.learning_vocab_progress (vocabulary_id, student_id, status, review_count)
    values (word_id, student_a, 'learning', 1);
  denied := false;
  begin
    insert into public.learning_vocab_progress (vocabulary_id, student_id, status, review_count)
      values (word_id, student_b, 'learning', 1);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student wrote another student''s vocabulary review'; end if;

  -- A classmate sees only their own progress and cannot overwrite this one.
  perform set_config('request.jwt.claim.sub', other_student_user::text, true);
  select count(*) into n from public.learning_lesson_progress
    where lesson_id = lesson_teacher and student_id = student_a;
  if n <> 0 then raise exception 'Classmate read another student''s progress'; end if;
  update public.learning_lesson_progress set status = 'not_started'
    where lesson_id = lesson_teacher and student_id = student_a;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Classmate updated another student''s progress'; end if;

  -- Teachers and parents never write progress; visibility stays scoped.
  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  denied := false;
  begin
    insert into public.learning_lesson_progress (lesson_id, student_id, status)
      values (lesson_teacher, student_a, 'completed');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Teacher wrote student progress'; end if;
  if not exists (select 1 from public.learning_lesson_progress
    where lesson_id = lesson_teacher and student_id = student_a) then
    raise exception 'Assigned teacher cannot read class progress';
  end if;

  perform set_config('request.jwt.claim.sub', parent_id::text, true);
  if not exists (select 1 from public.learning_lesson_progress
    where lesson_id = lesson_teacher and student_id = student_a) then
    raise exception 'Verified parent cannot read child progress';
  end if;
  denied := false;
  begin
    update public.learning_lesson_progress set status = 'completed'
      where lesson_id = lesson_teacher and student_id = student_a;
    if found then raise exception 'Parent updated progress'; end if;
  exception when insufficient_privilege then denied := true; end;

  perform set_config('request.jwt.claim.sub', unverified_parent_id::text, true);
  select count(*) into n from public.learning_lesson_progress
    where lesson_id = lesson_teacher and student_id = student_a;
  if n <> 0 then raise exception 'Unverified parent read child progress'; end if;

  execute 'reset role';

  -- Anonymous clients hold no vocabulary or progress privileges at all.
  if has_table_privilege('anon', 'public.learning_vocabulary', 'SELECT,INSERT,UPDATE,DELETE')
    or has_table_privilege('anon', 'public.learning_vocab_progress', 'SELECT,INSERT,UPDATE,DELETE')
    or has_table_privilege('anon', 'public.learning_lesson_progress', 'SELECT,INSERT,UPDATE,DELETE')
    then raise exception 'Anonymous learning access granted'; end if;
end;
$$;
rollback;
select 'Learning completion authorization assertions passed; fixtures rolled back' as result;
