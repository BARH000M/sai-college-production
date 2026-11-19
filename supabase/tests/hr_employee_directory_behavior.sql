-- Self-contained integration test. The runner must target a disposable database.
\set ON_ERROR_STOP on
begin;
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;

create type public.app_role as enum (
  'super_admin', 'admin', 'teacher', 'accountant', 'receptionist',
  'librarian', 'student', 'parent', 'content_editor'
);
create table public.user_roles (
  user_id uuid not null references auth.users(id),
  role public.app_role not null,
  primary key (user_id, role)
);
create table public.branches (id uuid primary key, name text not null, code text not null unique);
create table public.branch_memberships (
  user_id uuid not null references auth.users(id),
  branch_id uuid not null references public.branches(id),
  is_active boolean not null default true,
  primary key (user_id, branch_id)
);

create function public.sai_security_has_role(wanted_role public.app_role)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role);
$$;
create function public.sai_security_branch_member(wanted_branch uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid()) and m.branch_id = wanted_branch and m.is_active);
$$;
grant usage on type public.app_role to authenticated;
grant execute on function public.sai_security_has_role(public.app_role),
  public.sai_security_branch_member(uuid) to authenticated;

\ir ../migrations/20261119230404_phase5a_hr_employee_directory.sql

do $$
begin
  if to_regclass('public.sai_hr_employees') is null then
    raise exception 'Phase 5A HR migration did not create its table';
  end if;
  if has_table_privilege('authenticated', 'public.sai_hr_employees', 'DELETE') then
    raise exception 'HR employee records unexpectedly allow deletion';
  end if;
end;
$$;

do $$
declare
  admin_id uuid := gen_random_uuid();
  teacher_id uuid := gen_random_uuid();
  other_admin_id uuid := gen_random_uuid();
  branch_a uuid := gen_random_uuid();
  branch_b uuid := gen_random_uuid();
  visible_count integer;
  employee_id uuid;
  denied boolean;
begin
  insert into auth.users (id) values (admin_id), (teacher_id), (other_admin_id);
  insert into public.user_roles (user_id, role) values
    (admin_id, 'admin'), (teacher_id, 'teacher'), (other_admin_id, 'admin');
  insert into public.branches (id, name, code) values
    (branch_a, 'HR_TEST_A', 'HR_TEST_A_' || replace(gen_random_uuid()::text, '-', '')),
    (branch_b, 'HR_TEST_B', 'HR_TEST_B_' || replace(gen_random_uuid()::text, '-', ''));
  insert into public.branch_memberships (user_id, branch_id, is_active)
    values (admin_id, branch_a, true), (other_admin_id, branch_b, true);

  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';
  insert into public.sai_hr_employees
    (branch_id, title, employee_code, department, designation)
    values (branch_a, 'HR_TEST_EMPLOYEE', 'HR_TEST_001', 'Academic', 'Teacher')
    returning id into employee_id;
  if not found then raise exception 'Authorized branch admin could not create employee'; end if;

  update public.sai_hr_employees set title = 'HR_TEST_UPDATED' where id = employee_id;
  if not found then raise exception 'Authorized branch admin could not update employee'; end if;

  denied := false;
  begin
    insert into public.sai_hr_employees
      (branch_id, title, employee_code, department, designation)
      values (branch_b, 'HR_TEST_CROSS_BRANCH', 'HR_TEST_002', 'Academic', 'Teacher');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Cross-branch employee creation was accepted'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', other_admin_id::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.sai_hr_employees;
  if visible_count <> 0 then raise exception 'Admin read employee data from another branch'; end if;
  execute 'reset role';

  perform set_config('request.jwt.claim.sub', teacher_id::text, true);
  execute 'set local role authenticated';
  select count(*) into visible_count from public.sai_hr_employees;
  if visible_count <> 0 then raise exception 'Non-HR role read the employee directory'; end if;
  denied := false;
  begin
    insert into public.sai_hr_employees
      (branch_id, title, employee_code, department, designation)
      values (branch_a, 'HR_TEST_UNAUTHORIZED', 'HR_TEST_003', 'Academic', 'Teacher');
  exception when insufficient_privilege then denied := true; end;
  if not denied then raise exception 'Non-HR role created an employee'; end if;
  execute 'reset role';
end;
$$;
rollback;
