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
  status text not null default 'active', full_name text not null default 'Student',
  admission_no text not null default 'STUDENT'
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
 ('00000000-0000-0000-0000-000000000104'),
 ('00000000-0000-0000-0000-000000000105');
insert into public.user_roles values
 ('00000000-0000-0000-0000-000000000101','teacher'),
 ('00000000-0000-0000-0000-000000000102','student'),
 ('00000000-0000-0000-0000-000000000103','parent'),
 ('00000000-0000-0000-0000-000000000104','student'),
 ('00000000-0000-0000-0000-000000000105','student');
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
 ('00000000-0000-0000-0000-000000000602','00000000-0000-0000-0000-000000000104','00000000-0000-0000-0000-000000000202','active'),
 ('00000000-0000-0000-0000-000000000603','00000000-0000-0000-0000-000000000105','00000000-0000-0000-0000-000000000201','active');
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
  'vocabulary','Practice question','["A","B"]',0,7),
 ('00000000-0000-0000-0000-000000000808','00000000-0000-0000-0000-000000000501',
  'true_false','هل نينغشيا في الصين؟','["صح","خطأ"]',0,8);
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000701';
insert into public.learning_assessments
 (id,course_id,lesson_id,title,starts_at,due_at,time_limit_minutes,attempt_limit,passing_score,randomize_questions)
values
 ('00000000-0000-0000-0000-000000000711',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Scheduled random assessment',now()+interval '1 hour',now()+interval '2 hours',30,2,65,true),
 ('00000000-0000-0000-0000-000000000712',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Individual assignment',null,now()+interval '2 hours',null,1,70,false),
 ('00000000-0000-0000-0000-000000000713',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Timed assessment',null,now()+interval '2 hours',1,1,70,false),
 ('00000000-0000-0000-0000-000000000714',
  '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
  'Question bank target',null,null,null,1,70,false);
insert into public.learning_exercise_questions
 (id,lesson_id,kind,prompt,choices,correct_choice,position,assessment_id,points)
values
 ('00000000-0000-0000-0000-000000000811','00000000-0000-0000-0000-000000000501',
  'multiple_choice','Scheduled question one','["A","B"]',0,1,'00000000-0000-0000-0000-000000000711',1),
 ('00000000-0000-0000-0000-000000000812','00000000-0000-0000-0000-000000000501',
  'multiple_choice','Scheduled question two','["A","B"]',0,2,'00000000-0000-0000-0000-000000000711',2),
 ('00000000-0000-0000-0000-000000000813','00000000-0000-0000-0000-000000000501',
  'multiple_choice','Assigned question','["A","B"]',0,1,'00000000-0000-0000-0000-000000000712',1),
 ('00000000-0000-0000-0000-000000000814','00000000-0000-0000-0000-000000000501',
  'multiple_choice','Timed question','["A","B"]',0,1,'00000000-0000-0000-0000-000000000713',1);
update public.learning_assessments set status='published'
  where id in ('00000000-0000-0000-0000-000000000711',
    '00000000-0000-0000-0000-000000000712',
    '00000000-0000-0000-0000-000000000713');
insert into public.learning_exercise_questions
  (lesson_id,kind,prompt,choices,correct_choice,assessment_id,points,bank_category)
values ('00000000-0000-0000-0000-000000000501','multiple_choice','Bank question',
  '["A","B"]',1,null,2,'مفردات');
insert into public.learning_exercise_questions
  (lesson_id,kind,prompt,choices,correct_choice,assessment_id,points,answer_key,bank_category)
values ('00000000-0000-0000-0000-000000000501','multiple_select','Select two',
  '["A","B","C"]',null,null,2,'[0,2]','قواعد'),
 ('00000000-0000-0000-0000-000000000501','ordering','Order three',
  '["C","A","B"]',null,null,2,'["A","B","C"]','ترتيب');
do $$
declare v_copy uuid; v_roster record; v_bank_id uuid; v_added_id uuid;
  v_multi_id uuid; v_order_id uuid;
begin
  v_copy := public.sai_learning_assessment_duplicate(
    '00000000-0000-0000-0000-000000000701', 'نسخة قابلة للتحرير');
  if not exists (select 1 from public.learning_assessments
      where id=v_copy and status='draft' and starts_at is null and due_at is null
        and attempt_limit=1 and passing_score=70 and randomize_questions=false)
    or (select count(*) from public.learning_exercise_questions where assessment_id=v_copy) <> 5
    or exists (select 1 from public.learning_assessment_attempts where assessment_id=v_copy) then
    raise exception 'Assessment duplication did not preserve settings/questions without history';
  end if;
  perform public.sai_learning_assessment_assign(
    '00000000-0000-0000-0000-000000000712',
    array['00000000-0000-0000-0000-000000000603'::uuid]);
  select * into v_roster from public.sai_learning_assessment_roster(
    '00000000-0000-0000-0000-000000000712')
    where student_id='00000000-0000-0000-0000-000000000601';
  if v_roster.assigned or v_roster.class_wide then
    raise exception 'Individual student assignment did not restrict the class roster';
  end if;
  select id into v_bank_id from public.sai_learning_assessment_question_bank(
    '00000000-0000-0000-0000-000000000401','مفردات');
  if v_bank_id is null then raise exception 'Teacher could not load categorized bank questions'; end if;
  v_added_id := public.sai_learning_assessment_add_from_bank(
    '00000000-0000-0000-0000-000000000714',v_bank_id);
  if not exists (select 1 from public.sai_learning_assessment_questions_admin(
      '00000000-0000-0000-0000-000000000714')
      where id=v_added_id and bank_category='مفردات' and correct_choice=1) then
    raise exception 'Question bank import did not preserve the protected answer key';
  end if;
  select id into v_bank_id from public.sai_learning_assessment_question_bank(
    '00000000-0000-0000-0000-000000000401','قواعد');
  v_multi_id := public.sai_learning_assessment_add_from_bank(
    '00000000-0000-0000-0000-000000000714',v_bank_id);
  if not exists (select 1 from public.sai_learning_assessment_questions_admin(
      '00000000-0000-0000-0000-000000000714')
      where id=v_multi_id and kind='multiple_select' and answer_key='[0,2]'::jsonb) then
    raise exception 'Multiple-select bank import did not preserve its answer set';
  end if;
  select id into v_bank_id from public.sai_learning_assessment_question_bank(
    '00000000-0000-0000-0000-000000000401','ترتيب');
  v_order_id := public.sai_learning_assessment_add_from_bank(
    '00000000-0000-0000-0000-000000000714',v_bank_id);
  if not exists (select 1 from public.sai_learning_assessment_questions_admin(
      '00000000-0000-0000-0000-000000000714')
      where id=v_order_id and kind='ordering' and answer_key='["A","B","C"]'::jsonb) then
    raise exception 'Ordering question import did not preserve the answer sequence';
  end if;
  begin
    perform public.sai_learning_assessment_assign(
      '00000000-0000-0000-0000-000000000712',
      array['00000000-0000-0000-0000-000000000602'::uuid]);
    raise exception 'Assessment assigned a student from another class';
  exception when check_violation then null;
  end;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
declare v_first jsonb; v_resume jsonb;
begin
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000711');
    raise exception 'Assessment opened before its scheduled start';
  exception when raise_exception then
    if sqlerrm <> 'Assessment has not started yet' then raise; end if;
  end;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
begin
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000712');
    raise exception 'Unassigned student started an individual assessment';
  exception when insufficient_privilege then null;
  end;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000101');
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000714';
select public.as_user('00000000-0000-0000-0000-000000000105');
do $$
declare
  v_start jsonb;
  v_attempt uuid;
  v_question jsonb;
  v_multiple uuid;
  v_result jsonb;
begin
  v_start := public.sai_learning_assessment_start(
    '00000000-0000-0000-0000-000000000714');
  v_attempt := (v_start->>'attempt_id')::uuid;
  select (question->>'id')::uuid into v_multiple
    from jsonb_array_elements(v_start->'questions') question
    where question->>'kind'='multiple_select';
  begin
    perform public.sai_learning_assessment_save(v_attempt,v_multiple,'[0,0]');
    raise exception 'Duplicate multiple-select answers were accepted';
  exception when check_violation then null;
  end;
  select (question->>'id')::uuid into v_multiple
    from jsonb_array_elements(v_start->'questions') question
    where question->>'kind'='ordering';
  begin
    perform public.sai_learning_assessment_save(v_attempt,v_multiple,'["A","A","C"]');
    raise exception 'Duplicate ordering answer was accepted';
  exception when check_violation then null;
  end;
  for v_question in select value from jsonb_array_elements(v_start->'questions')
  loop
    if v_question->>'kind'='multiple_select' then
      perform public.sai_learning_assessment_save(
        v_attempt,(v_question->>'id')::uuid,'[0,2]');
    elsif v_question->>'kind'='ordering' then
      perform public.sai_learning_assessment_save(
        v_attempt,(v_question->>'id')::uuid,'["A","B","C"]');
    else
      perform public.sai_learning_assessment_save(
        v_attempt,(v_question->>'id')::uuid,'1');
    end if;
  end loop;
  v_result := public.sai_learning_assessment_submit(v_attempt);
  if v_result->>'status' <> 'graded'
    or (select score from public.learning_assessment_attempts where id=v_attempt) <> 6 then
    raise exception 'Multiple-answer questions were not automatically graded: %',v_result;
  end if;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000101');
update public.learning_assessments set starts_at=now()-interval '1 minute'
  where id='00000000-0000-0000-0000-000000000711';
select public.as_user('00000000-0000-0000-0000-000000000105');
do $$
declare v_first jsonb; v_resume jsonb; v_order jsonb;
begin
  v_first := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000711');
  v_resume := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000711');
  if jsonb_array_length(v_first->'questions') <> 2
    or v_first->'questions' <> v_resume->'questions'
    or v_first->>'expires_at' is null then
    raise exception 'Randomized order or time-limit expiry was not stable across resume';
  end if;
  v_first := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000712');
  if jsonb_array_length(v_first->'questions') <> 1 then
    raise exception 'Assigned student could not start the assessment';
  end if;
  v_first := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000713');
  if v_first->>'status' <> 'in_progress' then
    raise exception 'Timed assessment did not start in progress';
  end if;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000101');
do $$
begin
  begin
    perform public.sai_learning_assessment_assign(
      '00000000-0000-0000-0000-000000000712',
      array['00000000-0000-0000-0000-000000000603'::uuid]);
    raise exception 'Assignment changed after an attempt began';
  exception when check_violation then null;
  end;
end $$;
reset role;
update public.learning_assessment_attempts
  set expires_at=clock_timestamp()-interval '1 second'
  where assessment_id='00000000-0000-0000-0000-000000000713';
set role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000105');
do $$
declare v_start jsonb;
begin
  v_start := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000713');
  if v_start->>'status' not in ('submitted', 'graded')
    or v_start->>'timed_out' <> 'true' then
    raise exception 'Expired timed attempt was not submitted automatically';
  end if;
end $$;
reset role;
do $$
begin
  if not exists (select 1 from public.learning_assessment_attempts
      where assessment_id='00000000-0000-0000-0000-000000000713'
        and status in ('submitted', 'graded')) then
    raise exception 'Timed attempt history was not persisted: %',
      (select jsonb_agg(jsonb_build_object('id',id,'student_id',student_id,
        'attempt_number',attempt_number,'status',status,'expires_at',expires_at))
        from public.learning_assessment_attempts
        where assessment_id='00000000-0000-0000-0000-000000000713');
  end if;
end $$;
set role authenticated;
select public.as_user('00000000-0000-0000-0000-000000000101');
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
        '00000000-0000-0000-0000-000000000501')) <> 2
    or not exists (select 1 from public.sai_learning_exercise_questions_admin(
        '00000000-0000-0000-0000-000000000501')
      where id in ('00000000-0000-0000-0000-000000000807',
        '00000000-0000-0000-0000-000000000808')
      group by lesson_id having count(*) = 2) then
    raise exception 'Practice authoring included assessment questions';
  end if;
end $$;

select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
declare v_started jsonb; v_attempt uuid; v_result jsonb; v_answer uuid; v_practice jsonb;
  v_resume jsonb;
begin
  if exists (select 1 from public.learning_exercise_questions
      where bank_category='مفردات') then
    raise exception 'Student can read the assessment question bank';
  end if;
  begin
    perform * from public.sai_learning_assessment_question_bank(
      '00000000-0000-0000-0000-000000000401',null);
    raise exception 'Student queried protected question bank';
  exception when insufficient_privilege then null;
  end;
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
    '[{"question":"00000000-0000-0000-0000-000000000807","choice":0},'
    '{"question":"00000000-0000-0000-0000-000000000808","choice":0}]');
  if (v_practice->>'total')::int <> 2 or (v_practice->>'score')::int <> 100
    or jsonb_array_length(v_practice->'results') <> 2 then
    raise exception 'Practice grading did not include both supported practice types: %', v_practice;
  end if;
  v_practice := public.sai_learning_submit_exercise(
    '00000000-0000-0000-0000-000000000501',
    '[{"question":"00000000-0000-0000-0000-000000000808","choice":1}]');
  if (v_practice->>'score')::int <> 0 or (v_practice->>'passed')::boolean then
    raise exception 'True/false wrong answer was not graded as incorrect: %', v_practice;
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
  v_resume := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
  if v_resume->>'attempt_id' <> v_attempt::text
    or v_resume->'saved_answers'->>'00000000-0000-0000-0000-000000000804' <> 'مرحباً' then
    raise exception 'Answers were not persisted and restored before submission';
  end if;
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
  update public.learning_assessments set status='closed'
    where id='00000000-0000-0000-0000-000000000701';
  begin
    update public.learning_assessments set status='draft'
      where id='00000000-0000-0000-0000-000000000701';
    raise exception 'Closed assessment with history returned to draft';
  exception when check_violation then null;
  end;
  update public.learning_assessments set results_released=true
    where id in ('00000000-0000-0000-0000-000000000701',
      '00000000-0000-0000-0000-000000000712');
end $$;

select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
begin
  if not exists (select 1 from public.learning_assessments
      where id='00000000-0000-0000-0000-000000000701' and status='closed')
    or not exists (select 1 from public.learning_assessment_attempts
      where assessment_id='00000000-0000-0000-0000-000000000701'
        and status='graded' and score=9) then
    raise exception 'Student cannot see a closed assessment and its released history';
  end if;
  begin
    perform public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
    raise exception 'Student restarted a closed assessment';
  exception when insufficient_privilege then null;
  end;
end $$;
select public.as_user('00000000-0000-0000-0000-000000000103');
do $$
begin
  if not exists (select 1 from public.learning_assessments
      where id='00000000-0000-0000-0000-000000000701' and status='closed') then
    raise exception 'Verified parent cannot see closed assessment history';
  end if;
  if exists (select 1 from public.learning_exercise_questions
      where assessment_id='00000000-0000-0000-0000-000000000701') then
    raise exception 'Parent can read the assessment question bank';
  end if;
  if not exists (select 1 from public.sai_learning_assessment_results('00000000-0000-0000-0000-000000000701')
      where score=9 and feedback='إجابة جيدة' and passed) then
    raise exception 'Verified parent cannot read released linked result';
  end if;
  if exists (select 1 from public.sai_learning_assessment_results('00000000-0000-0000-0000-000000000712')) then
    raise exception 'Parent read an individually assigned assessment for an unassigned child';
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

