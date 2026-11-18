-- Synthetic Phase 4B assessment contract; run only in the isolated local cluster.
-- These fixtures emulate the referenced Main contracts; they are not a database replay.
create schema auth;
create schema private;
create schema storage;
create role anon nologin;
create role authenticated nologin;
create function auth.uid() returns uuid language sql stable as
  $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth, public, private, storage to authenticated, anon;
grant execute on function auth.uid() to authenticated;

create table auth.users (id uuid primary key);
create table public.user_roles (user_id uuid not null, role text not null, primary key(user_id,role));
create table public.parent_student_links (
  parent_user_id uuid not null, student_id uuid not null, verified_at timestamptz,
  primary key(parent_user_id,student_id)
);
create table public.classes (id uuid primary key, teacher_id uuid);
create table public.academic_sessions (id uuid primary key);
create table public.learning_courses (
  id uuid primary key, class_id uuid not null references public.classes,
  session_id uuid not null references public.academic_sessions
);
create table public.learning_lessons (
  id uuid primary key, course_id uuid not null references public.learning_courses,
  is_published boolean not null default true
);
create table public.students (
  id uuid primary key, user_id uuid, class_id uuid not null references public.classes,
  status text not null default 'active'
);
create table public.learning_homework (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.learning_courses,
  title text not null,
  instructions text,
  due_at timestamptz not null,
  max_score integer not null default 100,
  is_published boolean not null default true
);
create table public.learning_homework_submissions (
  id uuid primary key default gen_random_uuid(),
  homework_id uuid not null references public.learning_homework,
  student_id uuid not null references public.students(id),
  status text not null default 'submitted',
  content text,
  submitted_at timestamptz not null default now(),
  score numeric,
  feedback text,
  graded_at timestamptz,
  graded_by uuid,
  unique(homework_id,student_id)
);
create table public.learning_vocabulary (
  id uuid primary key, course_id uuid not null references public.learning_courses
);
create table public.learning_vocab_progress (
  vocabulary_id uuid not null, student_id uuid not null, status text,
  review_count integer, last_reviewed_at timestamptz, updated_at timestamptz,
  primary key(vocabulary_id,student_id)
);
create table public.learning_lesson_progress (
  lesson_id uuid not null, student_id uuid not null, status text,
  completion_basis text, updated_at timestamptz,
  primary key(lesson_id,student_id)
);
create table public.audit_logs (
  actor_user_id uuid, action text, entity_type text, entity_id uuid, metadata jsonb
);

insert into auth.users values
 ('00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000102'),
 ('00000000-0000-0000-0000-000000000103'),
 ('00000000-0000-0000-0000-000000000104');
insert into public.user_roles values
 ('00000000-0000-0000-0000-000000000101','teacher'),
 ('00000000-0000-0000-0000-000000000102','student'),
 ('00000000-0000-0000-0000-000000000103','parent'),
 ('00000000-0000-0000-0000-000000000104','student');
insert into public.classes values
 ('00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000101'),
 ('00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000104');
insert into public.academic_sessions values
 ('00000000-0000-0000-0000-000000000301');
insert into public.learning_courses values
 ('00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000201','00000000-0000-0000-0000-000000000301'),
 ('00000000-0000-0000-0000-000000000402','00000000-0000-0000-0000-000000000202','00000000-0000-0000-0000-000000000301');
insert into public.learning_lessons values
 ('00000000-0000-0000-0000-000000000501','00000000-0000-0000-0000-000000000401',true),
 ('00000000-0000-0000-0000-000000000502','00000000-0000-0000-0000-000000000402',true);
insert into public.students values
 ('00000000-0000-0000-0000-000000000601','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000000201','active'),
 ('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000202','active');
insert into public.parent_student_links values
 ('00000000-0000-0000-0000-000000000103','00000000-0000-0000-0000-000000000601',now());
create table storage.buckets (
  id text primary key, name text not null, public boolean not null,
  file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(), bucket_id text not null,
  name text not null, metadata jsonb
);
alter table storage.objects enable row level security;
create function storage.foldername(wanted_path text) returns text[] language sql immutable as $$
  select (string_to_array(wanted_path,'/'))[1:cardinality(string_to_array(wanted_path,'/'))-1]
$$;

create function private.sai_security_has_role(wanted text)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.user_roles r
    where r.user_id=(select auth.uid()) and r.role=wanted);
$$;
create function private.sai_security_can_read_student(wanted uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.students s where s.id=wanted and (
    s.user_id=(select auth.uid())
    or (private.sai_security_has_role('parent') and exists(
      select 1 from public.parent_student_links l where l.student_id=s.id
        and l.parent_user_id=(select auth.uid()) and l.verified_at is not null))
  ));
$$;
create function private.sai_security_can_read_class(wanted uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.classes c where c.id=wanted and (
    c.teacher_id=(select auth.uid())
    or exists(select 1 from public.students s where s.class_id=c.id
      and (s.user_id=(select auth.uid()) or exists(
        select 1 from public.parent_student_links l where l.student_id=s.id
          and l.parent_user_id=(select auth.uid()) and l.verified_at is not null)))
  ));
$$;
create function private.sai_learning_can_read_course(wanted uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.learning_courses c
    where c.id=wanted and private.sai_security_can_read_class(c.class_id));
$$;
create function private.sai_learning_own_student(wanted uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.students s
    where s.id=wanted and s.user_id=(select auth.uid()));
$$;
create function private.sai_learning_can_manage_course(wanted uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,private as $$
  select exists(select 1 from public.learning_courses c join public.classes cl on cl.id=c.class_id
    where c.id=wanted and (cl.teacher_id=(select auth.uid())
      or private.sai_security_has_role('super_admin')
      or (private.sai_security_has_role('admin') and cl.teacher_id=(select auth.uid()))));
$$;
create function private.sai_learning_question_course(wanted_lesson uuid)
returns uuid language sql stable security definer set search_path=pg_catalog,public,private as $$
  select l.course_id from public.learning_lessons l where l.id=wanted_lesson;
$$;
grant execute on function private.sai_security_has_role(text),
  private.sai_security_can_read_student(uuid),
  private.sai_security_can_read_class(uuid),
  private.sai_learning_can_read_course(uuid),
  private.sai_learning_own_student(uuid),
  private.sai_learning_can_manage_course(uuid),
  private.sai_learning_question_course(uuid) to authenticated;
\ir ../migrations/20261116013950_learning_scored_exercises.sql
grant select on public.students to authenticated;

-- Mirror the authenticated client grants and row filters required by the Main
-- contracts. Policy expressions below legitimately touch these relations while
-- evaluating student/family visibility; broad table ownership is not a substitute.
grant select on public.user_roles, public.parent_student_links, public.classes,
  public.academic_sessions, public.learning_courses, public.learning_lessons
  to authenticated;
alter table public.user_roles enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.classes enable row level security;
alter table public.academic_sessions enable row level security;
alter table public.learning_courses enable row level security;
alter table public.learning_lessons enable row level security;
create policy user_roles_read_self on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()));
create policy parent_links_read_related on public.parent_student_links for select to authenticated
  using (private.sai_security_can_read_student(student_id));
create policy classes_read_related on public.classes for select to authenticated
  using (private.sai_security_can_read_class(id));
create policy sessions_read_related on public.academic_sessions for select to authenticated
  using (private.sai_security_has_role('teacher')
    or private.sai_security_has_role('student')
    or private.sai_security_has_role('parent'));
create policy courses_read_related on public.learning_courses for select to authenticated
  using (private.sai_learning_can_read_course(id));
create policy lessons_read_related on public.learning_lessons for select to authenticated
  using (private.sai_learning_can_read_course(course_id));
alter table public.learning_exercise_questions enable row level security;
create function public.as_user(p_user uuid) returns void language sql as
  $$select set_config('request.jwt.claim.sub',p_user::text,false)$$;

\ir ../deployment/phase4b-assessments/001_learning_assessments.sql

set role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000101');
insert into public.learning_assessments
 (id,course_id,lesson_id,title,instructions,due_at,attempt_limit)
values
 ('00000000-0000-0000-0000-000000000701','00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000501','تقييم الدرس','أجب عن الأسئلة',now()+interval '1 day',1);
insert into public.learning_exercise_questions
 (id,lesson_id,kind,prompt,choices,correct_choice,position,assessment_id,points,answer_key)
values
 ('00000000-0000-0000-0000-000000000801','00000000-0000-0000-0000-000000000501',
  'multiple_choice','اختر الإجابة','["أ","ب"]',0,1,'00000000-0000-0000-0000-000000000701',2,null),
 ('00000000-0000-0000-0000-000000000802','00000000-0000-0000-0000-000000000501',
  'true_false','صح أم خطأ','["صح","خطأ"]',0,2,'00000000-0000-0000-0000-000000000701',1,null),
 ('00000000-0000-0000-0000-000000000803','00000000-0000-0000-0000-000000000501',
  'matching','صل بين الطرفين','["صباح","مساء","早","晚"]',null,3,
  '00000000-0000-0000-0000-000000000701',2,'{"صباح":"早","مساء":"晚"}'),
 ('00000000-0000-0000-0000-000000000804','00000000-0000-0000-0000-000000000501',
  'fill_blank','أكمل: 你好 تعني ___','[]',null,4,
  '00000000-0000-0000-0000-000000000701',1,'["مرحباً","مرحبا"]'),
 ('00000000-0000-0000-0000-000000000805','00000000-0000-0000-0000-000000000501',
  'written','اشرح الإجابة','[]',null,5,
  '00000000-0000-0000-0000-000000000701',4,null);
insert into public.learning_exercise_questions
 (id,lesson_id,kind,prompt,choices,correct_choice,position,assessment_id)
values
 ('00000000-0000-0000-0000-000000000806','00000000-0000-0000-0000-000000000501',
  'multiple_choice','Temporary question','["A","B"]',0,6,'00000000-0000-0000-0000-000000000701');
delete from public.learning_exercise_questions where id='00000000-0000-0000-0000-000000000806';
insert into public.learning_exercise_questions
 (id,lesson_id,kind,prompt,choices,correct_choice,position)
values
 ('00000000-0000-0000-0000-000000000807','00000000-0000-0000-0000-000000000501',
  'vocabulary','Practice question','["A","B"]',0,7);
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000701';
insert into public.learning_assessments (id,course_id,lesson_id,title,due_at)
values ('00000000-0000-0000-0000-000000000708',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Expired assessment',now()-interval '1 minute');
insert into public.learning_exercise_questions
  (lesson_id,kind,prompt,choices,correct_choice,assessment_id)
values ('00000000-0000-0000-0000-000000000501','multiple_choice','Expired question',
  '["A","B"]',0,'00000000-0000-0000-0000-000000000708');
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000708';
do $$
begin
  if (select count(*) from public.sai_learning_exercise_questions_admin(
        '00000000-0000-0000-0000-000000000501')) <> 1
    or not exists (select 1 from public.sai_learning_exercise_questions_admin(
        '00000000-0000-0000-0000-000000000501')
      where id='00000000-0000-0000-0000-000000000807') then
    raise exception 'Practice authoring included assessment questions';
  end if;
end $$;

select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
declare v_started jsonb; v_attempt uuid; v_result jsonb; v_answer uuid; v_practice jsonb;
begin
  if exists (select 1 from public.learning_exercise_questions
      where assessment_id='00000000-0000-0000-0000-000000000701') then
    raise exception 'Student can read assessment questions outside an attempt';
  end if;
  begin
    perform correct_choice from public.learning_exercise_questions
      where id='00000000-0000-0000-0000-000000000801';
    raise exception 'Student read answer key';
  exception when insufficient_privilege then null;
  end;
  v_practice := public.sai_learning_submit_exercise(
    '00000000-0000-0000-0000-000000000501',
    '[{"question":"00000000-0000-0000-0000-000000000807","choice":0}]');
  if (v_practice->>'total')::int <> 1 or (v_practice->>'score')::int <> 100
    or jsonb_array_length(v_practice->'results') <> 1 then
    raise exception 'Practice grading included assessment questions: %', v_practice;
  end if;
  v_started := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
  if jsonb_array_length(v_started->'questions') <> 5 then
    raise exception 'Authorized attempt did not receive its questions';
  end if;
  if v_started::text like '%answer_key%' or v_started::text like '%correct_choice%' then
    raise exception 'Start RPC leaked an answer key';
  end if;
  v_attempt := (v_started->>'attempt_id')::uuid;
  perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000801','0');
  perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000802','0');
  perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000803','{"صباح":"早","مساء":"晚"}');
  perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000804','"مرحباً"');
  perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000805','"إجابة كتابية مطولة"');
  v_result := public.sai_learning_assessment_submit(v_attempt);
  if v_result->>'status' <> 'submitted' or (v_result->>'needs_manual_grading')::int <> 1 then
    raise exception 'Objective grading or written-review state is wrong: %',v_result;
  end if;
  begin
    perform public.sai_learning_assessment_submit(v_attempt);
    raise exception 'Duplicate assessment submission succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000708');
    raise exception 'Expired assessment started';
  exception when raise_exception then
    if sqlerrm <> 'Assessment deadline has passed' then raise; end if;
  end;
  if exists (select 1 from public.learning_assessment_attempts
      where id=v_attempt and score is not null) then
    raise exception 'Unreleased result score should remain hidden from the student';
  end if;
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
    raise exception 'Attempt limit was not enforced';
  exception when raise_exception then
    if sqlerrm = 'Attempt limit was not enforced' then raise; end if;
  end;
end $$;

select public.as_user('00000000-0000-0000-0000-000000000101');
do $$
begin
  begin
    insert into public.learning_exercise_questions
      (lesson_id,kind,prompt,choices,correct_choice,assessment_id)
    values ('00000000-0000-0000-0000-000000000501','multiple_choice','Late question',
      '["A","B"]',0,'00000000-0000-0000-0000-000000000701');
    raise exception 'Question inserted after attempt';
  exception when check_violation then
    if sqlerrm <> 'Assessment questions cannot be edited after attempts begin' then raise; end if;
  end;
  begin
    delete from public.learning_exercise_questions
      where id='00000000-0000-0000-0000-000000000801';
    raise exception 'Question deleted after attempt';
  exception when check_violation then
    if sqlerrm <> 'Assessment questions cannot be edited after attempts begin' then raise; end if;
  end;
  begin
    update public.learning_exercise_questions set assessment_id='00000000-0000-0000-0000-000000000701'
      where id='00000000-0000-0000-0000-000000000807';
    raise exception 'Question moved into assessment after attempt';
  exception when check_violation then
    if sqlerrm <> 'Assessment questions cannot be edited after attempts begin' then raise; end if;
  end;
end $$;
do $$
declare v_answer uuid; v_attempt uuid;
begin
  select x.id,a.id into v_answer,v_attempt
    from public.learning_assessment_answers x
    join public.learning_assessment_attempts a on a.id=x.attempt_id
    where x.question_id='00000000-0000-0000-0000-000000000805';
  begin
    perform public.sai_learning_assessment_grade(v_answer,5,'Invalid grade');
    raise exception 'Written grade exceeded question maximum';
  exception when check_violation then null;
  end;
  perform public.sai_learning_assessment_grade(v_answer,3,'إجابة جيدة');
  if (select status from public.learning_assessment_attempts where id=v_attempt) <> 'graded'
    or (select score from public.learning_assessment_attempts where id=v_attempt) <> 9 then
    raise exception 'Teacher grading did not recalculate the authoritative result';
  end if;
  begin
    delete from public.learning_assessments
      where id='00000000-0000-0000-0000-000000000701';
    raise exception 'Published assessment deleted with grading history';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
do $$
begin
  begin
    delete from public.learning_assessments
      where id='00000000-0000-0000-0000-000000000701';
    raise exception 'Published assessment deletion guard did not run';
  exception when check_violation then
    if sqlerrm <> 'Published assessments and assessment history cannot be deleted' then raise; end if;
  end;
  if not exists (select 1 from public.learning_assessment_attempts
      where assessment_id='00000000-0000-0000-0000-000000000701') then
    raise exception 'Assessment deletion removed historical attempts';
  end if;
end $$;

set role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000101');
do $$
begin
  update public.learning_assessments set results_released=true
    where id='00000000-0000-0000-0000-000000000701';
end $$;

select public.as_user('00000000-0000-0000-0000-000000000103');
do $$
begin
  if exists (select 1 from public.learning_exercise_questions
      where assessment_id='00000000-0000-0000-0000-000000000701') then
    raise exception 'Parent can read the assessment question bank';
  end if;
  if not exists (select 1 from public.sai_learning_assessment_results('00000000-0000-0000-0000-000000000701')
      where score=9 and feedback='إجابة جيدة') then
    raise exception 'Verified parent cannot read released linked result';
  end if;
end $$;

select public.as_user('00000000-0000-0000-0000-000000000104');
do $$
begin
  if exists (select 1 from public.sai_learning_assessment_results('00000000-0000-0000-0000-000000000701')) then
    raise exception 'Unrelated student read another class result';
  end if;
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
    raise exception 'Cross-class student started an assessment';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
insert into public.learning_homework
  (id,course_id,title,instructions,due_at,max_score,is_published)
values
  ('00000000-0000-0000-0000-000000000702',
   '00000000-0000-0000-0000-000000000401','واجب آمن','أرفق إجابة',now()+interval '1 day',20,true);
select public.as_user('00000000-0000-0000-0000-000000000102');
insert into public.learning_homework_submissions
  (homework_id,student_id,status,content)
values
  ('00000000-0000-0000-0000-000000000702',
   '00000000-0000-0000-0000-000000000601','submitted','إجابة نصية صالحة');
do $$
declare v_submission uuid;
begin
  select id into v_submission from public.learning_homework_submissions
    where homework_id='00000000-0000-0000-0000-000000000702'
      and student_id='00000000-0000-0000-0000-000000000601';
  begin
    update public.learning_homework_submissions set score=5
      where id=v_submission;
    raise exception 'Student changed a protected grade';
  exception when insufficient_privilege then null;
  end;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000101');
update public.learning_homework_submissions
  set status='graded',score=18,feedback='عمل جيد',graded_by='00000000-0000-0000-0000-000000000104',
      graded_at='2000-01-01'
  where homework_id='00000000-0000-0000-0000-000000000702'
    and student_id='00000000-0000-0000-0000-000000000601';
do $$
begin
  if not exists (select 1 from public.learning_homework_submissions
    where homework_id='00000000-0000-0000-0000-000000000702'
      and student_id='00000000-0000-0000-0000-000000000601'
      and score=18 and graded_by='00000000-0000-0000-0000-000000000101'
      and graded_at > now()-interval '1 minute') then
    raise exception 'Teacher review was not server-attributed';
  end if;
  begin
    update public.learning_homework_submissions set score=21
      where homework_id='00000000-0000-0000-0000-000000000702'
        and student_id='00000000-0000-0000-0000-000000000601';
    raise exception 'Grade exceeded the homework maximum';
  exception when check_violation then null;
  end;
end $$;
select 'PASS: assessment authoring, hidden keys, autosave, objective grading, written review, attempt limits, released-family results, and protected homework grading';

begin;
set local role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000101');
insert into public.learning_assessments (id,course_id,lesson_id,title,due_at)
values ('00000000-0000-0000-0000-000000000710',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Deadline boundary',clock_timestamp()+interval '2 seconds');
insert into public.learning_exercise_questions
  (id,lesson_id,kind,prompt,choices,correct_choice,assessment_id)
values ('00000000-0000-0000-0000-000000000810',
  '00000000-0000-0000-0000-000000000501','multiple_choice','Deadline question',
  '["A","B"]',0,'00000000-0000-0000-0000-000000000710');
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000710';
select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
declare v_attempt uuid;
begin
  v_attempt := (public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000710')->>'attempt_id')::uuid;
  perform pg_sleep(2.2);
  begin
    perform public.sai_learning_assessment_save(v_attempt,'00000000-0000-0000-0000-000000000810','0');
    raise exception 'Answer accepted after real deadline';
  exception when raise_exception then
    if sqlerrm <> 'Assessment deadline has passed' then raise; end if;
  end;
  begin
    perform public.sai_learning_assessment_submit(v_attempt);
    raise exception 'Submission accepted after real deadline';
  exception when raise_exception then
    if sqlerrm <> 'Assessment deadline has passed' then raise; end if;
  end;
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000710');
    raise exception 'Attempt resumed after real deadline';
  exception when raise_exception then
    if sqlerrm <> 'Assessment deadline has passed' then raise; end if;
  end;
end $$;
rollback;

begin isolation level repeatable read;
set local role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
begin
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
    raise exception 'Repeatable-read attempt was accepted';
  exception when sqlstate '25001' then null;
  end;
  perform public.as_user('00000000-0000-0000-0000-000000000101');
  begin
    delete from public.learning_exercise_questions
      where id='00000000-0000-0000-0000-000000000801';
    raise exception 'Repeatable-read question edit was accepted';
  exception when sqlstate '25001' then null;
  end;
end $$;
rollback;

