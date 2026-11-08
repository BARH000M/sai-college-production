-- Prepared for isolated testing and review; do not apply automatically.
do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
end;
$$;

-- This directory does not broaden the general academic_sessions SELECT policy.
create or replace function public.sai_admissions_sessions(wanted_branch uuid)
returns table (id uuid, name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if wanted_branch is null or not exists (select 1 from public.branches b where b.id = wanted_branch)
    or not (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(wanted_branch)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query select s.id, s.name from public.academic_sessions s
    where s.is_active order by s.name, s.id;
end;
$$;
revoke all on function public.sai_admissions_sessions(uuid) from public, anon, authenticated;
grant execute on function public.sai_admissions_sessions(uuid) to authenticated;

-- Replace the deployed trigger function without changing its trigger or other checks.
create or replace function public.sai_admissions_prepare()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(new.branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' or new.academic_session_id is distinct from old.academic_session_id then
    if not exists (select 1 from public.academic_sessions s
      where s.id = new.academic_session_id and s.is_active) then
      raise exception 'Active session is required' using errcode = '23514';
    end if;
  end if;
  if new.assigned_to is not null and (tg_op = 'INSERT' or new.assigned_to is distinct from old.assigned_to) then
    if not exists (
      select 1 from public.branch_memberships m
      where m.user_id = new.assigned_to and m.branch_id = new.branch_id and m.is_active
        and exists (select 1 from public.user_roles r where r.user_id = m.user_id
          and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    ) then
      raise exception 'Assignee is not active staff in this branch';
    end if;
  end if;
  new.updated_at := now();
  if new.status in ('enrolled','rejected','withdrawn') then
    if tg_op = 'INSERT' then new.closed_at := now();
    elsif old.status not in ('enrolled','rejected','withdrawn') then new.closed_at := now();
    else new.closed_at := old.closed_at;
    end if;
  else
    new.closed_at := null;
  end if;
  return new;
end;
$$;
