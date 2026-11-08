-- Prepared for staging review; do not apply automatically.
do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
    or has_schema_privilege('anon', 'public', 'CREATE')
    or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
end;
$$;

create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  academic_session_id uuid not null references public.academic_sessions(id),
  class_id uuid not null references public.classes(id),
  attendance_date date not null,
  start_time timestamptz,
  end_time timestamptz,
  status text not null default 'open' check (status in ('open', 'closed', 'cancelled')),
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, attendance_date),
  check (start_time is null or end_time is null or end_time >= start_time)
);

create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  attendance_session_id uuid not null references public.attendance_sessions(id),
  student_id uuid not null references public.students(id),
  status text not null check (status in ('present', 'absent', 'late', 'excused')),
  note text,
  marked_by uuid not null default auth.uid() references auth.users(id),
  marked_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (attendance_session_id, student_id)
);

create index attendance_sessions_scope_idx on public.attendance_sessions(branch_id, academic_session_id, attendance_date desc);
create index attendance_records_student_idx on public.attendance_records(student_id, attendance_session_id);
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
revoke all on public.attendance_sessions, public.attendance_records from public, anon, authenticated;
grant select on public.attendance_sessions, public.attendance_records to authenticated;
grant insert (branch_id, academic_session_id, class_id, attendance_date, start_time, end_time)
  on public.attendance_sessions to authenticated;
grant update (status, start_time, end_time) on public.attendance_sessions to authenticated;
grant insert (attendance_session_id, student_id, status, note) on public.attendance_records to authenticated;
grant update (status, note) on public.attendance_records to authenticated;

create function public.sai_attendance_manage_class(wanted_class uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.classes c where c.id = wanted_class and (
      public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(c.branch_id) and (
        public.sai_security_has_role('admin')
        or (public.sai_security_has_role('teacher') and c.teacher_id = (select auth.uid()))
      ))
    )
  );
$$;

create function public.sai_attendance_view_record(wanted_session uuid, wanted_student uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.attendance_sessions a
    join public.students s on s.id = wanted_student
    where a.id = wanted_session and (
      public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id))
      or (public.sai_security_has_role('student') and s.user_id = (select auth.uid()))
      or (public.sai_security_has_role('parent') and exists (
        select 1 from public.parent_student_links l where l.student_id = s.id
          and l.parent_user_id = (select auth.uid()) and l.verified_at is not null
      ))
    )
  );
$$;

create function public.sai_attendance_view_session(wanted_session uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.attendance_sessions a where a.id = wanted_session and (
      public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id))
      or exists (select 1 from public.attendance_records r
        where r.attendance_session_id = a.id and public.sai_attendance_view_record(a.id, r.student_id))
    )
  );
$$;
revoke all on function public.sai_attendance_manage_class(uuid), public.sai_attendance_view_record(uuid, uuid),
  public.sai_attendance_view_session(uuid) from public, anon, authenticated;
grant execute on function public.sai_attendance_manage_class(uuid), public.sai_attendance_view_record(uuid, uuid),
  public.sai_attendance_view_session(uuid) to authenticated;

create policy attendance_sessions_read on public.attendance_sessions for select to authenticated
  using (public.sai_attendance_view_session(id));
create policy attendance_sessions_insert on public.attendance_sessions for insert to authenticated
  with check (public.sai_attendance_manage_class(class_id) and created_by = (select auth.uid()));
create policy attendance_sessions_update on public.attendance_sessions for update to authenticated
  using (public.sai_attendance_manage_class(class_id))
  with check (public.sai_attendance_manage_class(class_id));
create policy attendance_records_read on public.attendance_records for select to authenticated
  using (public.sai_attendance_view_record(attendance_session_id, student_id));
create policy attendance_records_insert on public.attendance_records for insert to authenticated
  with check (exists (select 1 from public.attendance_sessions a where a.id = attendance_session_id
    and public.sai_attendance_manage_class(a.class_id)));
create policy attendance_records_update on public.attendance_records for update to authenticated
  using (exists (select 1 from public.attendance_sessions a where a.id = attendance_session_id
    and (public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id)))))
  with check (exists (select 1 from public.attendance_sessions a where a.id = attendance_session_id
    and (public.sai_attendance_manage_class(a.class_id)
      or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(a.branch_id)))));

create function public.sai_attendance_prepare_session()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if not public.sai_attendance_manage_class(new.class_id) then
    raise exception 'Not authorized for this class' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and old.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if new.attendance_date > (now() at time zone 'Asia/Aden')::date then
    raise exception 'Future attendance date is not permitted' using errcode = '23514';
  end if;
  if not exists (select 1 from public.classes c where c.id = new.class_id
    and c.branch_id = new.branch_id and c.session_id = new.academic_session_id) then
    raise exception 'Class, branch and academic session do not match' using errcode = '23514';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
create trigger attendance_session_prepare before insert or update on public.attendance_sessions
  for each row execute function public.sai_attendance_prepare_session();

create function public.sai_attendance_prepare_record()
returns trigger language plpgsql security definer set search_path = public
as $$
declare session_row public.attendance_sessions%rowtype;
begin
  select * into session_row from public.attendance_sessions a
    where a.id = new.attendance_session_id for update;
  if not found then raise exception 'Attendance session not found' using errcode = '23503'; end if;
  if not (public.sai_attendance_manage_class(session_row.class_id)
    or (tg_op = 'UPDATE' and public.sai_security_has_role('receptionist')
      and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for this attendance' using errcode = '42501';
  end if;
  if session_row.status <> 'open' then
    raise exception 'Attendance session is read-only' using errcode = '23514';
  end if;
  if tg_op = 'INSERT' then
    perform 1 from public.students s where s.id = new.student_id
      and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id for share;
    if not found then
      raise exception 'Student does not belong to this class' using errcode = '23514';
    end if;
  end if;
  new.marked_by := auth.uid();
  new.marked_at := now();
  new.updated_at := now();
  return new;
end;
$$;
create trigger attendance_record_prepare before insert or update on public.attendance_records
  for each row execute function public.sai_attendance_prepare_record();

create function public.sai_attendance_audit()
returns trigger language plpgsql security definer set search_path = public
as $$
declare audit_action text;
begin
  if tg_table_name = 'attendance_sessions' then
    if tg_op = 'INSERT' then audit_action := 'create';
    elsif new.status = 'closed' then audit_action := 'close';
    elsif new.status = 'cancelled' then audit_action := 'cancel';
    else audit_action := 'update'; end if;
  elsif tg_op = 'INSERT' then audit_action := 'mark';
  else audit_action := 'correct'; end if;
  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
    values (auth.uid(), audit_action, tg_table_name, new.id,
      jsonb_build_object('source', 'sai_attendance_trigger'));
  return new;
end;
$$;
create trigger attendance_session_audit after insert or update on public.attendance_sessions
  for each row execute function public.sai_attendance_audit();
create trigger attendance_record_audit after insert or update on public.attendance_records
  for each row execute function public.sai_attendance_audit();
revoke all on function public.sai_attendance_prepare_session(), public.sai_attendance_prepare_record(),
  public.sai_attendance_audit() from public, anon, authenticated;

-- Only minimal class and roster data is exposed, with server-checked role scope.
create function public.sai_attendance_classes()
returns table (id uuid, name text, branch_id uuid, academic_session_id uuid, teacher_id uuid)
language sql stable security definer set search_path = public
as $$
  select c.id, c.name, c.branch_id, c.session_id, c.teacher_id
  from public.classes c where public.sai_attendance_manage_class(c.id)
    or (public.sai_security_has_role('receptionist') and public.sai_security_branch_member(c.branch_id))
    or public.sai_security_can_read_class(c.id)
  order by c.name, c.id;
$$;
create function public.sai_attendance_roster(wanted_session uuid)
returns table (student_id uuid, full_name text, record_id uuid, attendance_status text, note text)
language plpgsql stable security definer set search_path = public
as $$
declare session_row public.attendance_sessions%rowtype; manager boolean;
begin
  select * into session_row from public.attendance_sessions where id = wanted_session;
  if not found then raise exception 'Attendance session not found' using errcode = '42501'; end if;
  manager := public.sai_attendance_manage_class(session_row.class_id);
  if not (manager or (public.sai_security_has_role('receptionist')
    and public.sai_security_branch_member(session_row.branch_id))) then
    raise exception 'Not authorized for roster' using errcode = '42501';
  end if;
  return query select s.id, s.full_name, r.id, r.status, r.note
    from public.students s
    left join public.attendance_records r on r.student_id = s.id and r.attendance_session_id = wanted_session
    where (manager and s.class_id = session_row.class_id and s.branch_id = session_row.branch_id)
      or r.id is not null
    order by s.full_name, s.id;
end;
$$;
revoke all on function public.sai_attendance_classes(), public.sai_attendance_roster(uuid) from public, anon, authenticated;
grant execute on function public.sai_attendance_classes(), public.sai_attendance_roster(uuid) to authenticated;
