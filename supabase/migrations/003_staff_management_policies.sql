-- Prepared for review and isolated role testing; do not apply automatically.
-- Sessions are global, so only super admins can manage them.
-- New branches are likewise created only by super admins.

do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
  if exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('branches', 'academic_sessions', 'classes', 'students', 'branch_memberships')
      and (not c.relrowsecurity
        or has_any_column_privilege('authenticated', c.oid, 'INSERT')
        or has_any_column_privilege('authenticated', c.oid, 'UPDATE')
        or has_any_column_privilege('anon', c.oid, 'INSERT')
        or has_any_column_privilege('anon', c.oid, 'UPDATE'))
  ) then
    raise exception 'Unexpected RLS or browser write privileges; review before proceeding';
  end if;
  if exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public'
      and p.tablename in ('branches', 'academic_sessions', 'classes', 'students', 'branch_memberships')
      and p.cmd <> 'SELECT'
  ) then
    raise exception 'Unexpected management write policy; review before proceeding';
  end if;
end;
$$;

alter table public.classes add column if not exists is_active boolean not null default true;
alter table public.branch_memberships add column if not exists is_active boolean not null default true;

-- Inactive memberships must not confer branch access. Existing SELECT policies
-- continue to use this helper; archived rows themselves remain queryable.
create or replace function public.sai_security_branch_member(wanted_branch uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$$;

-- Column grants keep generated keys, ownership and branch/session scope
-- immutable. They do not grant any browser access to user_roles.
grant insert (name, code, address, is_active) on public.branches to authenticated;
grant update (name, code, address, is_active) on public.branches to authenticated;
grant insert (name, starts_on, ends_on, is_active) on public.academic_sessions to authenticated;
grant update (name, starts_on, ends_on, is_active) on public.academic_sessions to authenticated;
grant insert (branch_id, session_id, name, program, capacity, teacher_id, is_active)
  on public.classes to authenticated;
grant update (name, program, capacity, is_active) on public.classes to authenticated;
grant insert (user_id, branch_id, admission_no, full_name, date_of_birth, class_id, status)
  on public.students to authenticated;
grant update (admission_no, full_name, date_of_birth, class_id, status)
  on public.students to authenticated;
grant insert (user_id, branch_id, is_active) on public.branch_memberships to authenticated;
grant update (is_active) on public.branch_memberships to authenticated;

create policy branches_insert_super_admin on public.branches
  for insert to authenticated
  with check (public.sai_security_has_role('super_admin'));
create policy branches_update_scoped_admin on public.branches
  for update to authenticated
  using (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(id)))
  with check (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(id)));

create policy academic_sessions_insert_super_admin on public.academic_sessions
  for insert to authenticated
  with check (public.sai_security_has_role('super_admin'));
create policy academic_sessions_update_super_admin on public.academic_sessions
  for update to authenticated
  using (public.sai_security_has_role('super_admin'))
  with check (public.sai_security_has_role('super_admin'));

create policy classes_insert_scoped_admin on public.classes
  for insert to authenticated
  with check (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin')
      and public.sai_security_branch_member(branch_id)
      and public.sai_security_can_read_session(session_id)));
create policy classes_update_scoped_admin on public.classes
  for update to authenticated
  using (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)))
  with check (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)));

create policy students_insert_scoped_admin on public.students
  for insert to authenticated
  with check (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)));
create policy students_update_scoped_admin on public.students
  for update to authenticated
  using (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)))
  with check (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(branch_id)));

-- Membership privacy remains self-only for admins: only super admins can
-- create or manage another user's membership.
create policy branch_memberships_insert_super_admin on public.branch_memberships
  for insert to authenticated
  with check (public.sai_security_has_role('super_admin'));
create policy branch_memberships_update_self_or_super_admin on public.branch_memberships
  for update to authenticated
  using (public.sai_security_has_role('super_admin') or
    (user_id = (select auth.uid()) and public.sai_security_has_role('admin')
      and public.sai_security_branch_member(branch_id)))
  with check (public.sai_security_has_role('super_admin') or
    (user_id = (select auth.uid()) and public.sai_security_has_role('admin')));

-- A class assignment must never move a student across branches.
create function public.sai_management_validate_student_class()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (public.sai_security_has_role('super_admin') or
    (public.sai_security_has_role('admin') and public.sai_security_branch_member(new.branch_id))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if new.class_id is not null and not exists (
    select 1 from public.classes c
    where c.id = new.class_id and c.branch_id = new.branch_id
  ) then
    raise exception 'Invalid class or branch';
  end if;
  return new;
end;
$$;

revoke all on function public.sai_management_validate_student_class() from public, anon, authenticated;
create trigger students_validate_class_branch
  before insert or update of class_id, branch_id on public.students
  for each row execute function public.sai_management_validate_student_class();

-- The trigger runs in the same transaction as the mutation, and stores changed
-- column names instead of personal field values. Direct audit inserts from 002
-- remain untrusted and can imitate the metadata used by these entries.
create function public.sai_management_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_row jsonb := to_jsonb(new);
  old_row jsonb;
  changed_columns jsonb;
  target_id uuid;
begin
  if tg_op = 'UPDATE' then
    old_row := to_jsonb(old);
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed_columns
      from jsonb_each(new_row) as k
      where k.value is distinct from old_row -> k.key;
  else
    changed_columns := '[]'::jsonb;
  end if;
  target_id := case when tg_table_name = 'branch_memberships'
    then (new_row ->> 'branch_id')::uuid else (new_row ->> 'id')::uuid end;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (
    auth.uid(), lower(tg_op), tg_table_name, target_id,
    jsonb_build_object('source', 'sai_management_trigger',
      'changed_columns', changed_columns,
      'branch_id', case when tg_table_name = 'branches' then new_row -> 'id'
        else new_row -> 'branch_id' end,
      'membership_user_id', case when tg_table_name = 'branch_memberships'
        then new_row -> 'user_id' else null end)
  );
  return new;
end;
$$;

revoke all on function public.sai_management_audit_mutation() from public, anon, authenticated;
create trigger audit_branches_management after insert or update on public.branches
  for each row execute function public.sai_management_audit_mutation();
create trigger audit_sessions_management after insert or update on public.academic_sessions
  for each row execute function public.sai_management_audit_mutation();
create trigger audit_classes_management after insert or update on public.classes
  for each row execute function public.sai_management_audit_mutation();
create trigger audit_students_management after insert or update on public.students
  for each row execute function public.sai_management_audit_mutation();
create trigger audit_memberships_management after insert or update on public.branch_memberships
  for each row execute function public.sai_management_audit_mutation();
