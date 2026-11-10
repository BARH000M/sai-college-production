-- 022_consolidate_security_helpers.sql
--
-- Purpose
--   Eliminate the duplicated private/public security-helper implementations that
--   caused ten RLS policies to resolve to SECURITY INVOKER twins in the `public`
--   schema, and that left eighteen PL/pgSQL functions depending on whichever copy
--   the search_path happened to reach.
--
-- What actually exists (verified live against the primary project)
--   private.sai_security_*   SECURITY DEFINER  <- the real implementations
--   private.sai_learning_*   SECURITY DEFINER  <- the real implementations
--   public.sai_security_*    SECURITY INVOKER  <- duplicates, no search_path pin
--   public.sai_learning_*    SECURITY INVOKER  <- duplicates, no search_path pin
--
-- Three distinct problems, and why each is handled the way it is:
--
--   1. Ten policies called the helpers UNQUALIFIED, so they bound to the public
--      INVOKER twins instead of the private DEFINER implementations.
--      -> Fixed by re-pointing each policy at the private helper explicitly.
--
--   2. Eighteen functions call the helpers unqualified, and eleven of them pin
--      `search_path = public` (or `pg_catalog, public`) with `private` absent or
--      ordered after `public`. They therefore also bind to the public twins.
--      -> Dropping the public twins is NOT safe: it would break admissions,
--         attendance, directory, role and finance RPCs at runtime. Instead the
--         public twins are reduced to thin SECURITY DEFINER delegating wrappers,
--         so every caller keeps working against a single implementation.
--
--   3. The two copies could silently drift, because both carried real bodies.
--      -> Now the private schema is the only place logic lives. The public
--         functions contain no logic at all, so drift is impossible.
--
-- Post-condition
--   No behavioural change is intended. Every predicate and every helper result is
--   identical before and after; only the resolution path and the duplication are
--   removed.
--
-- This migration is idempotent and safe to re-run.

begin;

-- ============================================================================
-- 1. Re-point the ten policies from public (invoker) to private (definer).
--    Predicates are reproduced exactly; only the schema prefix changes.
-- ============================================================================

alter policy announcements_read on public.announcements
  using (
    (exists ( select 1
       from user_roles r
      where ((r.user_id = (select auth.uid()))
         and ((r.role = 'super_admin'::app_role)
           or ((r.role = any (array['admin'::app_role, 'content_editor'::app_role]))
               and private.sai_security_branch_member(announcements.branch_id))))))
    or (
      is_published
      and ((expires_at is null) or (expires_at > now()))
      and ((branch_id is null)
        or private.sai_security_branch_member(branch_id)
        or (exists ( select 1 from user_roles r
                      where ((r.user_id = (select auth.uid())) and (r.role = 'super_admin'::app_role)))))
      and ((audience = 'all'::text)
        or (exists ( select 1 from user_roles r
                      where ((r.user_id = (select auth.uid()))
                        and (((announcements.audience = 'staff'::text)
                              and (r.role = any (array['super_admin'::app_role, 'admin'::app_role, 'teacher'::app_role, 'accountant'::app_role, 'receptionist'::app_role, 'librarian'::app_role, 'content_editor'::app_role])))
                          or ((announcements.audience = 'teachers'::text) and (r.role = 'teacher'::app_role))
                          or ((announcements.audience = 'parents'::text) and (r.role = 'parent'::app_role))
                          or ((announcements.audience = 'students'::text) and (r.role = 'student'::app_role))))))))
  );

alter policy announcements_write on public.announcements
  with check ((exists ( select 1
   from user_roles r
  where ((r.user_id = (select auth.uid())) and ((r.role = 'super_admin'::app_role) or ((r.role = any (array['admin'::app_role, 'content_editor'::app_role])) and ((announcements.branch_id is null) or private.sai_security_branch_member(announcements.branch_id))))))));

alter policy announcement_deliveries_read on public.announcement_deliveries
  using (
    exists ( select 1
       from announcements a
      where ((a.id = announcement_deliveries.announcement_id)
         and (exists ( select 1
                 from user_roles r
                where ((r.user_id = (select auth.uid()))
                   and ((r.role = 'super_admin'::app_role)
                     or ((r.role = any (array['admin'::app_role, 'content_editor'::app_role]))
                         and ((a.branch_id is null) or private.sai_security_branch_member(a.branch_id)))))))))
  );

alter policy library_items_write on public.library_items
  using ((exists ( select 1
   from user_roles r
  where ((r.user_id = (select auth.uid())) and ((r.role = 'super_admin'::app_role) or ((r.role = any (array['admin'::app_role, 'librarian'::app_role])) and private.sai_security_branch_member(library_items.branch_id)))))))
  with check ((exists ( select 1
   from user_roles r
  where ((r.user_id = (select auth.uid())) and ((r.role = 'super_admin'::app_role) or ((r.role = any (array['admin'::app_role, 'librarian'::app_role])) and private.sai_security_branch_member(library_items.branch_id)))))));

alter policy library_loans_read on public.library_loans
  using (
    (exists ( select 1 from user_roles r
               where ((r.user_id = (select auth.uid()))
                 and ((r.role = 'super_admin'::app_role)
                   or ((r.role = any (array['admin'::app_role, 'librarian'::app_role, 'receptionist'::app_role, 'teacher'::app_role]))
                       and private.sai_security_branch_member(library_loans.branch_id))))))
    or (exists ( select 1 from students s
                  where ((s.id = library_loans.student_id) and (s.user_id = (select auth.uid())))))
    or (exists ( select 1
                   from (parent_student_links l join students s on (((s.id = l.student_id) and (s.id = library_loans.student_id))))
                  where ((l.parent_user_id = (select auth.uid())) and (l.verified_at is not null))))
  );

alter policy library_loans_write on public.library_loans
  using ((exists ( select 1
   from user_roles r
  where ((r.user_id = (select auth.uid())) and ((r.role = 'super_admin'::app_role) or ((r.role = any (array['admin'::app_role, 'librarian'::app_role])) and private.sai_security_branch_member(library_loans.branch_id)))))))
  with check ((exists ( select 1
   from user_roles r
  where ((r.user_id = (select auth.uid())) and ((r.role = 'super_admin'::app_role) or ((r.role = any (array['admin'::app_role, 'librarian'::app_role])) and private.sai_security_branch_member(library_loans.branch_id)))))));

alter policy learning_vocabulary_select on public.learning_vocabulary
  using (is_published or private.sai_learning_can_manage_course(course_id));

alter policy learning_vocabulary_write on public.learning_vocabulary
  using (private.sai_learning_can_manage_course(course_id))
  with check (private.sai_learning_can_manage_course(course_id));

alter policy learning_vocab_progress_select on public.learning_vocab_progress
  using (private.sai_security_can_read_student(student_id));

alter policy learning_vocab_progress_write on public.learning_vocab_progress
  using (private.sai_learning_own_student(student_id))
  with check (private.sai_learning_own_student(student_id));

-- ============================================================================
-- 2. Reduce the eleven public twins to delegating wrappers.
--    No logic is duplicated any more; the private schema is the only source.
--    SECURITY DEFINER plus a pinned search_path keeps behaviour identical to the
--    private implementation for every existing caller.
-- ============================================================================

create or replace function public.sai_security_has_role(wanted_role public.app_role) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_has_role($1) $$;

create or replace function public.sai_security_branch_member(wanted_branch uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_branch_member($1) $$;

create or replace function public.sai_security_can_read_branch(wanted_branch uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_can_read_branch($1) $$;

create or replace function public.sai_security_can_read_class(wanted_class uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_can_read_class($1) $$;

create or replace function public.sai_security_can_read_session(wanted_session uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_can_read_session($1) $$;

create or replace function public.sai_security_can_read_student(wanted_student uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_security_can_read_student($1) $$;

create or replace function public.sai_learning_can_grade_homework(wanted_homework uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_learning_can_grade_homework($1) $$;

create or replace function public.sai_learning_can_manage_course(wanted_course uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_learning_can_manage_course($1) $$;

create or replace function public.sai_learning_can_read_course(wanted_course uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_learning_can_read_course($1) $$;

create or replace function public.sai_learning_can_read_homework(wanted_homework uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_learning_can_read_homework($1) $$;

create or replace function public.sai_learning_own_student(wanted_student uuid) returns boolean
language sql stable security definer set search_path = pg_catalog, public, private
as $$ select private.sai_learning_own_student($1) $$;

commit;

-- ============================================================================
-- Verification (run after applying)
-- ============================================================================
-- (a) No policy may reference an unqualified helper any more. Must return 0 rows.
--
--   select tablename, policyname, qual, with_check
--     from pg_policies
--    where schemaname = 'public'
--      and (
--        (coalesce(qual,'') ~ '(^|[^a-z_.])sai_(security|learning)_')
--     or (coalesce(with_check,'') ~ '(^|[^a-z_.])sai_(security|learning)_')
--      );
--
-- (b) No policy may still depend on a public twin. Must return 0 rows.
--
--   select (select polname from pg_policy where oid = d.objid) as policy,
--          (select n.nspname || '.' || p.proname
--             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--            where p.oid = d.refobjid) as referenced
--     from pg_depend d
--    where d.refclassid = 'pg_proc'::regclass
--      and d.refobjid in (
--        select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--         where n.nspname = 'public'
--           and (p.proname like 'sai_security_%' or p.proname like 'sai_learning_%')
--      );
--
-- (c) All eleven public wrappers must report prosecdef = true and carry a pinned
--     search_path. Must return 11 rows, all definer = t.
--
--   select p.proname, p.prosecdef as definer, p.proconfig::text
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and (p.proname like 'sai_security_%' or p.proname like 'sai_learning_%')
--    order by p.proname;

-- ============================================================================
-- Not included, deliberately
-- ============================================================================
--   * The public twins are NOT dropped. Eighteen functions call them
--     unqualified, eleven of those pin `search_path` to `public` without
--     `private`, so a drop would raise "function does not exist" inside
--     admissions, attendance, directory, role and finance RPCs at runtime.
--   * No GRANT is issued here. Restoring write privileges is migration 021.