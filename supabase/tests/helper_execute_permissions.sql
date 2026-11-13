-- Run only against an isolated test database or an explicitly approved local
-- Supabase instance. Verifies effective role privileges, including PUBLIC ACLs.
do $$
declare
  v_signature text;
  v_function regprocedure;
  v_public_exec boolean;
begin
  foreach v_signature in array array[
    'public.sai_security_branch_member(uuid)',
    'public.sai_security_can_read_branch(uuid)',
    'public.sai_security_can_read_class(uuid)',
    'public.sai_security_can_read_session(uuid)',
    'public.sai_security_can_read_student(uuid)',
    'public.sai_security_has_role(public.app_role)',
    'public.sai_learning_can_grade_homework(uuid)',
    'public.sai_learning_can_manage_course(uuid)',
    'public.sai_learning_can_read_course(uuid)',
    'public.sai_learning_can_read_homework(uuid)',
    'public.sai_learning_own_student(uuid)',
    'public.sai_finance_can_read_student(uuid,uuid)',
    'public.sai_finance_has_role(text[])',
    'public.sai_finance_staff(uuid,text[])'
  ]
  loop
    v_function := to_regprocedure(v_signature);
    if v_function is null then
      raise exception 'FAIL: expected wrapper % is missing', v_signature;
    end if;

    if has_function_privilege('anon', v_function, 'EXECUTE') then
      raise exception 'FAIL: anon can execute %', v_signature;
    end if;
    if has_function_privilege('authenticated', v_function, 'EXECUTE') then
      raise exception 'FAIL: authenticated can execute %', v_signature;
    end if;
    if not has_function_privilege('service_role', v_function, 'EXECUTE') then
      raise exception 'FAIL: service_role lost EXECUTE on %', v_signature;
    end if;

    select exists (
      select 1
      from pg_proc p,
           aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
      where p.oid = v_function
        and acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) into v_public_exec;
    if v_public_exec then
      raise exception 'FAIL: PUBLIC has EXECUTE on %', v_signature;
    end if;
  end loop;

  raise notice 'PASS: helper wrappers are denied to PUBLIC, anon, authenticated and retained for service_role';
end;
$$;
