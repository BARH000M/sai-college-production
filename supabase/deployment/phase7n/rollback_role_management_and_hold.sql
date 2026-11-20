-- Rollback for 20261120120000_role_management_and_hold_infrastructure.sql
-- Project: aeryusbrulqdxjdynwfh (Main). NEVER run automatically.
--
-- Order matters: release the hold and drop the guards first, so no trigger is left
-- pointing at a function that no longer exists.
--
-- Consequence of running this: public.sai_manage_role_assignment() and
-- public.sai_assert_mutations_enabled() disappear, so Super Admin grant/revoke and
-- every Edge Function using the mutation gate stop working again. Take a verified
-- backup first and have this script reviewed by the owner.

begin;

-- 1. Make sure the platform is not left in maintenance mode.
update private.sai_mutation_hold_state
set enabled = false,
    changed_at = pg_catalog.now(),
    reason = 'hold released by 20261120120000 rollback'
where singleton;

-- 2. Remove every installed guard trigger.
do $rollback$
declare
  v_relation record;
begin
  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage', 'auth')
      and c.relkind in ('r', 'p')
      and not c.relispartition
    order by n.nspname, c.relname
  loop
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_statement on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_truncate on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_row on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_account_mutation on %I.%I',
      v_relation.nspname, v_relation.relname
    );
  end loop;
end;
$rollback$;

-- 3. Drop the public surface installed by the package.
drop function if exists public.sai_set_mutation_hold(boolean, text);
drop function if exists public.sai_mutation_hold_status();
drop function if exists public.sai_assert_mutations_enabled();
drop function if exists public.sai_manage_role_assignment(
  uuid, uuid, text, public.app_role, uuid[], boolean, boolean, text, text
);

-- 4. Drop the private helpers.
drop function if exists private.sai_install_mutation_hold_guards();
drop function if exists private.sai_mutation_hold_guard();
drop function if exists private.sai_assert_mutations_enabled();
drop function if exists private.sai_has_other_usable_super_admin(uuid);

-- 5. The state and audit tables are intentionally kept so the maintenance history
--    stays auditable. Drop them manually only with explicit approval:
--    drop table if exists private.sai_mutation_hold_audit;
--    drop table if exists private.sai_mutation_hold_state;

notify pgrst, 'reload schema';

commit;