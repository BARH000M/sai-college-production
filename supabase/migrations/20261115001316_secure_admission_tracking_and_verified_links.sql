begin;

create table private.admission_tracking_tokens (
  enquiry_id uuid primary key references public.admissions_enquiries(id) on delete cascade,
  token_hash bytea not null unique,
  issued_by uuid references auth.users(id),
  issued_at timestamptz not null default now()
);

alter table private.admission_tracking_tokens enable row level security;
revoke all on table private.admission_tracking_tokens from public, anon, authenticated;

create table private.admission_tracking_rate_limits (
  scope text not null check (scope in ('submit', 'track', 'email')),
  client_key text not null check (client_key ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0),
  primary key (scope, client_key)
);

alter table private.admission_tracking_rate_limits enable row level security;
revoke all on table private.admission_tracking_rate_limits from public, anon, authenticated;

create function public.admissions_public_rate_limit(p_client_key text, p_scope text)
returns boolean
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, private
as $$
declare
  window_seconds integer;
  request_limit integer;
  current_count integer;
begin
  if p_client_key is null or p_client_key !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  case p_scope
    when 'submit' then window_seconds := 600; request_limit := 5;
    when 'track' then window_seconds := 600; request_limit := 30;
    when 'email' then window_seconds := 600; request_limit := 5;
    else return false;
  end case;

  insert into private.admission_tracking_rate_limits as limits (
    scope, client_key, window_started_at, request_count
  )
  values (p_scope, p_client_key, clock_timestamp(), 1)
  on conflict (scope, client_key) do update
  set window_started_at = case
        when limits.window_started_at <= clock_timestamp() - make_interval(secs => window_seconds)
          then clock_timestamp()
        else limits.window_started_at
      end,
      request_count = case
        when limits.window_started_at <= clock_timestamp() - make_interval(secs => window_seconds)
          then 1
        else limits.request_count + 1
      end
  returning request_count into current_count;

  if current_count % 100 = 0 then
    delete from private.admission_tracking_rate_limits
    where window_started_at < clock_timestamp() - interval '1 day';
  end if;

  return current_count <= request_limit;
end;
$$;

create function public.admissions_public_submit(
  p_full_name text,
  p_phone text,
  p_email text,
  p_program text,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_branch uuid;
  v_session uuid;
  v_creator uuid;
  v_enquiry_id uuid;
  v_reference text;
  v_token text;
  v_previous_subject text := current_setting('request.jwt.claim.sub', true);
begin
  if length(btrim(coalesce(p_full_name, ''))) < 2 or length(btrim(p_full_name)) > 120 then
    raise exception 'INVALID_NAME' using errcode = '22023';
  end if;
  if length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) < 6
    and nullif(btrim(coalesce(p_email, '')), '') is null then
    raise exception 'INVALID_CONTACT' using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_email, '')), '') is not null
    and btrim(p_email) !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'INVALID_EMAIL' using errcode = '22023';
  end if;
  if length(coalesce(p_program, '')) > 120 or length(coalesce(p_message, '')) > 500 then
    raise exception 'MESSAGE_TOO_LONG' using errcode = '22023';
  end if;

  select b.id into v_branch
  from public.branches b
  where b.is_active
  order by b.created_at, b.id
  limit 1;

  select s.id into v_session
  from public.academic_sessions s
  where s.is_active
  order by s.starts_on desc, s.id
  limit 1;

  if v_branch is null or v_session is null then
    raise exception 'NO_ACTIVE_TERM' using errcode = 'P0001';
  end if;

  select r.user_id into v_creator
  from public.user_roles r
  where r.role = 'super_admin'
  order by r.assigned_at, r.user_id
  limit 1;

  if v_creator is null then
    raise exception 'NO_ADMISSIONS_OWNER' using errcode = 'P0001';
  end if;

  v_token := encode(pg_catalog.sha256(convert_to(
    pg_catalog.gen_random_uuid()::text || pg_catalog.gen_random_uuid()::text || pg_catalog.gen_random_uuid()::text,
    'UTF8'
  )), 'hex');

  begin
    perform set_config('request.jwt.claim.sub', v_creator::text, true);
    insert into public.admissions_enquiries (
      branch_id, academic_session_id, applicant_full_name, phone, email,
      preferred_program, source, notes, status, created_by
    )
    values (
      v_branch,
      v_session,
      btrim(p_full_name),
      nullif(btrim(p_phone), ''),
      lower(nullif(btrim(p_email), '')),
      nullif(btrim(p_program), ''),
      'website',
      nullif(btrim(p_message), ''),
      'new',
      v_creator
    )
    returning id, application_no into v_enquiry_id, v_reference;
    perform set_config('request.jwt.claim.sub', coalesce(v_previous_subject, ''), true);
  exception when others then
    perform set_config('request.jwt.claim.sub', coalesce(v_previous_subject, ''), true);
    raise;
  end;

  insert into private.admission_tracking_tokens (enquiry_id, token_hash)
  values (v_enquiry_id, pg_catalog.sha256(convert_to(v_token, 'UTF8')));

  return jsonb_build_object('reference', v_reference, 'tracking_token', v_token);
end;
$$;

create function public.admissions_public_status(p_reference text, p_tracking_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  result jsonb;
begin
  if p_reference is null or length(btrim(p_reference)) < 6 or length(btrim(p_reference)) > 80
    or p_tracking_token is null or p_tracking_token !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  select jsonb_build_object(
    'status', e.status,
    'submitted_at', e.created_at,
    'status_updated_at', e.updated_at
  )
  into result
  from public.admissions_enquiries e
  join private.admission_tracking_tokens t on t.enquiry_id = e.id
  where upper(e.application_no) = upper(btrim(p_reference))
    and t.token_hash = pg_catalog.sha256(convert_to(p_tracking_token, 'UTF8'))
  limit 1;

  return result;
end;
$$;

create function public.admissions_public_history(p_reference text, p_tracking_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  enquiry_id uuid;
  result jsonb;
begin
  if p_reference is null or length(btrim(p_reference)) < 6 or length(btrim(p_reference)) > 80
    or p_tracking_token is null or p_tracking_token !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  select e.id into enquiry_id
  from public.admissions_enquiries e
  join private.admission_tracking_tokens t on t.enquiry_id = e.id
  where upper(e.application_no) = upper(btrim(p_reference))
    and t.token_hash = pg_catalog.sha256(convert_to(p_tracking_token, 'UTF8'))
  limit 1;

  if enquiry_id is null then
    return null;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'action', a.action,
    'status', coalesce(nullif(a.metadata ->> 'new_status', ''), 'new'),
    'occurred_at', a.created_at
  ) order by a.created_at, a.id), '[]'::jsonb)
  into result
  from public.audit_logs a
  where a.entity_type = 'admissions_enquiries'
    and a.entity_id = enquiry_id
    and a.action in ('insert', 'status_change');

  return result;
end;
$$;

create function public.admissions_issue_tracking_token(p_enquiry_id uuid)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_branch uuid;
  v_actor uuid := auth.uid();
  v_token text;
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select e.branch_id into v_branch
  from public.admissions_enquiries e
  where e.id = p_enquiry_id
  for update;

  if not found then
    raise exception 'Admission enquiry not found' using errcode = 'P0002';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_has_role('admin')
      and private.sai_security_branch_member(v_branch)
    )
  ) then
    raise exception 'Not authorized to issue an applicant tracking token' using errcode = '42501';
  end if;

  v_token := encode(pg_catalog.sha256(convert_to(
    pg_catalog.gen_random_uuid()::text || pg_catalog.gen_random_uuid()::text || pg_catalog.gen_random_uuid()::text,
    'UTF8'
  )), 'hex');
  insert into private.admission_tracking_tokens (enquiry_id, token_hash, issued_by, issued_at)
  values (p_enquiry_id, pg_catalog.sha256(convert_to(v_token, 'UTF8')), v_actor, now())
  on conflict (enquiry_id) do update
  set token_hash = excluded.token_hash,
      issued_by = excluded.issued_by,
      issued_at = excluded.issued_at;

  return v_token;
end;
$$;

create function public.admissions_link_student_account(p_student_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth
as $$
declare
  v_actor uuid := auth.uid();
  v_branch uuid;
  v_email text;
  v_name text;
begin
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
    raise exception 'Not authorized to link accounts for this branch' using errcode = '42501';
  end if;

  select u.email,
         coalesce(nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''), u.email, 'Student')
  into v_email, v_name
  from auth.users u
  where u.id = p_user_id
    and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null);

  if not found then
    raise exception 'A verified Auth account is required' using errcode = '22023';
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
        and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
    ) then
      raise exception 'A verified Auth account is required' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.admissions_guard_student_account_link() from public, anon, authenticated;
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
      and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
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
      and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null)
  ) then
    raise exception 'A verified parent Auth account and staff verification are required'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function private.admissions_guard_parent_link() from public, anon, authenticated;
create trigger parent_student_links_guard_verification
  before insert or update on public.parent_student_links
  for each row execute function private.admissions_guard_parent_link();

revoke insert, update, delete, truncate on public.parent_student_links from public, anon, authenticated;

revoke all on function public.admissions_public_rate_limit(text, text) from public, anon, authenticated;
grant execute on function public.admissions_public_rate_limit(text, text) to service_role;

revoke all on function public.admissions_public_submit(text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.admissions_public_submit(text, text, text, text, text) to service_role;

revoke all on function public.admissions_public_status(text, text) from public, anon, authenticated;
grant execute on function public.admissions_public_status(text, text) to service_role;

revoke all on function public.admissions_public_history(text, text) from public, anon, authenticated;
grant execute on function public.admissions_public_history(text, text) to service_role;

revoke all on function public.admissions_issue_tracking_token(uuid) from public, anon, authenticated;
grant execute on function public.admissions_issue_tracking_token(uuid) to authenticated;

revoke all on function public.admissions_link_student_account(uuid, uuid) from public, anon, authenticated;
grant execute on function public.admissions_link_student_account(uuid, uuid) to authenticated;

revoke all on function public.admissions_unlink_student_account(uuid) from public, anon, authenticated;
grant execute on function public.admissions_unlink_student_account(uuid) to authenticated;

revoke all on function public.admissions_list_parent_links(uuid) from public, anon, authenticated;
grant execute on function public.admissions_list_parent_links(uuid) to authenticated;

revoke all on function public.admissions_verify_parent_student(uuid, uuid) from public, anon, authenticated;
grant execute on function public.admissions_verify_parent_student(uuid, uuid) to authenticated;

do $$
begin
  if to_regprocedure('public.sai_public_admission_status(text)') is not null then
    execute 'revoke all on function public.sai_public_admission_status(text) from public, anon, authenticated';
  end if;
  if to_regprocedure('public.sai_public_admission_history(text)') is not null then
    execute 'revoke all on function public.sai_public_admission_history(text) from public, anon, authenticated';
  end if;
  if to_regprocedure('public.sai_public_admission_submit(text, text, text, text, text)') is not null then
    execute 'revoke all on function public.sai_public_admission_submit(text, text, text, text, text) from public, anon, authenticated';
  end if;
end;
$$;

commit;