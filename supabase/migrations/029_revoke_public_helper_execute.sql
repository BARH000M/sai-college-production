-- 029 — Remove inherited PUBLIC EXECUTE from internal SECURITY DEFINER wrappers.
--
-- Migrations 023 and 028 revoked only authenticated. PostgreSQL's default
-- PUBLIC EXECUTE grant still made the wrappers callable by anon and
-- authenticated, so revoke from PUBLIC and grant the server role explicitly.
-- RLS now calls private.* directly; wrapper owners retain their own privileges.

revoke execute on function
  public.sai_security_branch_member(uuid),
  public.sai_security_can_read_branch(uuid),
  public.sai_security_can_read_class(uuid),
  public.sai_security_can_read_session(uuid),
  public.sai_security_can_read_student(uuid),
  public.sai_security_has_role(public.app_role),
  public.sai_learning_can_grade_homework(uuid),
  public.sai_learning_can_manage_course(uuid),
  public.sai_learning_can_read_course(uuid),
  public.sai_learning_can_read_homework(uuid),
  public.sai_learning_own_student(uuid),
  public.sai_finance_can_read_student(uuid, uuid),
  public.sai_finance_has_role(text[]),
  public.sai_finance_staff(uuid, text[])
from public, anon, authenticated;

grant execute on function
  public.sai_security_branch_member(uuid),
  public.sai_security_can_read_branch(uuid),
  public.sai_security_can_read_class(uuid),
  public.sai_security_can_read_session(uuid),
  public.sai_security_can_read_student(uuid),
  public.sai_security_has_role(public.app_role),
  public.sai_learning_can_grade_homework(uuid),
  public.sai_learning_can_manage_course(uuid),
  public.sai_learning_can_read_course(uuid),
  public.sai_learning_can_read_homework(uuid),
  public.sai_learning_own_student(uuid),
  public.sai_finance_can_read_student(uuid, uuid),
  public.sai_finance_has_role(text[]),
  public.sai_finance_staff(uuid, text[])
to service_role;
