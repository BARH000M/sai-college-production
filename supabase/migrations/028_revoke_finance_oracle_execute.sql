-- 028 — Close the second enumeration oracle: sai_finance_can_read_student
--
-- Found during the public-RPC audit. The 023 revoke covers the eleven
-- security/learning wrappers, but public.sai_finance_can_read_student(
-- wanted_student uuid, wanted_branch uuid) is the same shape and was missed:
-- it is SECURITY DEFINER (authoritative, bypasses RLS), lives in `public`, and
-- grants EXECUTE to `authenticated` — so any signed-in user can POST
--   /rest/v1/rpc/sai_finance_can_read_student
-- with a guessed student UUID and branch UUID and learn whether that student's
-- fees are visible to them. Booleans only, no rows, but it is an entitlement
-- probe over arbitrary IDs — an oracle.
--
-- Safe to revoke because (verified before writing this file):
--   * after 026 the six finance policies point at private.*, and `authenticated`
--     holds EXECUTE on the private helpers, so RLS keeps resolving;
--   * the two remaining internal callers (sai_finance_assignments and
--     sai_finance_payments) are SECURITY DEFINER owned by `postgres`, so they
--     pass the EXECUTE check as owner;
--   * no web or mobile client calls it — zero matches in src/ and mobile/lib/.
--
-- Same platform guardrail as GRANT/REVOKE in 021/023: this statement is refused
-- from the agent SQL path and must be run in the Supabase Dashboard SQL Editor.
--
-- Rollback: grant execute on function public.sai_finance_can_read_student(uuid, uuid) to authenticated;

revoke execute on function public.sai_finance_can_read_student(uuid, uuid) from authenticated;

-- Verification: authenticated_exec must be false, service_role_exec true.
select p.proname as func_name,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
       has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_exec
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('sai_finance_can_read_student', 'sai_finance_staff', 'sai_finance_has_role')
order by p.proname;