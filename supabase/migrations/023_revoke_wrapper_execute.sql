-- 023 — Close the UUID enumeration oracle on the eleven public helper wrappers
--
-- Why: the eleven public.sai_security_* / public.sai_learning_* functions are
-- SECURITY DEFINER thin delegating wrappers over private.* implementations.
-- They live in the `public` schema, so PostgREST exposes them as RPC endpoints.
-- With EXECUTE held by `authenticated`, any signed-in user could POST to
--   /rest/v1/rpc/sai_security_can_read_student
-- with a guessed UUID and learn whether they are entitled to that record.
-- The answer is authoritative (SECURITY DEFINER bypasses RLS), which makes the
-- oracle reliable. It returns booleans only — no rows leak — but it is an
-- entitlement probe over arbitrary IDs.
--
-- Safety: safe to revoke because
--   * all 27 internal callers are SECURITY DEFINER owned by `postgres`, so they
--     pass the EXECUTE check as owner;
--   * every RLS policy now references private.* explicitly;
--   * no web or mobile client calls these functions (verified: zero matches in
--     src/ and mobile/lib/).
--
-- NOTE: this statement is blocked from the agent SQL path (privilege
-- escalation). It must be run in the Supabase Dashboard SQL Editor.
--
-- Rollback: grant execute on function ... to authenticated;

revoke execute on function
  public.sai_security_branch_member(uuid),
  public.sai_security_can_read_branch(uuid),
  public.sai_security_can_read_class(uuid),
  public.sai_security_can_read_session(uuid),
  public.sai_security_can_read_student(uuid),
  public.sai_security_has_role(app_role),
  public.sai_learning_can_grade_homework(uuid),
  public.sai_learning_can_manage_course(uuid),
  public.sai_learning_can_read_course(uuid),
  public.sai_learning_can_read_homework(uuid),
  public.sai_learning_own_student(uuid)
from authenticated;

-- Verification: expect authenticated_exec = false for all eleven rows,
-- while service_role keeps access for server-side work.
select
  p.proname as func_name,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_exec,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
  has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_exec
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class',
    'sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role',
    'sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course',
    'sai_learning_can_read_homework','sai_learning_own_student'
  )
order by p.proname;