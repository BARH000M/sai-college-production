-- PROPOSAL ONLY: additive Main-compatible examinations schema; do not replay migrations.
-- Phase 4A: examination scheduling, marks entry, grade calculation and result
-- publication. Reuses branches, academic_sessions, classes, students,
-- parent_student_links, learning_courses and the private security helpers.
-- Existing RLS and column grants on those tables remain authoritative.
begin;

do $$
begin
  if not exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='classes' and c.relrowsecurity) then
    raise exception 'Expected Main classes table with RLS enabled';
  end if;
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='private' and p.proname='sai_security_has_role') then
    raise exception 'Expected private security helper layer; review before installing';
  end if;
  if exists (select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='exams') then
    raise exception 'public.exams already exists; do not replay this proposal';
  end if;
end $$;

-- ============================================================================
-- Tables
-- ============================================================================
create table public.exams (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  class_id uuid not null references public.classes(id),
  course_id uuid references public.learning_courses(id) on delete set null,
  subject text not null,
  title text not null,
  exam_date date not null,
  start_time time,
  end_time time,
  room text,
  max_score numeric(6,2) not null default 100 check (max_score > 0 and max_score <= 1000),
  status text not null default 'draft'
    check (status in ('draft','marks_entry','review','published','cancelled')),
  created_by uuid not null default auth.uid() references auth.users(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time is null or end_time is null or end_time > start_time)
);

create table public.exam_results (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.exams(id) on delete cascade,
  student_id uuid not null references public.students(id),
  score numeric(6,2),
  grade text,
  note text,
  entered_by uuid references auth.users(id),
  entered_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (exam_id, student_id)
);

create index exams_scope_idx on public.exams(branch_id, academic_session_id, exam_date desc);
create index exams_class_idx on public.exams(class_id, status);
create index exam_results_exam_idx on public.exam_results(exam_id);
create index exam_results_student_idx on public.exam_results(student_id);

alter table public.exams enable row level security;
alter table public.exam_results enable row level security;

revoke all on public.exams, public.exam_results from public, anon, authenticated;
grant select on public.exams, public.exam_results to authenticated;
grant insert (branch_id, academic_session_id, class_id, course_id, subject, title,
  exam_date, start_time, end_time, room, max_score) on public.exams to authenticated;
grant update (subject, title, exam_date, start_time, end_time, room, max_score, status)
  on public.exams to authenticated;
grant insert (exam_id, student_id, score, note) on public.exam_results to authenticated;
grant update (score, note) on public.exam_results to authenticated;

-- ============================================================================
-- Private helpers (logic lives only in the private schema, like 022/025)
-- ============================================================================
create or replace function private.sai_exams_manage_class(wanted_class uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.classes c where c.id = wanted_class and (
      private.sai_security_has_role('super_admin')
      or (private.sai_security_branch_member(c.branch_id) and (
        private.sai_security_has_role('admin')
        or (private.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid()))
      ))
    )
  );
$$;

create or replace function private.sai_exams_manage_exam(wanted_exam uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.exams e
    where e.id = wanted_exam and private.sai_exams_manage_class(e.class_id)
  );
$$;

-- Staff visibility for scheduling/review without marks authority.
create or replace function private.sai_exams_staff_view(wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select private.sai_security_branch_member(wanted_branch)
    and private.sai_security_has_role('receptionist');
$$;

-- Students and verified parents see an exam once its results are published.
create or replace function private.sai_exams_family_view(wanted_exam uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select exists (
    select 1 from public.exams e
    join public.students s on s.class_id = e.class_id and s.branch_id = e.branch_id
    where e.id = wanted_exam and e.status = 'published'
      and (
        (private.sai_security_has_role('student') and s.user_id = (select auth.uid()))
        or (private.sai_security_has_role('parent') and exists (
          select 1 from public.parent_student_links l
          where l.student_id = s.id and l.parent_user_id = (select auth.uid())
            and l.verified_at is not null
        ))
      )
  );
$$;

create or replace function private.sai_exams_can_read_exam(wanted_exam uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select private.sai_exams_manage_exam(wanted_exam)
    or exists (select 1 from public.exams e where e.id = wanted_exam
      and (private.sai_exams_staff_view(e.branch_id)))
    or private.sai_exams_family_view(wanted_exam);
$$;

create or replace function private.sai_exams_can_read_result(wanted_exam uuid, wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $$
  select private.sai_exams_manage_exam(wanted_exam)
    or exists (select 1 from public.exams e where e.id = wanted_exam
      and private.sai_exams_staff_view(e.branch_id))
    or exists (
      select 1 from public.exams e join public.students s on s.id = wanted_student
      where e.id = wanted_exam and e.status = 'published'
        and s.class_id = e.class_id and s.branch_id = e.branch_id
        and (
          (private.sai_security_has_role('student') and s.user_id = (select auth.uid()))
          or (private.sai_security_has_role('parent') and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          ))
        )
    );
$$;

-- Grade bands used by both applications and print sheets; codes stay English,
-- clients map them to Arabic labels.
create or replace function private.sai_exam_grade(p_score numeric, p_max numeric)
returns text language sql immutable set search_path = pg_catalog
as $$
  select case
    when p_score is null or p_max is null or p_max <= 0 then null
    when p_score / p_max >= 0.9 then 'excellent'
    when p_score / p_max >= 0.8 then 'very_good'
    when p_score / p_max >= 0.7 then 'good'
    when p_score / p_max >= 0.6 then 'acceptable'
    when p_score / p_max >= 0.5 then 'weak'
    else 'fail'
  end;
$$;

revoke all on function private.sai_exams_manage_class(uuid), private.sai_exams_manage_exam(uuid),
  private.sai_exams_staff_view(uuid), private.sai_exams_family_view(uuid),
  private.sai_exams_can_read_exam(uuid), private.sai_exams_can_read_result(uuid, uuid),
  private.sai_exam_grade(numeric, numeric) from public, anon;
grant execute on function private.sai_exams_manage_class(uuid), private.sai_exams_manage_exam(uuid),
  private.sai_exams_staff_view(uuid), private.sai_exams_family_view(uuid),
  private.sai_exams_can_read_exam(uuid), private.sai_exams_can_read_result(uuid, uuid),
  private.sai_exam_grade(numeric, numeric) to authenticated;

-- ============================================================================
-- Row-level security
-- ============================================================================
create policy exams_select on public.exams for select to authenticated
  using (private.sai_exams_can_read_exam(id));
create policy exams_insert on public.exams for insert to authenticated
  with check (private.sai_exams_manage_class(class_id) and created_by = (select auth.uid()));
create policy exams_update on public.exams for update to authenticated
  using (private.sai_exams_manage_exam(id))
  with check (private.sai_exams_manage_exam(id));

create policy exam_results_select on public.exam_results for select to authenticated
  using (private.sai_exams_can_read_result(exam_id, student_id));
create policy exam_results_insert on public.exam_results for insert to authenticated
  with check (private.sai_exams_manage_exam(exam_id));
create policy exam_results_update on public.exam_results for update to authenticated
  using (private.sai_exams_manage_exam(exam_id))
  with check (private.sai_exams_manage_exam(exam_id));

-- ============================================================================
-- Validation, state machine and grade triggers
-- ============================================================================
create or replace function private.sai_exams_prepare()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then
      raise exception 'New exams start as draft' using errcode = '23514';
    end if;
    if not private.sai_exams_manage_class(new.class_id) then
      raise exception 'Not authorized for this class' using errcode = '42501';
    end if;
  end if;
  if tg_op = 'UPDATE' and not private.sai_exams_manage_exam(old.id) then
    raise exception 'Not authorized for this exam' using errcode = '42501';
  end if;
  new.subject := btrim(new.subject);
  new.title := btrim(new.title);
  new.room := nullif(btrim(coalesce(new.room, '')), '');
  if char_length(new.title) not between 2 and 160 or new.title ~ '[[:cntrl:]]' then
    raise exception 'Invalid exam title' using errcode = '22023';
  end if;
  if char_length(new.subject) not between 2 and 120 or new.subject ~ '[[:cntrl:]]' then
    raise exception 'Invalid exam subject' using errcode = '22023';
  end if;
  if new.room is not null and (char_length(new.room) > 60 or new.room ~ '[[:cntrl:]]') then
    raise exception 'Invalid exam room' using errcode = '22023';
  end if;
  if not exists (select 1 from public.classes c
      where c.id = new.class_id and c.branch_id = new.branch_id
        and c.session_id = new.academic_session_id) then
    raise exception 'Class, branch and academic session do not match' using errcode = '23514';
  end if;
  if new.course_id is not null and not exists (select 1 from public.learning_courses lc
      where lc.id = new.course_id and lc.class_id = new.class_id and lc.branch_id = new.branch_id) then
    raise exception 'Course does not belong to this class' using errcode = '23514';
  end if;
  if not exists (select 1 from public.academic_sessions s
      where s.id = new.academic_session_id
        and new.exam_date between s.starts_on and s.ends_on) then
    raise exception 'Exam date is outside the academic session' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if not (private.sai_security_has_role('super_admin') or private.sai_security_has_role('admin'))
        and new.status in ('review', 'published') then
      raise exception 'Only academic administration can review or publish results' using errcode = '42501';
    end if;
    if not ((old.status = 'draft' and new.status in ('marks_entry', 'cancelled'))
        or (old.status = 'marks_entry' and new.status in ('review', 'cancelled'))
        or (old.status = 'review' and new.status in ('marks_entry', 'published'))
        or (old.status = 'published' and new.status = 'review')) then
      raise exception 'Unsupported exam status change' using errcode = '23514';
    end if;
    if new.status = 'published' then
      new.published_at := now();
    end if;
  end if;
  if tg_op = 'UPDATE' and old.status = 'published' and new.status = 'published' then
    raise exception 'Published exams are read-only' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger sai_exams_prepare before insert or update on public.exams
  for each row execute function private.sai_exams_prepare();

create or replace function private.sai_exam_results_prepare()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare exam_row public.exams%rowtype;
begin
  select * into exam_row from public.exams e where e.id = new.exam_id for update;
  if not found then
    raise exception 'Exam not found' using errcode = '23503';
  end if;
  if not private.sai_exams_manage_exam(new.exam_id) then
    raise exception 'Not authorized for this exam' using errcode = '42501';
  end if;
  if exam_row.status <> 'marks_entry' then
    raise exception 'Marks are only editable while the exam is open for marks entry' using errcode = '23514';
  end if;
  if not exists (select 1 from public.students s where s.id = new.student_id
      and s.class_id = exam_row.class_id and s.branch_id = exam_row.branch_id
      and s.status = 'active') then
    raise exception 'Student does not belong to this exam class' using errcode = '23514';
  end if;
  if new.score is not null and (new.score < 0 or new.score > exam_row.max_score) then
    raise exception 'Score must be between zero and the exam maximum' using errcode = '22023';
  end if;
  new.note := nullif(btrim(coalesce(new.note, '')), '');
  if new.note is not null and (char_length(new.note) > 240 or new.note ~ '[[:cntrl:]]') then
    raise exception 'Invalid result note' using errcode = '22023';
  end if;
  new.grade := private.sai_exam_grade(new.score, exam_row.max_score);
  new.entered_by := (select auth.uid());
  new.entered_at := now();
  new.updated_at := now();
  return new;
end $$;

create trigger sai_exam_results_prepare before insert or update on public.exam_results
  for each row execute function private.sai_exam_results_prepare();

create or replace function private.sai_exams_audit()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, private
as $$
declare audit_action text;
begin
  if tg_table_name = 'exams' then
    if tg_op = 'INSERT' then audit_action := 'create';
    elsif new.status is distinct from old.status then audit_action := 'status:' || new.status;
    else audit_action := 'update'; end if;
  elsif tg_op = 'INSERT' then audit_action := 'mark';
  else audit_action := 'correct'; end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
    values ((select auth.uid()), audit_action, tg_table_name, new.id,
      jsonb_build_object('source', 'sai_exams_trigger'));
  return new;
end $$;

create trigger sai_exams_audit after insert or update on public.exams
  for each row execute function private.sai_exams_audit();
create trigger sai_exam_results_audit after insert or update on public.exam_results
  for each row execute function private.sai_exams_audit();
revoke all on function private.sai_exams_prepare(), private.sai_exam_results_prepare(),
  private.sai_exams_audit() from public, anon, authenticated;

-- ============================================================================
-- Minimal directory and roster RPCs (mirrors the attendance contract)
-- ============================================================================
create or replace function public.sai_exams_classes()
returns table (id uuid, name text, branch_id uuid, academic_session_id uuid, teacher_id uuid)
language sql stable security definer set search_path = pg_catalog, public, private
as $$
  select c.id, c.name, c.branch_id, c.session_id, c.teacher_id
  from public.classes c
  where private.sai_exams_manage_class(c.id)
     or private.sai_exams_staff_view(c.branch_id)
     or private.sai_security_can_read_class(c.id)
  order by c.name, c.id;
$$;
revoke all on function public.sai_exams_classes() from public, anon;
grant execute on function public.sai_exams_classes() to authenticated;

-- Marks-entry roster: class students with any saved result, managers only.
create or replace function public.sai_exam_roster(wanted_exam uuid)
returns table (student_id uuid, full_name text, admission_no text,
  result_id uuid, score numeric, grade text, note text)
language plpgsql stable security definer set search_path = pg_catalog, public, private
as $$
declare exam_row public.exams%rowtype;
begin
  select * into exam_row from public.exams e where e.id = wanted_exam;
  if not found then
    raise exception 'Exam not found' using errcode = '42501';
  end if;
  if not (private.sai_exams_manage_exam(wanted_exam)
      or private.sai_exams_staff_view(exam_row.branch_id)) then
    raise exception 'Not authorized for this roster' using errcode = '42501';
  end if;
  return query
    select s.id, s.full_name, s.admission_no, r.id, r.score, r.grade, r.note
    from public.students s
    left join public.exam_results r
      on r.student_id = s.id and r.exam_id = wanted_exam
    where s.class_id = exam_row.class_id and s.branch_id = exam_row.branch_id
      and s.status = 'active'
    order by s.full_name, s.id;
end $$;
revoke all on function public.sai_exam_roster(uuid) from public, anon;
grant execute on function public.sai_exam_roster(uuid) to authenticated;

commit;
