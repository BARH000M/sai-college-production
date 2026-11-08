-- Learning portal foundation: courses, lessons, progress, homework and submissions.
-- Applied to the live project; kept here for reproducibility.

create or replace function public.sai_admissions_sessions(wanted_branch uuid)
returns table (id uuid, name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if wanted_branch is null
    or not exists (select 1 from public.branches b where b.id = wanted_branch) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(wanted_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query
    select s.id, s.name
    from public.academic_sessions s
    where s.is_active
    order by s.name, s.id;
end;
$$;
grant execute on function public.sai_admissions_sessions(uuid) to authenticated;

create table if not exists public.learning_courses (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id) on delete cascade,
  session_id uuid not null references public.academic_sessions(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete cascade,
  title text not null,
  description text,
  level text,
  teacher_id uuid references public.profiles(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.learning_lessons (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.learning_courses(id) on delete cascade,
  title text not null,
  summary text,
  kind text not null default 'lesson' check (kind in ('lesson','listening','speaking','vocabulary','reading','review')),
  position integer not null default 1,
  duration_minutes integer not null default 45,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.learning_lesson_progress (
  lesson_id uuid not null references public.learning_lessons(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status text not null default 'not_started' check (status in ('not_started','in_progress','completed')),
  updated_at timestamptz not null default now(),
  primary key (lesson_id, student_id)
);

create table if not exists public.learning_homework (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.learning_courses(id) on delete cascade,
  title text not null,
  instructions text,
  due_at timestamptz not null,
  max_score integer not null default 100,
  position integer not null default 1,
  is_published boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.learning_homework_submissions (
  id uuid primary key default gen_random_uuid(),
  homework_id uuid not null references public.learning_homework(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  status text not null default 'submitted' check (status in ('submitted','graded','returned')),
  content text,
  submitted_at timestamptz not null default now(),
  score integer,
  feedback text,
  graded_at timestamptz,
  graded_by uuid references public.profiles(id) on delete set null,
  unique (homework_id, student_id)
);

create index if not exists learning_courses_class_idx on public.learning_courses(class_id);
create index if not exists learning_lessons_course_idx on public.learning_lessons(course_id, position);
create index if not exists learning_homework_course_idx on public.learning_homework(course_id, position);
create index if not exists learning_progress_student_idx on public.learning_lesson_progress(student_id);
create index if not exists learning_submissions_student_idx on public.learning_homework_submissions(student_id);

create or replace function public.sai_learning_can_read_course(wanted_course uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course and public.sai_security_can_read_class(c.class_id)
  );
$$;

create or replace function public.sai_learning_can_manage_course(wanted_course uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course
      and (
        public.sai_security_has_role('super_admin')
        or (public.sai_security_has_role('admin') and public.sai_security_branch_member(c.branch_id))
        or (
          public.sai_security_has_role('teacher')
          and public.sai_security_branch_member(c.branch_id)
          and (
            c.teacher_id = (select auth.uid())
            or exists (
              select 1 from public.classes cl
              where cl.id = c.class_id and cl.teacher_id = (select auth.uid())
            )
          )
        )
      )
  );
$$;

create or replace function public.sai_learning_can_read_homework(wanted_homework uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.learning_homework h
    join public.learning_courses c on c.id = h.course_id
    where h.id = wanted_homework
      and (h.is_published or public.sai_learning_can_manage_course(c.id))
      and public.sai_security_can_read_class(c.class_id)
  );
$$;

create or replace function public.sai_learning_can_grade_homework(wanted_homework uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.learning_homework h
    where h.id = wanted_homework and public.sai_learning_can_manage_course(h.course_id)
  );
$$;

create or replace function public.sai_learning_own_student(wanted_student uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.students s
    where s.id = wanted_student and s.user_id = (select auth.uid())
  );
$$;

alter table public.learning_courses enable row level security;
alter table public.learning_lessons enable row level security;
alter table public.learning_lesson_progress enable row level security;
alter table public.learning_homework enable row level security;
alter table public.learning_homework_submissions enable row level security;

drop policy if exists learning_courses_select on public.learning_courses;
create policy learning_courses_select on public.learning_courses
  for select to authenticated using (public.sai_security_can_read_class(class_id));

drop policy if exists learning_courses_write on public.learning_courses;
create policy learning_courses_write on public.learning_courses
  for all to authenticated
  using (
    public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))
    or (
      public.sai_security_has_role('teacher')
      and public.sai_security_branch_member(branch_id)
      and (
        teacher_id = (select auth.uid())
        or exists (select 1 from public.classes cl where cl.id = class_id and cl.teacher_id = (select auth.uid()))
      )
    )
  )
  with check (
    public.sai_security_has_role('super_admin')
    or (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id))
    or (
      public.sai_security_has_role('teacher')
      and public.sai_security_branch_member(branch_id)
      and (
        teacher_id = (select auth.uid())
        or exists (select 1 from public.classes cl where cl.id = class_id and cl.teacher_id = (select auth.uid()))
      )
    )
  );

drop policy if exists learning_lessons_select on public.learning_lessons;
create policy learning_lessons_select on public.learning_lessons
  for select to authenticated
  using (is_published or public.sai_learning_can_manage_course(course_id));

drop policy if exists learning_lessons_write on public.learning_lessons;
create policy learning_lessons_write on public.learning_lessons
  for all to authenticated
  using (public.sai_learning_can_manage_course(course_id))
  with check (public.sai_learning_can_manage_course(course_id));

drop policy if exists learning_homework_select on public.learning_homework;
create policy learning_homework_select on public.learning_homework
  for select to authenticated
  using (public.sai_learning_can_read_homework(id));

drop policy if exists learning_homework_write on public.learning_homework;
create policy learning_homework_write on public.learning_homework
  for all to authenticated
  using (public.sai_learning_can_manage_course(course_id))
  with check (public.sai_learning_can_manage_course(course_id));

drop policy if exists learning_progress_select on public.learning_lesson_progress;
create policy learning_progress_select on public.learning_lesson_progress
  for select to authenticated using (public.sai_security_can_read_student(student_id));

drop policy if exists learning_progress_write on public.learning_lesson_progress;
create policy learning_progress_write on public.learning_lesson_progress
  for all to authenticated
  using (public.sai_learning_own_student(student_id))
  with check (public.sai_learning_own_student(student_id));

drop policy if exists learning_submissions_select on public.learning_homework_submissions;
create policy learning_submissions_select on public.learning_homework_submissions
  for select to authenticated
  using (
    public.sai_security_can_read_student(student_id)
    and public.sai_learning_can_read_homework(homework_id)
  );

drop policy if exists learning_submissions_student_insert on public.learning_homework_submissions;
create policy learning_submissions_student_insert on public.learning_homework_submissions
  for insert to authenticated
  with check (
    public.sai_learning_own_student(student_id)
    and public.sai_learning_can_read_homework(homework_id)
    and status = 'submitted'
  );

drop policy if exists learning_submissions_student_update on public.learning_homework_submissions;
create policy learning_submissions_student_update on public.learning_homework_submissions
  for update to authenticated
  using (public.sai_learning_own_student(student_id) and status = 'submitted')
  with check (public.sai_learning_own_student(student_id) and status = 'submitted');

drop policy if exists learning_submissions_staff_update on public.learning_homework_submissions;
create policy learning_submissions_staff_update on public.learning_homework_submissions
  for update to authenticated
  using (public.sai_learning_can_grade_homework(homework_id))
  with check (public.sai_learning_can_grade_homework(homework_id));

grant select, insert, update, delete on public.learning_courses to authenticated;
grant select, insert, update, delete on public.learning_lessons to authenticated;
grant select, insert, update, delete on public.learning_lesson_progress to authenticated;
grant select, insert, update, delete on public.learning_homework to authenticated;
grant select, insert, update, delete on public.learning_homework_submissions to authenticated;