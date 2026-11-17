-- Synthetic Phase 4A examinations tests; run only in the native isolated test cluster.
-- Fixtures mirror the Main contracts the proposal depends on; they are not a replay.
create schema auth;
create schema private;
create role anon nologin;
create role authenticated nologin;
create function auth.uid() returns uuid language sql stable as
  $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth,public,private to authenticated,anon;
grant execute on function auth.uid() to authenticated;
create table auth.users (id uuid primary key);
insert into auth.users values
  ('00000000-0000-0000-0000-000000001001'),('00000000-0000-0000-0000-000000001002'),
  ('00000000-0000-0000-0000-000000001003'),('00000000-0000-0000-0000-000000001004'),
  ('00000000-0000-0000-0000-000000001005'),('00000000-0000-0000-0000-000000001006'),
  ('00000000-0000-0000-0000-000000001007'),('00000000-0000-0000-0000-000000001008'),
  ('00000000-0000-0000-0000-000000001009'),('00000000-0000-0000-0000-000000001010');

create table public.user_roles (user_id uuid not null, role text not null, primary key (user_id, role));
create table public.branches (id uuid primary key, name text not null);
create table public.academic_sessions (id uuid primary key, name text not null,
  starts_on date not null, ends_on date not null, is_active boolean not null default true);
create table public.branch_memberships (user_id uuid not null, branch_id uuid not null,
  is_active boolean not null default true, primary key (user_id, branch_id));
create table public.classes (id uuid primary key, branch_id uuid not null, session_id uuid not null,
  name text not null, teacher_id uuid);
create table public.students (id uuid primary key, user_id uuid, branch_id uuid not null,
  class_id uuid, admission_no text not null, full_name text not null,
  status text not null default 'active');
create table public.parent_student_links (parent_user_id uuid not null, student_id uuid not null,
  verified_at timestamptz, primary key (parent_user_id, student_id));
create table public.learning_courses (id uuid primary key, branch_id uuid not null,
  session_id uuid not null, class_id uuid not null, title text not null, teacher_id uuid);
create table public.audit_logs (id uuid primary key default gen_random_uuid(),
  actor_user_id uuid, action text not null, entity_type text not null,
  entity_id uuid, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now());

-- The proposal guard requires an RLS-enabled classes table, like Main.
alter table public.classes enable row level security;

-- Fixture copies of the security helpers the proposal builds on.
create function private.sai_security_has_role(wanted text)
returns boolean language sql stable security definer set search_path = pg_catalog, public, private as $$
  select exists (select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted);
$$;
create function private.sai_security_branch_member(wanted_branch uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public, private as $$
  select exists (select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid()) and m.branch_id = wanted_branch and m.is_active);
$$;
create function private.sai_security_can_read_class(wanted_class uuid)
returns boolean language sql stable security definer set search_path = pg_catalog, public, private as $$
  select exists (select 1 from public.classes c where c.id = wanted_class and (
    private.sai_security_has_role('super_admin')
    or (private.sai_security_has_role('admin') and private.sai_security_branch_member(c.branch_id))
    or (private.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid())
        and private.sai_security_branch_member(c.branch_id))
    or exists (select 1 from public.students s where s.class_id = c.id and (
      (private.sai_security_has_role('student') and s.user_id = (select auth.uid()))
      or (private.sai_security_has_role('parent') and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null)))))
  );
$$;
revoke all on function private.sai_security_has_role(text),
  private.sai_security_branch_member(uuid), private.sai_security_can_read_class(uuid) from public, anon;
grant execute on function private.sai_security_has_role(text),
  private.sai_security_branch_member(uuid), private.sai_security_can_read_class(uuid) to authenticated;

-- Identities
-- 1001 teacher-one (class one)   1002 teacher-two (class two)  1003 admin branch one
-- 1004 super_admin               1005 receptionist branch one  1006 student-one user
-- 1007 verified parent of one    1008 unverified parent        1009 student-two user
-- 1010 admin branch two only
insert into public.user_roles values
  ('00000000-0000-0000-0000-000000001001','teacher'),
  ('00000000-0000-0000-0000-000000001002','teacher'),
  ('00000000-0000-0000-0000-000000001003','admin'),
  ('00000000-0000-0000-0000-000000001004','super_admin'),
  ('00000000-0000-0000-0000-000000001005','receptionist'),
  ('00000000-0000-0000-0000-000000001006','student'),
  ('00000000-0000-0000-0000-000000001007','parent'),
  ('00000000-0000-0000-0000-000000001008','parent'),
  ('00000000-0000-0000-0000-000000001009','student'),
  ('00000000-0000-0000-0000-000000001010','admin');
insert into public.branches values
  ('00000000-0000-0000-0000-0000000000b1','Branch One'),
  ('00000000-0000-0000-0000-0000000000b2','Branch Two');
insert into public.academic_sessions values
  ('00000000-0000-0000-0000-000000000051','2026A','2026-01-01','2026-06-30',true);
insert into public.branch_memberships values
  ('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-0000000000b1',true),
  ('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-0000000000b1',true),
  ('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-0000000000b1',true),
  ('00000000-0000-0000-0000-000000001005','00000000-0000-0000-0000-0000000000b1',true),
  ('00000000-0000-0000-0000-000000001010','00000000-0000-0000-0000-0000000000b2',true);
insert into public.classes values
  ('00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051','Class One','00000000-0000-0000-0000-000000001001'),
  ('00000000-0000-0000-0000-0000000000c2','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051','Class Two','00000000-0000-0000-0000-000000001002');
insert into public.students values
  ('00000000-0000-0000-0000-0000000000e1','00000000-0000-0000-0000-000000001006','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000c1','A-1','Student One','active'),
  ('00000000-0000-0000-0000-0000000000e2','00000000-0000-0000-0000-000000001009','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000c1','A-2','Student Two','active'),
  ('00000000-0000-0000-0000-0000000000e3',null,'00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000c2','A-3','Student Three','active'),
  ('00000000-0000-0000-0000-0000000000e4',null,'00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000c1','A-4','Student Withdrawn','withdrawn');
insert into public.parent_student_links values
  ('00000000-0000-0000-0000-000000001007','00000000-0000-0000-0000-0000000000e1',now()),
  ('00000000-0000-0000-0000-000000001008','00000000-0000-0000-0000-0000000000e1',null);
insert into public.learning_courses values
  ('00000000-0000-0000-0000-0000000000d1','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051','00000000-0000-0000-0000-0000000000c1','Course One','00000000-0000-0000-0000-000000001001'),
  ('00000000-0000-0000-0000-0000000000d2','00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051','00000000-0000-0000-0000-0000000000c2','Course Two','00000000-0000-0000-0000-000000001002');

\ir ../deployment/phase4a-examinations/001_examinations.sql

create or replace function as_user(p_user uuid) returns void language sql as
  $$select set_config('request.jwt.claim.sub', p_user::text, false)$$;

set role authenticated;

-- ---------- Creation and scheduling ----------
select as_user('00000000-0000-0000-0000-000000001001');
insert into public.exams (branch_id, academic_session_id, class_id, course_id, subject, title,
    exam_date, start_time, end_time, room, max_score)
  values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051',
    '00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d1',
    'اللغة الصينية','اختبار منتصف الفصل','2026-03-15','09:00','11:00','قاعة 1',100);
do $$
declare v_exam uuid;
begin
  select id into v_exam from public.exams;
  if not exists (select 1 from public.exams where id = v_exam and status = 'draft'
      and created_by = '00000000-0000-0000-0000-000000001001' and published_at is null) then
    raise exception 'Exam not created as draft';
  end if;
  perform set_config('sai.exam', v_exam::text, false);
end $$;

do $$
declare v_exam uuid := current_setting('sai.exam')::uuid; v_count integer;
begin
  -- Invalid scheduling and content are rejected.
  begin
    insert into public.exams (branch_id, academic_session_id, class_id, subject, title, exam_date)
      values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051',
        '00000000-0000-0000-0000-0000000000c1','x','اختبار قصير المادة','2026-03-15');
    raise exception 'short subject accepted';
  exception when invalid_parameter_value then null; end;
  begin
    insert into public.exams (branch_id, academic_session_id, class_id, subject, title, exam_date)
      values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051',
        '00000000-0000-0000-0000-0000000000c1','اللغة الصينية','اختبار خارج الجلسة','2026-12-01');
    raise exception 'out-of-session date accepted';
  exception when check_violation then null; end;
  begin
    insert into public.exams (branch_id, academic_session_id, class_id, course_id, subject, title, exam_date)
      values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000051',
        '00000000-0000-0000-0000-0000000000c1','00000000-0000-0000-0000-0000000000d2',
        'اللغة الصينية','اختبار مقرر آخر','2026-03-15');
    raise exception 'foreign course accepted';
  exception when check_violation then null; end;
  -- Teachers cannot review or publish, and cannot skip states.
  begin
    update public.exams set status = 'published' where id = v_exam;
    raise exception 'teacher published';
  exception when insufficient_privilege then null; end;
  begin
    update public.exams set status = 'review' where id = v_exam;
    raise exception 'teacher reviewed';
  exception when insufficient_privilege then null; end;
  -- Another class teacher cannot see or manage this exam (RLS hides the row).
  perform as_user('00000000-0000-0000-0000-000000001002');
  update public.exams set title = 'استيلاء' where id = v_exam;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'foreign teacher updated'; end if;
  perform as_user('00000000-0000-0000-0000-000000001001');
  update public.exams set status = 'marks_entry' where id = v_exam;
end $$;

-- ---------- Marks entry and grade calculation ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid; v_count integer; v_band record;
begin
  insert into public.exam_results (exam_id, student_id, score, note) values
    (v_exam,'00000000-0000-0000-0000-0000000000e1',95,'ممتاز'),
    (v_exam,'00000000-0000-0000-0000-0000000000e2',40,null);
  if not exists (select 1 from public.exam_results where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e1' and grade = 'excellent'
      and entered_by = '00000000-0000-0000-0000-000000001001' and entered_at is not null) then
    raise exception 'grade not computed for 95';
  end if;
  if not exists (select 1 from public.exam_results where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e2' and grade = 'fail') then
    raise exception 'grade not computed for 40';
  end if;
  -- Grade band boundaries: exact and just-below thresholds.
  for v_band in select * from (values
      (90::numeric,'excellent'::text),(89.9,'very_good'),(80,'very_good'),(79.9,'good'),
      (70,'good'),(69.9,'acceptable'),(60,'acceptable'),(59.9,'weak'),
      (50,'weak'),(49.9,'fail'),(0,'fail')) as band(score, expected)
  loop
    update public.exam_results set score = v_band.score where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e2';
    if (select grade from public.exam_results where exam_id = v_exam
        and student_id = '00000000-0000-0000-0000-0000000000e2') is distinct from v_band.expected then
      raise exception 'grade band wrong for %: expected %', v_band.score, v_band.expected;
    end if;
  end loop;
  update public.exam_results set score = null where exam_id = v_exam
    and student_id = '00000000-0000-0000-0000-0000000000e2';
  if (select grade from public.exam_results where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e2') is not null then
    raise exception 'blank score kept a grade';
  end if;
  update public.exam_results set score = 40 where exam_id = v_exam
    and student_id = '00000000-0000-0000-0000-0000000000e2';
  -- Invalid scores and students are rejected.
  begin
    insert into public.exam_results (exam_id, student_id, score) values
      (v_exam,'00000000-0000-0000-0000-0000000000e3',50);
    raise exception 'foreign class student accepted';
  exception when check_violation then null; end;
  begin
    insert into public.exam_results (exam_id, student_id, score) values
      (v_exam,'00000000-0000-0000-0000-0000000000e4',50);
    raise exception 'withdrawn student accepted';
  exception when check_violation then null; end;
  begin
    update public.exam_results set score = 101 where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e1';
    raise exception 'over-max score accepted';
  exception when invalid_parameter_value then null; end;
  begin
    update public.exam_results set score = -1 where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e1';
    raise exception 'negative score accepted';
  exception when invalid_parameter_value then null; end;
end $$;

-- ---------- Pre-publication invisibility ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid; v_count integer;
begin
  perform as_user('00000000-0000-0000-0000-000000001006'); -- student one
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 0 then raise exception 'student saw unpublished results'; end if;
  perform as_user('00000000-0000-0000-0000-000000001007'); -- verified parent
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 0 then raise exception 'parent saw unpublished results'; end if;
  select count(*) into v_count from public.exams where id = v_exam;
  if v_count <> 0 then raise exception 'family saw unpublished exam'; end if;
end $$;

-- ---------- Review and publication (administration only) ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid;
begin
  perform as_user('00000000-0000-0000-0000-000000001003'); -- admin branch one
  update public.exams set status = 'review' where id = v_exam;
  -- Marks are locked during review.
  begin
    update public.exam_results set score = 50 where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e1';
    raise exception 'marks editable during review';
  exception when check_violation then null; end;
  -- Send back for correction, then publish.
  update public.exams set status = 'marks_entry' where id = v_exam;
  update public.exams set status = 'review' where id = v_exam;
  update public.exams set status = 'published' where id = v_exam;
  if not exists (select 1 from public.exams where id = v_exam and published_at is not null) then
    raise exception 'published_at not recorded';
  end if;
  -- Published exams are read-only (except reopening to review).
  begin
    update public.exams set title = 'تعديل بعد النشر' where id = v_exam;
    raise exception 'published exam edited';
  exception when check_violation then null; end;
end $$;

-- ---------- Student, parent, receptionist and cross-branch reads ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid; v_count integer;
begin
  perform as_user('00000000-0000-0000-0000-000000001006'); -- student one
  select count(*) into v_count from public.exam_results where exam_id = v_exam
    and student_id = '00000000-0000-0000-0000-0000000000e1' and grade = 'excellent';
  if v_count <> 1 then raise exception 'student cannot read own published result'; end if;
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 1 then raise exception 'student saw classmates results'; end if;
  update public.exam_results set score = 100 where exam_id = v_exam;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'student wrote a mark'; end if;
  if (select score from public.exam_results where exam_id = v_exam
      and student_id = '00000000-0000-0000-0000-0000000000e1') <> 95 then
    raise exception 'student mark was changed';
  end if;

  perform as_user('00000000-0000-0000-0000-000000001007'); -- verified parent
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 1 then raise exception 'verified parent read wrong rows'; end if;

  perform as_user('00000000-0000-0000-0000-000000001008'); -- unverified parent
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 0 then raise exception 'unverified parent read results'; end if;

  perform as_user('00000000-0000-0000-0000-000000001005'); -- receptionist
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 2 then raise exception 'receptionist cannot review results'; end if;
  begin
    insert into public.exam_results (exam_id, student_id, score) values
      (v_exam,'00000000-0000-0000-0000-0000000000e2',10);
    raise exception 'receptionist wrote a mark';
  exception when insufficient_privilege then null; end;

  perform as_user('00000000-0000-0000-0000-000000001010'); -- admin of branch two only
  select count(*) into v_count from public.exams where id = v_exam;
  if v_count <> 0 then raise exception 'cross-branch admin read the exam'; end if;
  update public.exams set status = 'review' where id = v_exam;
  get diagnostics v_count = row_count;
  if v_count <> 0 then raise exception 'cross-branch admin updated'; end if;

  -- Super admin sees and manages everything.
  perform as_user('00000000-0000-0000-0000-000000001004');
  select count(*) into v_count from public.exam_results where exam_id = v_exam;
  if v_count <> 2 then raise exception 'super admin read wrong rows'; end if;
end $$;

-- ---------- Roster RPC ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid; v_count integer;
begin
  perform as_user('00000000-0000-0000-0000-000000001001'); -- class teacher
  select count(*) into v_count from public.sai_exam_roster(v_exam);
  if v_count <> 2 then raise exception 'roster should list the two active class students, got %', v_count; end if;
  perform as_user('00000000-0000-0000-0000-000000001006'); -- student cannot call roster
  begin
    perform count(*) from public.sai_exam_roster(v_exam);
    raise exception 'student called roster';
  exception when insufficient_privilege then null; end;
end $$;

reset role;
set role anon;
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid;
begin
  begin
    perform count(*) from public.exams where id = v_exam;
    raise exception 'anon read exams';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- ---------- Audit coverage ----------
do $$
declare v_exam uuid := current_setting('sai.exam')::uuid;
begin
  if not exists (select 1 from public.audit_logs where entity_type = 'exams'
      and entity_id = v_exam and action = 'status:published') then
    raise exception 'publication not audited';
  end if;
  if not exists (select 1 from public.audit_logs where entity_type = 'exam_results'
      and action = 'mark') then
    raise exception 'marks not audited';
  end if;
end $$;

select 'PASS: examinations creation, scheduling, marks, grades, review/publish states, family access, roster and audit';
