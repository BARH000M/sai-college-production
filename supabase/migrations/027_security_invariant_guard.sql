-- 027 — Build gate: fail fast if the helper layering ever regresses
--
-- private.sai_assert_security_invariants() raises 42501 as soon as any of these
-- is true, so `supabase db push` (and any CI that runs it) fails instead of
-- silently reintroducing the drift that 022/025/026 removed:
--
--   1. an RLS policy depends on a public sai_* helper;
--   2. a private sai_* helper calls a public sai_* helper;
--   3. a public wrapper stopped being a pure private.* delegator.
--   4. (opt-in) a public wrapper still grants EXECUTE to `authenticated`,
--      i.e. the UUID enumeration oracle is open. Pass true to enforce, e.g.
--        select private.sai_assert_security_invariants(true);
--      Leave false until 023 and 028 have been run in the dashboard.
--
-- Why pg_depend and not pg_policies.qual: the deparsed policy expression is
-- rendered relative to the *caller's* search_path, so `private.sai_x(...)` is
-- printed as `sai_x(...)` inside a function that pins `private` into its path.
-- Text matching therefore reports false positives. The dependency graph is
-- exact and search_path independent.
--
-- The function lives in `private`, which is not exposed by PostgREST, so it is
-- not itself reachable as an RPC endpoint.

create or replace function private.sai_assert_security_invariants(p_enforce_execute boolean default false)
returns text
language plpgsql security definer
set search_path = pg_catalog, public, private
as $function$
declare
  v_wrappers constant text[] := array[
    'sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class',
    'sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role',
    'sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course',
    'sai_learning_can_read_homework','sai_learning_own_student',
    'sai_finance_can_read_student','sai_finance_has_role','sai_finance_staff'
  ];
  v_count integer;
  v_names text;
begin
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
    raise exception
      'security invariant violated: % RLS policy(ies) depend on the public helper layer (%). Re-point them to private.* (migrations 022/025/026).',
      v_count, v_names using errcode = '42501';
  end if;

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
    raise exception
      'security invariant violated: % private helper(s) call the public helper layer (%). Call private.* instead (migration 025).',
      v_count, v_names using errcode = '42501';
  end if;

  select count(*), string_agg(p.proname, ', ' order by p.proname)
    into v_count, v_names
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = any (v_wrappers)
    and p.prosrc !~ 'private\.sai_';

  if v_count > 0 then
    raise exception
      'security invariant violated: % public wrapper(s) no longer delegate to private.* (%). Re-apply 022/026.',
      v_count, v_names using errcode = '42501';
  end if;

  if p_enforce_execute then
    select count(*) into v_count
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any (v_wrappers)
      and has_function_privilege('authenticated', p.oid, 'execute');

    if v_count > 0 then
      raise exception
        'security invariant violated: % public wrapper(s) still grant EXECUTE to authenticated, so the UUID enumeration oracle is open. Run 023 and 028.',
        v_count using errcode = '42501';
    end if;
  end if;

  return format(
    'security invariants OK: 0 policies on public helpers, 0 private helpers calling public, %s wrappers delegating, execute_enforced=%s',
    array_length(v_wrappers, 1), p_enforce_execute
  );
end;
$function$;

-- Fail the migration itself if the tree is already dirty.
select private.sai_assert_security_invariants();