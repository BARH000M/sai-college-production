-- Prepared for isolated testing and review. Do not apply automatically.
do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
end;
$$;

create table public.admissions_enquiries (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  application_no text not null unique default ('ADM-' || gen_random_uuid()::text),
  applicant_full_name text not null check (length(btrim(applicant_full_name)) > 0),
  guardian_name text,
  phone text,
  email text,
  preferred_program text,
  preferred_level text,
  source text,
  notes text,
  status text not null default 'new'
    check (status in ('new','contacted','assessment','accepted','enrolled','rejected','withdrawn')),
  assigned_to uuid references auth.users(id),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);

create index admissions_scope_idx on public.admissions_enquiries(branch_id, academic_session_id, status, created_at desc);
create index admissions_assignee_idx on public.admissions_enquiries(assigned_to, branch_id);
alter table public.admissions_enquiries enable row level security;
revoke all on public.admissions_enquiries from public, anon, authenticated;
grant select on public.admissions_enquiries to authenticated;
grant insert (branch_id, academic_session_id, applicant_full_name, guardian_name, phone, email,
  preferred_program, preferred_level, source, notes, assigned_to)
  on public.admissions_enquiries to authenticated;
grant update (academic_session_id, applicant_full_name, guardian_name, phone, email,
  preferred_program, preferred_level, source, notes, status, assigned_to)
  on public.admissions_enquiries to authenticated;

create policy admissions_select_authorized on public.admissions_enquiries
  for select to authenticated using (
    public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(branch_id) and (
      public.sai_security_has_role('admin')
      or public.sai_security_has_role('receptionist')
      or (public.sai_security_has_role('teacher') and assigned_to = (select auth.uid()))
    ))
  );
create policy admissions_insert_staff on public.admissions_enquiries
  for insert to authenticated with check (
    created_by = (select auth.uid()) and status = 'new'
    and (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(branch_id)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist'))))
  );
create policy admissions_update_staff on public.admissions_enquiries
  for update to authenticated using (
    public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))
  ) with check (
    public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))
  );

-- Only an authorized admissions manager can enumerate active branch staff.
create function public.sai_admissions_staff(wanted_branch uuid)
returns table (user_id uuid, full_name text)
language plpgsql stable security definer set search_path = public
as $$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(wanted_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  return query
    select m.user_id, p.full_name
    from public.branch_memberships m
    join public.profiles p on p.id = m.user_id
    where m.branch_id = wanted_branch and m.is_active
      and exists (select 1 from public.user_roles r where r.user_id = m.user_id
        and r.role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor'))
    order by p.full_name, m.user_id;
end;
$$;
revoke all on function public.sai_admissions_staff(uuid) from public, anon, authenticated;
grant execute on function public.sai_admissions_staff(uuid) to authenticated;

-- Column grants protect immutable fields; trigger validates server-side scope,
-- assignment and lifecycle timestamps even for requests outside the UI.
create function public.sai_admissions_prepare()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(new.branch_id)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' or new.academic_session_id is distinct from old.academic_session_id then
    if not public.sai_security_can_read_session(new.academic_session_id) then
      raise exception 'Session is not available' using errcode = '42501';
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
revoke all on function public.sai_admissions_prepare() from public, anon, authenticated;
create trigger admissions_prepare before insert or update on public.admissions_enquiries
  for each row execute function public.sai_admissions_prepare();

create function public.sai_admissions_audit()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  changed jsonb := '[]'::jsonb;
  old_status text;
begin
  if tg_op = 'UPDATE' then
    old_status := old.status;
    select coalesce(jsonb_agg(k.key order by k.key), '[]'::jsonb)
      into changed from jsonb_each(to_jsonb(new)) k
      where k.value is distinct from to_jsonb(old) -> k.key;
  end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (auth.uid(), case when tg_op = 'UPDATE' and old.status is distinct from new.status
      then 'status_change' else lower(tg_op) end,
    'admissions_enquiries', new.id,
    jsonb_build_object('source', 'sai_admissions_trigger', 'branch_id', new.branch_id,
      'changed_columns', changed, 'old_status', old_status, 'new_status', new.status));
  return new;
end;
$$;
revoke all on function public.sai_admissions_audit() from public, anon, authenticated;
create trigger admissions_audit after insert or update on public.admissions_enquiries
  for each row execute function public.sai_admissions_audit();
