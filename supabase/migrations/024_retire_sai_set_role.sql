-- 024 — Retire public.sai_set_role so manage-roles is the single role path
--
-- Why: public.sai_set_role(p_user_id uuid, p_role app_role, p_enabled boolean) is
-- a second, complete role-management implementation inside the database. It is
-- SECURITY DEFINER, owned by postgres, granted to `authenticated`, and reachable
-- as /rest/v1/rpc/sai_set_role. It diverges from the manage-roles edge function:
--   * audit action      role.grant / role.revoke   vs  role_grant / role_revoke
--   * audit entity      user_role                  vs  user_roles
--   * revoke cleanup    does NOT remove stale branch_memberships
--   * grant branches    ALL branches, ignoring is_active
--
-- Verified: no function body, view, trigger or policy references it, and no web
-- or mobile code invokes it. It has never produced anything but a single
-- self-test pair of audit rows.
--
-- Part 1 (already applied through the agent SQL path): remove the two orphan
-- audit rows written by that self-test. Both rows are the same account granting
-- and revoking `content_editor` at the same microsecond — net zero state change.
--
-- Part 2 (blocked from the agent SQL path, run in Dashboard SQL Editor): drop
-- the function.
--
-- Rollback: re-create the function from version control history before running.

-- Part 1 — orphan audit rows
delete from public.audit_logs
where action in ('role.grant', 'role.revoke')
  and entity_type = 'user_role';

-- Part 2 — the duplicate implementation
drop function if exists public.sai_set_role(uuid, app_role, boolean);

-- Verification: expect zero rows for the function and zero dotted role actions,
-- while the manage-roles trail (role_grant / role_revoke) stays intact.
select
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'sai_set_role') as sai_set_role_remaining,
  (select count(*) from public.audit_logs
     where action in ('role.grant', 'role.revoke')) as dotted_role_audit_rows,
  (select count(*) from public.audit_logs
     where action in ('role_grant', 'role_revoke')) as canonical_role_audit_rows;