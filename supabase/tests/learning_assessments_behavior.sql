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
create table public.learning_exercise_questions (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.learning_lessons(id) on delete cascade,
  vocabulary_id uuid,
  kind text not null check (kind in ('vocabulary','listening')),
  prompt text not null check (length(btrim(prompt)) between 2 and 200),
  choices jsonb not null,
  correct_choice integer not null,
  position integer not null default 1,
  is_published boolean not null default true,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(choices) = 'array'
    and jsonb_array_length(choices) between 2 and 6
    and correct_choice >= 0
    and correct_choice < jsonb_array_length(choices))
);
create table public.learning_exercise_attempts (
  question_id uuid not null references public.learning_exercise_questions(id),
  student_id uuid not null references public.students(id),
  selected_choice integer not null,
  is_correct boolean not null,
  answered_at timestamptz not null default now(),
  primary key(question_id,student_id)
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
update public.learning_assessments set status='published'
  where id='00000000-0000-0000-0000-000000000701';

select public.as_user('00000000-0000-0000-0000-000000000102');
do $$
declare v_started jsonb; v_attempt uuid; v_result jsonb; v_answer uuid;
begin
  if (select count(*) from public.learning_exercise_questions
      where assessment_id='00000000-0000-0000-0000-000000000701') <> 5 then
    raise exception 'Published assessment questions are not visible';
  end if;
  begin
    perform correct_choice from public.learning_exercise_questions
      where id='00000000-0000-0000-0000-000000000801';
    raise exception 'Student read answer key';
  exception when insufficient_privilege then null;
  end;
  v_started := public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000701');
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
declare v_answer uuid; v_attempt uuid;
begin
  select x.id,a.id into v_answer,v_attempt
    from public.learning_assessment_answers x
    join public.learning_assessment_attempts a on a.id=x.attempt_id
    where x.question_id='00000000-0000-0000-0000-000000000805';
  perform public.sai_learning_assessment_grade(v_answer,3,'إجابة جيدة');
  if (select status from public.learning_assessment_attempts where id=v_attempt) <> 'graded'
    or (select score from public.learning_assessment_attempts where id=v_attempt) <> 9 then
    raise exception 'Teacher grading did not recalculate the authoritative result';
  end if;
  update public.learning_assessments set results_released=true
    where id='00000000-0000-0000-0000-000000000701';
end $$;

select public.as_user('00000000-0000-0000-0000-000000000103');
do $$
begin
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

