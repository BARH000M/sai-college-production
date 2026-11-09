-- Disposable-only approximation; the runner supplies the target guard.
do $$
begin
  if current_setting('server_version_num')::integer <> 170011 then
    raise exception 'Fixture requires PostgreSQL 17.11';
  end if;
  if exists (select 1 from pg_catalog.pg_namespace where nspname in ('auth', 'supabase_migrations', 'sai_finance'))
    or exists (select 1 from pg_catalog.pg_roles where rolname in ('anon', 'authenticated', 'sai_finance_owner'))
    or exists (select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public' and c.relkind in ('r', 'p', 'v', 'm', 'S'))
    or exists (select 1 from pg_catalog.pg_type t join pg_catalog.pg_namespace n on n.oid = t.typnamespace
               where n.nspname = 'public' and t.typname = 'app_role') then
    raise exception 'Cluster or database is not fresh; refusing fixture setup';
  end if;
end;
$$;

create role anon nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
create role authenticated nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable set search_path = pg_catalog
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
revoke all on schema auth from public;
grant usage on schema auth to anon, authenticated;
revoke all on function auth.uid() from public;
grant execute on function auth.uid() to anon, authenticated;
revoke create on schema public from public, anon, authenticated;
grant usage on schema public to anon, authenticated;
