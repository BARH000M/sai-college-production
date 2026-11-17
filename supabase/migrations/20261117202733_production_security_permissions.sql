-- Forward-only reconciliation for historical 021/023/024/028/029.
-- Main already has the intended column grants, so the broad 021 grants are
-- intentionally not replayed. Close public helper oracles and retire the
-- legacy role writer without deleting historical audit rows.
begin;
set local lock_timeout = '10s';
set local statement_timeout = '60s';

do $$
begin
  if pg_catalog.to_regprocedure(
      'public.sai_set_role(uuid,public.app_role,boolean)') is null
    or pg_catalog.to_regprocedure(
      'private.sai_security_has_role(public.app_role)') is null then
    raise exception 'Expected Main security baseline is missing';
  end if;
  if (select count(*) from pg_catalog.pg_enum
      where enumtypid = 'public.app_role'::pg_catalog.regtype) <> 9 then
    raise exception 'Unexpected app_role contract';
  end if;
end
$$;

create or replace function public.sai_set_role(
  p_user_id uuid,
  p_role public.app_role,
  p_enabled boolean
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception 'Use manage-roles with explicit branch and confirmation inputs'
    using errcode = '42501';
end
$$;
revoke all on function public.sai_set_role(uuid,public.app_role,boolean)
  from public, anon, authenticated, service_role;

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
  public.sai_finance_can_read_student(uuid,uuid),
  public.sai_finance_has_role(text[]),
  public.sai_finance_staff(uuid,text[])
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
  public.sai_finance_can_read_student(uuid,uuid),
  public.sai_finance_has_role(text[]),
  public.sai_finance_staff(uuid,text[])
to service_role;

notify pgrst, 'reload schema';
commit;
