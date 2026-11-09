-- 021_restore_write_grants.sql
--
-- Purpose: restore table privileges the application already assumes, so the RLS
-- policies that were written for these tables become reachable.
--
-- Background (verified read-only, Phase 0.1):
--   Every one of these nine tables had RLS enabled with correct INSERT / UPDATE
--   policies scoped to `authenticated`, but the privilege layer granted only
--   SELECT. A table privilege is checked before RLS is evaluated, so every
--   direct write from the portal failed with 42501 permission denied — often
--   silently, because the client code wraps the call in a catch.
--
-- Affected writes in application code:
--   src/portal/lib/auth.ts          -> profiles (insert on first sign-in)
--   src/portal/lib/management.ts    -> branches, academic_sessions, classes, students
--   src/portal/lib/attendance.ts    -> attendance_sessions, attendance_records
--   src/portal/lib/admissions.ts    -> admissions_enquiries
--   (branch_memberships)            -> staff onboarding / campus team membership
--
-- Scope discipline:
--   * INSERT and UPDATE only. No DELETE is granted: none of these nine tables
--     has a DELETE policy, so a DELETE grant would unlock nothing and only
--     widen the blast radius if a policy is ever added carelessly.
--   * No TRUNCATE, no REFERENCES, no TRIGGER.
--   * `anon` is deliberately untouched.
--   * Finance, library and communications are deliberately untouched: they
--     already write exclusively through SECURITY DEFINER RPCs.
--
-- This migration is idempotent and creates no schema objects.

grant insert, update on table
  public.profiles,
  public.branches,
  public.academic_sessions,
  public.classes,
  public.students,
  public.attendance_sessions,
  public.attendance_records,
  public.admissions_enquiries,
  public.branch_memberships
to authenticated;

-- Verification (run separately, expected: INSERT and UPDATE appear alongside SELECT)
-- select table_name, grantee, string_agg(privilege_type, ', ' order by privilege_type) as privs
-- from information_schema.role_table_grants
-- where table_schema = 'public'
--   and grantee in ('authenticated', 'anon')
--   and table_name in ('profiles','branches','academic_sessions','classes','students',
--                      'attendance_sessions','attendance_records','admissions_enquiries',
--                      'branch_memberships')
-- group by table_name, grantee
-- order by table_name, grantee;