-- Local proposal only. Do not apply without explicit Preview approval.
--
-- Blocker 1 root cause (verified against Preview catalogs 2026-11-16):
--   public.branch_memberships relacl granted authenticated table-level
--   INSERT/SELECT/UPDATE (arw) plus redundant column grants on
--   user_id/branch_id (INSERT) and is_active (INSERT/UPDATE).
--   Policy branch_memberships_update_self_or_super_admin had WITH CHECK
--   (user_id = auth.uid() and admin role) that did not validate the NEW
--   branch_id, so an admin could retarget their own active membership to
--   any existing branch and inherit that branch's admin scope. The AFTER
--   audit trigger only records the change; it does not prevent it.
--
-- Fix: authenticated keeps SELECT only (self/super_admin RLS unchanged).
-- All membership writes flow through service_role Edge Functions
-- (manage-roles, provision-learning-account, link-student-account), which
-- hold explicit DML grants and bypass RLS as the approved server contracts.
-- No browser code writes this table (verified: src/ and mobile/ only SELECT).
-- No records are modified; RLS stays enabled; no broad grants are added.
begin;

-- Table-level write privileges (relacl arw) and the separate column-level
-- grants must both be revoked: revoking one layer does not remove the other.
revoke insert, update, delete on public.branch_memberships from authenticated;
revoke insert (user_id, branch_id, is_active), update (user_id, branch_id, is_active)
  on public.branch_memberships from authenticated;

-- Replace the self-update policy with a super-admin-only policy that binds
-- both the old and the new row. The insert policy is already super-admin-only
-- and the self/super-admin SELECT policy is intentionally untouched.
drop policy if exists branch_memberships_update_self_or_super_admin on public.branch_memberships;

create policy branch_memberships_update_super_admin on public.branch_memberships
  for update to authenticated
  using (private.sai_security_has_role('super_admin'))
  with check (private.sai_security_has_role('super_admin'));

notify pgrst, 'reload schema';
commit;