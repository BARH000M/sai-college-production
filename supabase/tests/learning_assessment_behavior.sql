-- Disposable isolated database only. Verifies server-side grading, answer-key
-- hiding, assessed-completion guarding, and scoped result visibility.
begin;
do $$
begin
  if current_setting('sai.learning_assessment_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;

do $$
declare
  super_id uuid := gen_random_uuid(); teacher_id uuid := gen_random_uuid();
  other_teacher_id uuid := gen_random_uuid();
  student_user uuid := gen_random_uuid(); outsider_user uuid := gen_random_uuid();
  parent_id uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid(); session_id uuid := gen_random_uuid();
  class_a uuid := gen_random_uuid(); class_b uuid := gen_random_uuid();
  student_a uuid := gen_random_uuid(); student_out uuid := gen_random_uuid();
  course_a uuid := gen_random_uuid(); v_lesson uuid := gen_random_uuid();
  draft_lesson uuid := gen_random_uuid();
  word_id uuid; q_vocab uuid; q_listen uuid; result jsonb; basis text;
  denied boolean; n integer; is_right boolean;
  run_id text := replace(gen_random_uuid()::text, '-', '');
begin
  insert into auth.users (id, email_confirmed_at) values
    (super_id, now()), (teacher_id, now()), (other_teacher_id, now()),
    (student_user, now()), (outsider_user, now()), (parent_id, now());
  insert into public.user_roles (user_id, role) values
    (super_id, 'super_admin'), (teacher_id, 'teacher'), (other_teacher_id, 'teacher'),
    (student_user, 'student'), (outsider_user, 'student'), (parent_id, 'parent');
  perform set_config('request.jwt.claim.sub', super_id::text, true);
  insert into public.branches (id, name, code) values
    (branch_a, 'QUIZ_TEST', 'QUIZ_TEST_' || run_id);
  insert into public.academic_sessions (id, name, starts_on, ends_on, is_active)
    values (session_id, 'QUIZ_TEST_' || run_id, current_date, current_date + 30, true);
  insert into public.branch_memberships (user_id, branch_id, is_active) values
    (teacher_id, branch_a, true), (other_teacher_id, branch_a, true);
  insert into public.classes (id, branch_id, session_id, name, program, teacher_id) values
    (class_a, branch_a, session_id, 'QUIZ_TEST_a', 'chinese', teacher_id),
    (class_b, branch_a, session_id, 'QUIZ_TEST_b', 'chinese', other_teacher_id);
  insert into public.students (id, branch_id, admission_no, full_name, class_id) values
    (student_a, branch_a, 'QUIZ_TEST_' || run_id || '_a', 'QUIZ_TEST_a', class_a),
    (student_out, branch_a, 'QUIZ_TEST_' || run_id || '_b', 'QUIZ_TEST_b', class_b);
  execute 'set local role authenticated';
  perform public.admissions_link_student_account(student_a, student_user);
  perform public.admissions_link_student_account(student_out, outsider_user);
  perform public.admissions_verify_parent_student(student_a, parent_id);
  execute 'reset role';
  insert into public.learning_courses (id, branch_id, session_id, class_id, title)
    values (course_a, branch_a, session_id, class_a, 'QUIZ_TEST_' || run_id);
  insert into public.learning_lessons (id, course_id, title, kind, is_published) values
    (v_lesson, course_a, 'QUIZ_TEST_lesson', 'vocabulary', true),
    (draft_lesson, course_a, 'QUIZ_TEST_draft', 'lesson', false);

  -- The answer key column is never selectable by any client role.
  if has_column_privilege('authenticated', 'public.learning_exercise_questions', 'correct_choice', 'SELECT')
    or has_column_privilege('anon', 'public.learning_exercise_questions', 'correct_choice', 'SELECT')
    or has_table_privilege('anon', 'public.learning_exercise_questions', 'SELECT')
    or has_table_privilege('authenticated', 'public.learning_exercise_attempts', 'INSERT,UPDATE,DELETE')
    then raise exception 'Exercise access grants are too broad'; end if;

  -- The assigned teacher authors questions, including a vocabulary-linked one.
  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  execute 'set local role authenticated';
  insert into public.learning_vocabulary (course_id, lesson_id, hanzi, pinyin, meaning_ar)
    values (course_a, v_lesson, '你好', 'ni hao', 'QUIZ_TEST_greeting')
    returning id into word_id;
  insert into public.learning_exercise_questions
    (lesson_id, vocabulary_id, kind, prompt, choices, correct_choice, position)
  values
    (v_lesson, word_id, 'vocabulary', 'ما معنى 你好؟',
      '["مرحباً", "وداعاً", "شكراً"]'::jsonb, 0, 1)
    returning id into q_vocab;
  insert into public.learning_exercise_questions
    (lesson_id, kind, prompt, choices, correct_choice, position)
  values
    (v_lesson, 'listening', 'استمع واختر المعنى الصحيح',
      '["كتاب", "معلم", "مدرسة"]'::jsonb, 1, 2)
    returning id into q_listen;

  -- Invalid question shapes are rejected.
  denied := false;
  begin
    insert into public.learning_exercise_questions
      (lesson_id, kind, prompt, choices, correct_choice)
    values (v_lesson, 'vocabulary', 'QUIZ_TEST_bad', '["واحد", null]'::jsonb, 0);
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Null choice accepted'; end if;
  denied := false;
  begin
    insert into public.learning_exercise_questions
      (lesson_id, kind, prompt, choices, correct_choice)
    values (v_lesson, 'vocabulary', 'QUIZ_TEST_bad', '["واحد", "اثنان"]'::jsonb, 5);
  exception when check_violation then denied := true; end;
  if not denied then raise exception 'Out-of-range answer index accepted'; end if;

  -- The manager reads back the answer key; other teachers and students cannot.
  if not exists (select 1 from public.sai_learning_exercise_questions_admin(v_lesson)
    where id = q_vocab and correct_choice = 0) then
    raise exception 'Manager cannot read own answer keys';
  end if;
  perform set_config('request.jwt.claim.sub', other_teacher_id::text, true);
  if exists (select 1 from public.sai_learning_exercise_questions_admin(v_lesson)) then
    raise exception 'Unassigned teacher read answer keys';
  end if;
  denied := false;
  begin
    insert into public.learning_exercise_questions
      (lesson_id, kind, prompt, choices, correct_choice)
    values (v_lesson, 'vocabulary', 'QUIZ_TEST_other', '["أ", "ب"]'::jsonb, 0);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Unassigned teacher created a question'; end if;

  -- The enrolled student sees published questions without the answer key.
  perform set_config('request.jwt.claim.sub', student_user::text, true);
  select count(*) into n from public.learning_exercise_questions where lesson_id = v_lesson;
  if n <> 2 then raise exception 'Student cannot read published questions'; end if;
  denied := false;
  begin
    insert into public.learning_exercise_attempts (question_id, student_id, selected_choice, is_correct)
      values (q_vocab, student_a, 0, true);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Student inserted an attempt directly'; end if;

  -- One correct, one wrong: server computes 50%, below the pass mark.
  result := public.sai_learning_submit_exercise(v_lesson,
    jsonb_build_array(
      jsonb_build_object('question', q_vocab, 'choice', 2),
      jsonb_build_object('question', q_listen, 'choice', 1)));
  if (result ->> 'total')::int <> 2 or (result ->> 'correct')::int <> 1
    or (result ->> 'score')::int <> 50 or (result -> 'passed')::boolean then
    raise exception 'Server grading wrong: %', result;
  end if;
  select a.is_correct into is_right from public.learning_exercise_attempts a
    where a.question_id = q_vocab and a.student_id = student_a;
  if is_right then raise exception 'Wrong answer stored as correct'; end if;

  -- Malformed choices are graded as wrong answers, never as server errors.
  result := public.sai_learning_submit_exercise(v_lesson,
    jsonb_build_array(
      jsonb_build_object('question', q_vocab, 'choice', 1.5),
      jsonb_build_object('question', q_listen, 'choice', -1)));
  if (result ->> 'score')::int <> 0 or (result -> 'passed')::boolean then
    raise exception 'Malformed choices were not graded as wrong: %', result;
  end if;

  -- The missed vocabulary word rejoined the spaced-review queue.
  if not exists (select 1 from public.learning_vocab_progress
    where vocabulary_id = word_id and student_id = student_a
      and status = 'learning' and review_count = 0) then
    raise exception 'Missed word was not queued for review';
  end if;
  if exists (select 1 from public.learning_lesson_progress
    where lesson_id = v_lesson and student_id = student_a and status = 'completed') then
    raise exception 'Failing attempt recorded completion';
  end if;

  -- A student cannot forge an assessed completion directly.
  denied := false;
  begin
    insert into public.learning_lesson_progress (lesson_id, student_id, status, completion_basis)
      values (v_lesson, student_a, 'completed', 'assessed');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Client forged an assessed completion'; end if;

  -- Self-reported completion still works unchanged.
  insert into public.learning_lesson_progress (lesson_id, student_id, status, completion_basis)
    values (draft_lesson, student_a, 'completed', 'self_reported');

  -- A student from another class cannot submit to this course.
  perform set_config('request.jwt.claim.sub', outsider_user::text, true);
  denied := false;
  begin
    perform public.sai_learning_submit_exercise(v_lesson, '[]'::jsonb);
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Non-enrolled student submitted answers'; end if;

  -- Full marks: the server records assessed completion.
  perform set_config('request.jwt.claim.sub', student_user::text, true);
  result := public.sai_learning_submit_exercise(v_lesson,
    jsonb_build_array(
      jsonb_build_object('question', q_vocab, 'choice', 0),
      jsonb_build_object('question', q_listen, 'choice', 1)));
  if (result ->> 'score')::int <> 100 or not (result -> 'passed')::boolean then
    raise exception 'Perfect submission not passed: %', result;
  end if;
  select p.completion_basis into basis from public.learning_lesson_progress p
    where p.lesson_id = v_lesson and p.student_id = student_a;
  if basis is distinct from 'assessed' then raise exception 'Assessed completion not recorded'; end if;

  -- Class teacher and verified parent read the results; the outsider cannot.
  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  select count(*) into n from public.learning_exercise_attempts where student_id = student_a;
  if n <> 2 then raise exception 'Teacher cannot read class results'; end if;
  perform set_config('request.jwt.claim.sub', parent_id::text, true);
  select count(*) into n from public.learning_exercise_attempts where student_id = student_a;
  if n <> 2 then raise exception 'Verified parent cannot read child results'; end if;
  perform set_config('request.jwt.claim.sub', outsider_user::text, true);
  select count(*) into n from public.learning_exercise_attempts where student_id = student_a;
  if n <> 0 then raise exception 'Classmate read another student''s results'; end if;

  execute 'reset role';
end;
$$;
rollback;
select 'Learning assessment authorization assertions passed; fixtures rolled back' as result;
