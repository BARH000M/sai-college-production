-- Security invariants — the regression guard for the helper layering.
--
-- Read-only. Safe to run against the linked project or a local database:
--     supabase db query --linked --file supabase/tests/security_invariants.sql
-- or via the runner:
--     node supabase/tests/run-security-invariants.cjs
--
-- Exits non-zero (raises) if any RLS policy or private helper starts routing
-- through the public helper layer again, or if a public wrapper stops being a
-- pure delegator.
--
-- Implementation note: this deliberately uses pg_depend, not pg_policies.qual.
-- A policy expression is deparsed relative to the reader's search_path, so
-- `private.sai_x(...)` prints as `sai_x(...)` when `private` is on the path.
-- Text matching would produce false positives (and, depending on the reader's
-- path, false negatives). The dependency graph is exact.

do $$
declare
  v_count integer;
  v_names text;
begin
  -- 1. No RLS policy may depend on a public sai_* helper.
  select count(*), string_agg(c.relname || '.' || pol.polname, ', ' order by pol.polname)
    into v_count, v_names
  from pg_depend d
  join pg_policy pol on pol.oid = d.objid
  join pg_class c on c.oid = pol.polrelid
  join pg_proc p on p.oid = d.refobjid
  join pg_namespace pn on pn.oid = p.pronamespace
  where d.classid = 'pg_policy'::regclass
    and d.refclassid = 'pg_proc'::regclass
    and pn.nspname = 'public'
    and p.proname like 'sai\_%' escape '\';

  if v_count > 0 then
    raise exception 'FAIL invariant 1: % policy(ies) depend on public helpers -> %', v_count, v_names;
  end if;
  raise notice 'PASS invariant 1: no RLS policy depends on a public helper';

  -- 2. No private sai_* helper may call a public sai_* helper.
  select count(*), string_agg(src.proname, ', ' order by src.proname)
    into v_count, v_names
  from pg_depend d
  join pg_proc src on src.oid = d.objid
  join pg_namespace sn on sn.oid = src.pronamespace
  join pg_proc ref on ref.oid = d.refobjid
  join pg_namespace rn on rn.oid = ref.pronamespace
  where d.classid = 'pg_proc'::regclass
    and d.refclassid = 'pg_proc'::regclass
    and sn.nspname = 'private'
    and rn.nspname = 'public'
    and ref.proname like 'sai\_%' escape '\'
    and src.proname like 'sai\_%' escape '\';

  if v_count > 0 then
    raise exception 'FAIL invariant 2: % private helper(s) call public helpers -> %', v_count, v_names;
  end if;
  raise notice 'PASS invariant 2: no private helper calls the public layer';

  -- 3. Every public wrapper must stay a pure private.* delegator.
  select count(*), string_agg(p.proname, ', ' order by p.proname)
    into v_count, v_names
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class',
      'sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role',
      'sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course',
      'sai_learning_can_read_homework','sai_learning_own_student',
      'sai_finance_can_read_student','sai_finance_has_role','sai_finance_staff'
    )
    and p.prosrc !~ 'private\.sai_';

  if v_count > 0 then
    raise exception 'FAIL invariant 3: % wrapper(s) stopped delegating -> %', v_count, v_names;
  end if;
  raise notice 'PASS invariant 3: all public wrappers delegate to private.*';

  -- 4. Advisory: wrappers must not still be RPC-reachable by authenticated.
  select count(*) into v_count
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in (
      'sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class',
      'sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role',
      'sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course',
      'sai_learning_can_read_homework','sai_learning_own_student',
      'sai_finance_can_read_student','sai_finance_has_role','sai_finance_staff'
    )
    and has_function_privilege('authenticated', p.oid, 'execute');

  if v_count > 0 then
    raise warning 'PENDING: % wrapper(s) still grant EXECUTE to authenticated — run 023 and 028 to close the oracle', v_count;
  else
    raise notice 'PASS invariant 4: no wrapper is executable by authenticated';
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.proname = 'sai_assert_security_invariants'
  ) then
    raise notice '%', private.sai_assert_security_invariants();
  else
    raise notice 'gate function not installed (apply 027) — the three invariant checks above still ran';
  end if;
end;
$$;