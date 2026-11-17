-- Reversible local/Main proposal. First deactivate through the authorized
-- Super Admin RPC and verify the status; then run this transaction.
begin;

do $$
begin
  if exists (
    select 1
    from private.sai_mutation_hold_state
    where singleton and enabled
  ) then
    raise exception 'maintenance_hold_must_be_disabled_first' using errcode = '55000';
  end if;
end
$$;

drop event trigger sai_mutation_hold_ddl_guard;

do $$
declare
  v_relation record;
begin
  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
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
  end loop;

  for v_relation in
    select n.nspname, c.relname
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public', 'private', 'storage')
      and c.relkind in ('r', 'p')
      and c.relispartition
    order by n.nspname, c.relname
  loop
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_partition_statement on %I.%I',
      v_relation.nspname, v_relation.relname
    );
    execute pg_catalog.format(
      'drop trigger if exists sai_mutation_hold_partition_truncate on %I.%I',
      v_relation.nspname, v_relation.relname
    );
  end loop;

  if pg_catalog.to_regclass('auth.users') is not null then
    execute 'drop trigger if exists sai_mutation_hold_account_write on auth.users';
  end if;
  if pg_catalog.to_regclass('auth.identities') is not null then
    execute 'drop trigger if exists sai_mutation_hold_account_write on auth.identities';
  end if;
end
$$;

drop function public.sai_set_mutation_hold(boolean, text);
drop function public.sai_mutation_hold_status();
drop function public.sai_assert_mutations_enabled();
drop function private.sai_install_mutation_hold_guards();
drop function private.sai_mutation_hold_guard();
drop function private.sai_assert_mutations_enabled();
drop table private.sai_mutation_hold_audit;
drop table private.sai_mutation_hold_state;

commit;
