-- REVIEW ONLY. Main-compatible linking slice; requires 01. No tracking or settings changes.
begin;
create function public.admissions_link_student_account(p_student_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_branch uuid;
  v_previous_user uuid;
  v_email text;
  v_name text;
begin
  perform pg_catalog.pg_advisory_xact_lock(831704, 1);
  if not exists(select 1 from auth.users u where u.id=auth.uid()
    and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=now())) then
    raise exception 'Usable authenticated staff required' using errcode='42501';
  end if;
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select s.branch_id,s.user_id into v_branch,v_previous_user
  from public.students s
  where s.id = p_student_id
  for update;

  if not found then
    raise exception 'Student record not found' using errcode = 'P0002';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_has_role('admin')
      and private.sai_security_branch_member(v_branch)
    )
  ) then
    raise exception 'Not authorized to link accounts for this branch' using errcode = '42501';
  end if;

  select u.email,
         coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), u.email, 'Student')
  into v_email, v_name
  from auth.users u
  where u.id = p_user_id
    and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now());

  if not found then
    raise exception 'A verified Auth account is required' using errcode = '22023';
  end if;

  if v_previous_user is not null and v_previous_user is distinct from p_user_id then
    raise exception 'Student already linked; unlink explicitly first' using errcode='23505';
  end if;
  insert into public.profiles (id, full_name, email)
  values (p_user_id, v_name, v_email)
  on conflict (id) do nothing;

  perform set_config('sai.student_account_link', 'on', true);
  update public.students set user_id = p_user_id where id = p_student_id;
  perform set_config('sai.student_account_link', 'off', true);

  insert into public.user_roles (user_id, role, assigned_by)
  values (p_user_id, 'student', v_actor)
  on conflict (user_id, role) do nothing;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_actor, 'student_account_link', 'students', p_student_id,
    jsonb_build_object('user_id', p_user_id, 'source', 'admissions'));

  return jsonb_build_object('student_id', p_student_id, 'user_id', p_user_id);
end;
$$;

create function public.admissions_unlink_student_account(p_student_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_branch uuid;
  v_previous_user uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(831704, 1);
  if not exists(select 1 from auth.users u where u.id=auth.uid()
    and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=now())) then
    raise exception 'Usable authenticated staff required' using errcode='42501';
  end if;
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select s.branch_id, s.user_id into v_branch, v_previous_user
  from public.students s
  where s.id = p_student_id
  for update;

  if not found then
    raise exception 'Student record not found' using errcode = 'P0002';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_has_role('admin')
      and private.sai_security_branch_member(v_branch)
    )
  ) then
    raise exception 'Not authorized to unlink accounts for this branch' using errcode = '42501';
  end if;

  if v_previous_user is not null then
    perform set_config('sai.student_account_link', 'on', true);
    update public.students set user_id = null where id = p_student_id;
    perform set_config('sai.student_account_link', 'off', true);

    insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
    values (v_actor, 'student_account_unlink', 'students', p_student_id,
      jsonb_build_object('previous_user_id', v_previous_user, 'source', 'admissions'));
  end if;
end;
$$;

create function private.admissions_guard_student_account_link()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
begin
  if (tg_op = 'INSERT' and new.user_id is not null)
    or (tg_op = 'UPDATE' and new.user_id is distinct from old.user_id) then
    if current_setting('sai.student_account_link', true) is distinct from 'on' then
      raise exception 'Use the authorized student-account linking workflow' using errcode = '42501';
    end if;
    if new.user_id is not null and not exists (
      select 1 from auth.users u
      where u.id = new.user_id
        and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now())
    ) then
      raise exception 'A verified Auth account is required' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.admissions_guard_student_account_link() from public, anon, authenticated, service_role;
create trigger students_guard_account_link
  before insert or update of user_id on public.students
  for each row execute function private.admissions_guard_student_account_link();

create function public.admissions_list_parent_links(p_student_id uuid)
returns table (
  parent_user_id uuid,
  full_name text,
  email text,
  is_verified boolean,
  verified_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_branch uuid;
begin
  select s.branch_id into v_branch
  from public.students s
  where s.id = p_student_id;

  if not found then
    raise exception 'Student record not found' using errcode = 'P0002';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_has_role('admin')
      and private.sai_security_branch_member(v_branch)
    )
  ) then
    raise exception 'Not authorized to review parent links for this branch' using errcode = '42501';
  end if;

  return query
  select l.parent_user_id, p.full_name, p.email, l.verified_at is not null, l.verified_at
  from public.parent_student_links l
  join public.profiles p on p.id = l.parent_user_id
  where l.student_id = p_student_id
  order by p.full_name, l.parent_user_id;
end;
$$;

create function public.admissions_verify_parent_student(p_student_id uuid, p_parent_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_branch uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(831704, 1);
  if not exists(select 1 from auth.users u where u.id=auth.uid()
    and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=now())) then
    raise exception 'Usable authenticated staff required' using errcode='42501';
  end if;
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select s.branch_id into v_branch
  from public.students s
  where s.id = p_student_id
  for update;

  if not found then
    raise exception 'Student record not found' using errcode = 'P0002';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_has_role('admin')
      and private.sai_security_branch_member(v_branch)
    )
  ) then
    raise exception 'Not authorized to verify parent links for this branch' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from auth.users u
    join public.user_roles r on r.user_id = u.id and r.role = 'parent'
    where u.id = p_parent_user_id
      and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now())
  ) then
    raise exception 'A verified parent Auth account is required' using errcode = '22023';
  end if;

  perform set_config('sai.parent_link_verification', 'on', true);
  insert into public.parent_student_links (parent_user_id, student_id, verified_at, verified_by)
  values (p_parent_user_id, p_student_id, now(), v_actor)
  on conflict (parent_user_id, student_id) do update
  set verified_at = excluded.verified_at,
      verified_by = excluded.verified_by;
  perform set_config('sai.parent_link_verification', 'off', true);

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_actor, 'parent_student_link_verified', 'students', p_student_id,
    jsonb_build_object('parent_user_id', p_parent_user_id, 'source', 'admissions'));
end;
$$;

create function private.admissions_guard_parent_link()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
begin
  if current_setting('sai.parent_link_verification', true) is distinct from 'on' then
    raise exception 'Use the authorized parent-link verification workflow' using errcode = '42501';
  end if;
  if new.verified_at is null or new.verified_by is null or not exists (
    select 1
    from auth.users u
    join public.user_roles r on r.user_id = u.id and r.role = 'parent'
    where u.id = new.parent_user_id
      and u.email_confirmed_at is not null and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= now())
  ) then
    raise exception 'A verified parent Auth account and staff verification are required'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function private.admissions_guard_parent_link() from public, anon, authenticated, service_role;
create trigger parent_student_links_guard_verification
  before insert or update on public.parent_student_links
  for each row execute function private.admissions_guard_parent_link();

revoke insert, update, delete, truncate on public.parent_student_links from public, anon, authenticated;

revoke all on function public.admissions_link_student_account(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admissions_link_student_account(uuid,uuid) to authenticated;
revoke all on function public.admissions_unlink_student_account(uuid) from public,anon,authenticated,service_role;
grant execute on function public.admissions_unlink_student_account(uuid) to authenticated;
revoke all on function public.admissions_list_parent_links(uuid) from public,anon,authenticated,service_role;
grant execute on function public.admissions_list_parent_links(uuid) to authenticated;
revoke all on function public.admissions_verify_parent_student(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admissions_verify_parent_student(uuid,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
