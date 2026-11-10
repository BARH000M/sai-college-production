-- 025 — Normalise private helper search_path and repoint internal calls
--
-- Applied live on the primary project; this file records it for reproducibility.
--
-- Two changes, zero behaviour change:
--   1. Every private.sai_* helper now pins search_path = 'pg_catalog, public, private'
--      (previously several pinned only 'public', which is inconsistent and relies
--      on implicit resolution order).
--   2. Every internal helper-to-helper call is now schema-qualified as private.*
--      instead of public.*. Previously a single RLS row check could pass through
--      the public wrapper layer — up to three nested SECURITY DEFINER calls that
--      could not be inlined. The chain now goes straight to the implementation.
--
-- Table references were already schema-qualified and remain unchanged.
-- Argument names, return types, volatility and SECURITY DEFINER are preserved.

create or replace function private.sai_security_has_role(wanted_role app_role)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$function$;

create or replace function private.sai_security_branch_member(wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$function$;

create or replace function private.sai_security_can_read_branch(wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_security_has_role('super_admin')
    or (
      private.sai_security_branch_member(wanted_branch)
      and exists (
        select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and r.role in (
            'admin', 'teacher', 'accountant', 'receptionist',
            'librarian', 'content_editor'
          )
      )
    )
    or exists (
      select 1 from public.students s
      where s.branch_id = wanted_branch
        and (
          (private.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            private.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$function$;

create or replace function private.sai_security_can_read_class(wanted_class uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(c.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and private.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (private.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                private.sai_security_has_role('parent')
                and exists (
                  select 1 from public.parent_student_links l
                  where l.student_id = s.id
                    and l.parent_user_id = (select auth.uid())
                    and l.verified_at is not null
                )
              )
            )
        )
      )
  );
$function$;

create or replace function private.sai_security_can_read_session(wanted_session uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and private.sai_security_can_read_class(c.id)
    );
$function$;

create or replace function private.sai_security_can_read_student(wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(s.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          private.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          private.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$function$;

create or replace function private.sai_learning_can_manage_course(wanted_course uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course
      and (
        private.sai_security_has_role('super_admin')
        or (private.sai_security_has_role('admin') and private.sai_security_branch_member(c.branch_id))
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(c.branch_id)
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
$function$;

create or replace function private.sai_learning_can_read_course(wanted_course uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course and private.sai_security_can_read_class(c.class_id)
  );
$function$;

create or replace function private.sai_learning_can_read_homework(wanted_homework uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_homework h
    join public.learning_courses c on c.id = h.course_id
    where h.id = wanted_homework
      and (h.is_published or private.sai_learning_can_manage_course(c.id))
      and private.sai_security_can_read_class(c.class_id)
  );
$function$;

create or replace function private.sai_learning_can_grade_homework(wanted_homework uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_homework h
    where h.id = wanted_homework and private.sai_learning_can_manage_course(h.course_id)
  );
$function$;

create or replace function private.sai_learning_own_student(wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.students s
    where s.id = wanted_student and s.user_id = (select auth.uid())
  );
$function$;

create or replace function private.sai_attendance_manage_class(wanted_class uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.classes c where c.id = wanted_class and (
      private.sai_security_has_role('super_admin')
      or (private.sai_security_branch_member(c.branch_id) and (
        private.sai_security_has_role('admin')
        or (private.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid()))
      ))
    )
  );
$function$;

create or replace function private.sai_attendance_view_record(wanted_session uuid, wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.attendance_sessions a
    join public.students s on s.id = wanted_student
    where a.id = wanted_session and (
      private.sai_attendance_manage_class(a.class_id)
      or (private.sai_security_has_role('receptionist') and private.sai_security_branch_member(a.branch_id))
      or (private.sai_security_has_role('student') and s.user_id = (select auth.uid()))
      or (private.sai_security_has_role('parent') and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
      ))
    )
  );
$function$;

create or replace function private.sai_attendance_view_session(wanted_session uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.attendance_sessions a where a.id = wanted_session and (
      private.sai_attendance_manage_class(a.class_id)
      or (private.sai_security_has_role('receptionist') and private.sai_security_branch_member(a.branch_id))
      or exists (select 1 from public.attendance_records r
        where r.attendance_session_id = a.id and private.sai_attendance_view_record(a.id, r.student_id))
    )
  );
$function$;

-- Verification: both counts must be 0.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'private' and p.prokind = 'f' and p.proname like 'sai\_%' escape '\'
       and not ('search_path=pg_catalog, public, private' = any(coalesce(p.proconfig, array[]::text[])))) as wrong_search_path,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'private' and p.prokind = 'f' and p.proname like 'sai\_%' escape '\'
       and p.prosrc ~* 'public\.sai_(security|learning)_') as still_calling_public;