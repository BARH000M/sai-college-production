--
-- PostgreSQL database dump
--

\restrict XwtrCe5WBcfVAHY6UE2XcgynDJPNm9ba8ep7fl8K6TomhXW9KueQ2Fo8Ig0APJA

-- Dumped from database version 17.11
-- Dumped by pg_dump version 17.11

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: app_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.app_role AS ENUM (
    'super_admin',
    'admin',
    'teacher',
    'accountant',
    'receptionist',
    'librarian',
    'student',
    'parent',
    'content_editor'
);


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: sai_admission_history(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admission_history(p_enquiry_id uuid) RETURNS TABLE(entry_id uuid, action text, old_status text, new_status text, changed_columns jsonb, actor_id uuid, actor_name text, occurred_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_branch uuid;
begin
  select e.branch_id into v_branch from public.admissions_enquiries e where e.id = p_enquiry_id;
  if v_branch is null then
    raise exception 'Enquiry not found' using errcode = 'P0002';
  end if;
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(v_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;

  return query
    select a.id,
           a.action,
           nullif(a.metadata ->> 'old_status', ''),
           nullif(a.metadata ->> 'new_status', ''),
           coalesce(a.metadata -> 'changed_columns', '[]'::jsonb),
           a.actor_user_id,
           coalesce(nullif(btrim(p.full_name), ''), 'النظام'),
           a.created_at
    from public.audit_logs a
    left join public.profiles p on p.id = a.actor_user_id
    where a.entity_type = 'admissions_enquiries'
      and a.entity_id = p_enquiry_id
    order by a.created_at, a.id;
end;
$$;


--
-- Name: sai_admission_history_export(uuid, timestamp with time zone, timestamp with time zone, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admission_history_export(p_branch uuid DEFAULT NULL::uuid, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_enquiry_id uuid DEFAULT NULL::uuid) RETURNS TABLE(application_no text, applicant_full_name text, branch_name text, action text, old_status text, new_status text, changed_columns text, actor_name text, occurred_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_super boolean := public.sai_security_has_role('super_admin');
begin
  if p_enquiry_id is not null then
    if not (v_super or (public.sai_security_branch_member(
        (select e.branch_id from public.admissions_enquiries e where e.id = p_enquiry_id))
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
      raise exception 'Not authorized for this enquiry' using errcode = '42501';
    end if;
  elsif not v_super then
    if p_branch is null then
      raise exception 'Branch is required' using errcode = '22023';
    end if;
    if not (public.sai_security_branch_member(p_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist'))) then
      raise exception 'Not authorized for this branch' using errcode = '42501';
    end if;
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           b.name,
           a.action,
           nullif(a.metadata ->> 'old_status', ''),
           nullif(a.metadata ->> 'new_status', ''),
           (select string_agg(t.item, ', ')
              from jsonb_array_elements_text(coalesce(a.metadata -> 'changed_columns', '[]'::jsonb)) as t(item)),
           coalesce(nullif(btrim(p.full_name), ''), 'النظام'),
           a.created_at
      from public.audit_logs a
      join public.admissions_enquiries e on e.id = a.entity_id
      left join public.profiles p on p.id = a.actor_user_id
      left join public.branches b on b.id = e.branch_id
     where a.entity_type = 'admissions_enquiries'
       and (p_enquiry_id is null or e.id = p_enquiry_id)
       and (p_branch is null or e.branch_id = p_branch)
       and (p_from is null or a.created_at >= p_from)
       and (p_to is null or a.created_at <= p_to)
     order by a.created_at, a.id;
end;
$$;


--
-- Name: sai_admission_reminder_candidates(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admission_reminder_candidates() RETURNS TABLE(enquiry_id uuid, application_no text, applicant_full_name text, email text, phone text, preferred_program text, preferred_level text, branch_name text, session_name text, status text, created_at timestamp with time zone, days_open integer)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_claim_role text := current_setting('request.jwt.claim.role', true);
begin
  -- Only the server (service role) or a direct database session may read applicant contacts.
  if coalesce(v_claim_role, '') not in ('', 'service_role') then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  return query
    select e.id,
           e.application_no,
           e.applicant_full_name,
           e.email,
           e.phone,
           e.preferred_program,
           e.preferred_level,
           b.name,
           s.name,
           e.status,
           e.created_at,
           (now()::date - e.created_at::date)
      from public.admissions_enquiries e
      left join public.branches b on b.id = e.branch_id
      left join public.academic_sessions s on s.id = e.academic_session_id
     where e.status = 'new'
       and e.created_at <= now() - interval '3 days'
       and not exists (
         select 1 from public.admission_reminder_log l
          where l.enquiry_id = e.id and l.reminder_kind = 'stale_new'
       )
     order by e.created_at;
end;
$$;


--
-- Name: sai_admission_roster_export(uuid, uuid, text, timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admission_roster_export(p_branch uuid DEFAULT NULL::uuid, p_session uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(application_no text, applicant_full_name text, guardian_name text, phone text, email text, preferred_program text, preferred_level text, branch_name text, session_name text, status text, assigned_name text, source text, notes text, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_super boolean := public.sai_security_has_role('super_admin');
begin
  if not v_super then
    if not (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')) then
      raise exception 'Not authorized to export admissions' using errcode = '42501';
    end if;
    if p_branch is null then
      raise exception 'Branch is required' using errcode = '22023';
    end if;
    if not public.sai_security_branch_member(p_branch) then
      raise exception 'Not authorized for this branch' using errcode = '42501';
    end if;
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           e.guardian_name,
           e.phone,
           e.email,
           e.preferred_program,
           e.preferred_level,
           b.name,
           s.name,
           e.status,
           coalesce(nullif(btrim(p.full_name), ''), 'غير مسند'),
           e.source,
           e.notes,
           e.created_at,
           e.updated_at
      from public.admissions_enquiries e
      left join public.branches b on b.id = e.branch_id
      left join public.academic_sessions s on s.id = e.academic_session_id
      left join public.profiles p on p.id = e.assigned_to
     where (p_branch is null or e.branch_id = p_branch)
       and (p_session is null or e.academic_session_id = p_session)
       and (p_status is null or e.status = p_status)
       and (p_from is null or e.created_at >= p_from)
       and (p_to is null or e.created_at <= p_to)
     order by e.created_at, e.id;
end;
$$;


--
-- Name: sai_admission_status_email_context(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admission_status_email_context(p_enquiry_id uuid) RETURNS TABLE(application_no text, applicant_full_name text, email text, status text, previous_status text, preferred_program text, preferred_level text, branch_name text, session_name text, occurrence timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_branch uuid;
begin
  select e.branch_id into v_branch from public.admissions_enquiries e where e.id = p_enquiry_id;
  if v_branch is null then
    raise exception 'Enquiry not found' using errcode = 'P0002';
  end if;
  if not (public.sai_security_has_role('super_admin')
    or (public.sai_security_branch_member(v_branch)
      and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;

  return query
    select e.application_no,
           e.applicant_full_name,
           e.email,
           e.status,
           (select nullif(a.metadata ->> 'old_status', '')
              from public.audit_logs a
             where a.entity_type = 'admissions_enquiries'
               and a.entity_id = e.id
               and a.action = 'status_change'
             order by a.created_at desc, a.id desc
             limit 1),
           e.preferred_program,
           e.preferred_level,
           (select b.name from public.branches b where b.id = e.branch_id),
           (select s.name from public.academic_sessions s where s.id = e.academic_session_id),
           e.updated_at
      from public.admissions_enquiries e
     where e.id = p_enquiry_id;
end;
$$;


--
-- Name: sai_admissions_audit(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_audit() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sai_admissions_prepare(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_prepare() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if coalesce(current_setting('sai.public_web_enquiry', true), '') <> 'on' then
    if not (public.sai_security_has_role('super_admin')
      or (public.sai_security_branch_member(new.branch_id)
        and (public.sai_security_has_role('admin') or public.sai_security_has_role('receptionist')))) then
      raise exception 'Not authorized for this branch' using errcode = '42501';
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
  end if;
  if tg_op = 'INSERT' or new.academic_session_id is distinct from old.academic_session_id then
    if not exists (select 1 from public.academic_sessions s
      where s.id = new.academic_session_id and s.is_active) then
      raise exception 'Active session is required' using errcode = '23514';
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


--
-- Name: sai_admissions_staff(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_staff(wanted_branch uuid) RETURNS TABLE(user_id uuid, full_name text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sai_admissions_stale_new_count(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_admissions_stale_new_count(p_branch uuid DEFAULT NULL::uuid) RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_count integer;
begin
  if p_branch is null then
    if not public.sai_security_has_role('super_admin'::app_role) then
      raise exception 'Not authorized' using errcode = '42501';
    end if;
  elsif not public.sai_security_can_read_branch(p_branch) then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  select count(*)::integer into v_count
    from public.admissions_enquiries e
   where e.status = 'new'
     and e.created_at <= now() - interval '3 days'
     and (p_branch is null or e.branch_id = p_branch);

  return coalesce(v_count, 0);
end;
$$;


--
-- Name: sai_directory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_directory() RETURNS TABLE(user_id uuid, full_name text, email text, preferred_locale text, has_profile boolean, signed_up_at timestamp with time zone, roles text[])
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not public.sai_security_has_role('super_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
    select u.id,
           coalesce(nullif(p.full_name, ''),
                    nullif(u.raw_user_meta_data ->> 'full_name', ''),
                    u.email::text,
                    'Unnamed account')::text as full_name,
           coalesce(p.email, u.email)::text as email,
           coalesce(p.preferred_locale, 'ar')::text as preferred_locale,
           (p.id is not null) as has_profile,
           u.created_at as signed_up_at,
           coalesce((select array_agg(r.role::text) from public.user_roles r where r.user_id = u.id),
                    array[]::text[]) as roles
    from auth.users u
    left join public.profiles p on p.id = u.id
    order by 2;
end;
$$;


--
-- Name: sai_management_audit_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_management_audit_mutation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sai_management_validate_student_class(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_management_validate_student_class() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sai_probe_fn(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_probe_fn() RETURNS integer
    LANGUAGE sql
    AS $$ SELECT 1 $$;


--
-- Name: sai_public_admission_history(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_public_admission_history(p_reference text) RETURNS TABLE(action text, new_status text, occurred_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_id uuid;
begin
  if p_reference is null or length(btrim(p_reference)) < 6 then
    raise exception 'INVALID_REFERENCE' using errcode = '22023';
  end if;

  select e.id into v_id
  from public.admissions_enquiries e
  where upper(e.application_no) = upper(btrim(p_reference))
  limit 1;

  if v_id is null then
    return;
  end if;

  return query
    select a.action,
           coalesce(nullif(a.metadata ->> 'new_status', ''), 'new'),
           a.created_at
    from public.audit_logs a
    where a.entity_type = 'admissions_enquiries'
      and a.entity_id = v_id
      and a.action in ('insert', 'status_change')
    order by a.created_at, a.id;
end;
$$;


--
-- Name: sai_public_admission_status(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_public_admission_status(p_reference text) RETURNS TABLE(application_no text, applicant_name text, program text, level text, status text, branch_name text, session_name text, submitted_at timestamp with time zone, status_updated_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_reference is null or length(btrim(p_reference)) < 6 then
    raise exception 'INVALID_REFERENCE' using errcode = '22023';
  end if;
  return query
    select e.application_no,
           e.applicant_full_name,
           e.preferred_program,
           e.preferred_level,
           e.status,
           b.name,
           s.name,
           e.created_at,
           e.updated_at
    from public.admissions_enquiries e
    join public.branches b on b.id = e.branch_id
    join public.academic_sessions s on s.id = e.academic_session_id
    where upper(e.application_no) = upper(btrim(p_reference))
    limit 1;
end;
$$;


--
-- Name: sai_public_admission_submit(text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_public_admission_submit(p_full_name text, p_phone text, p_email text, p_program text, p_message text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_branch uuid;
  v_session uuid;
  v_creator uuid;
  v_ref text;
begin
  if length(btrim(coalesce(p_full_name, ''))) < 2 then
    raise exception 'INVALID_NAME' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_phone, ''))) < 6 then
    raise exception 'INVALID_PHONE' using errcode = '22023';
  end if;
  if btrim(coalesce(p_email, '')) <> '' and p_email !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'INVALID_EMAIL' using errcode = '22023';
  end if;
  if length(coalesce(p_message, '')) > 500 then
    raise exception 'MESSAGE_TOO_LONG' using errcode = '22023';
  end if;

  select b.id into v_branch from public.branches b
    where b.is_active order by b.created_at, b.id limit 1;
  select s.id into v_session from public.academic_sessions s
    where s.is_active order by s.starts_on desc, s.id limit 1;
  if v_branch is null or v_session is null then
    raise exception 'NO_ACTIVE_TERM' using errcode = 'P0001';
  end if;
  select r.user_id into v_creator from public.user_roles r
    where r.role = 'super_admin' order by r.assigned_at, r.user_id limit 1;
  if v_creator is null then
    raise exception 'NO_ADMISSIONS_OWNER' using errcode = 'P0001';
  end if;

  perform set_config('sai.public_web_enquiry', 'on', true);
  insert into public.admissions_enquiries (
    branch_id, academic_session_id, applicant_full_name, phone, email,
    preferred_program, source, notes, status, created_by
  ) values (
    v_branch, v_session, btrim(p_full_name), nullif(btrim(p_phone), ''), nullif(btrim(p_email), ''),
    nullif(btrim(p_program), ''), 'website', nullif(left(coalesce(p_message, ''), 500), ''), 'new', v_creator
  ) returning application_no into v_ref;
  perform set_config('sai.public_web_enquiry', 'off', true);

  return v_ref;
end;
$_$;


--
-- Name: sai_security_branch_member(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_branch_member(wanted_branch uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$$;


--
-- Name: sai_security_can_read_branch(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_branch(wanted_branch uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.sai_security_has_role('super_admin')
    or (
      public.sai_security_branch_member(wanted_branch)
      and exists (
        select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and r.role in (
            'admin', 'teacher', 'accountant', 'receptionist',
            'librarian', 'content_editor'
          )
      )
    )
    or exists (
      select 1 from public.students s
      where s.branch_id = wanted_branch
        and (
          (public.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            public.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$$;


--
-- Name: sai_security_can_read_class(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_class(wanted_class uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(c.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and public.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (public.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                public.sai_security_has_role('parent')
                and exists (
                  select 1 from public.parent_student_links l
                  where l.student_id = s.id
                    and l.parent_user_id = (select auth.uid())
                    and l.verified_at is not null
                )
              )
            )
        )
      )
  );
$$;


--
-- Name: sai_security_can_read_session(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_session(wanted_session uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select public.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and public.sai_security_can_read_class(c.id)
    );
$$;


--
-- Name: sai_security_can_read_student(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_can_read_student(wanted_student uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(s.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and public.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          public.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          public.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$$;


--
-- Name: sai_security_has_role(public.app_role); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_security_has_role(wanted_role public.app_role) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$$;


--
-- Name: sai_set_role(uuid, public.app_role, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_set_role(p_user_id uuid, p_role public.app_role, p_enabled boolean) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_me uuid := auth.uid();
begin
  if not public.sai_security_has_role('super_admin') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_user_id is null then
    raise exception 'invalid_user' using errcode = '22023';
  end if;

  if p_enabled then
    if not exists (select 1 from auth.users u where u.id = p_user_id) then
      raise exception 'unknown_user' using errcode = '22023';
    end if;
    if not exists (select 1 from public.profiles p where p.id = p_user_id) then
      insert into public.profiles (id, full_name, email, preferred_locale)
      select u.id,
             coalesce(nullif(u.raw_user_meta_data ->> 'full_name', ''), u.email, 'New account'),
             u.email,
             'ar'
      from auth.users u
      where u.id = p_user_id;
    end if;

    insert into public.user_roles (user_id, role, assigned_by)
    values (p_user_id, p_role, v_me)
    on conflict (user_id, role) do nothing;

    if p_role in ('super_admin', 'admin', 'receptionist') then
      insert into public.branch_memberships (user_id, branch_id, is_active)
      select p_user_id, b.id, true
      from public.branches b
      where not exists (
        select 1 from public.branch_memberships m where m.user_id = p_user_id and m.branch_id = b.id
      );
    elsif p_role in ('teacher', 'accountant', 'librarian', 'content_editor') then
      insert into public.branch_memberships (user_id, branch_id, is_active)
      select p_user_id, b.id, true
      from public.branches b
      where b.is_active
        and not exists (
          select 1 from public.branch_memberships m where m.user_id = p_user_id and m.branch_id = b.id
        );
    end if;
  else
    if p_user_id = v_me and p_role = 'super_admin' then
      raise exception 'cannot_remove_own_super_admin' using errcode = '42501';
    end if;
    delete from public.user_roles where user_id = p_user_id and role = p_role;
  end if;

  insert into public.audit_logs (actor_user_id, action, entity_type, entity_id, metadata)
  values (v_me,
          case when p_enabled then 'role.grant' else 'role.revoke' end,
          'user_role', p_user_id, jsonb_build_object('role', p_role::text));

  return jsonb_build_object('user_id', p_user_id, 'role', p_role, 'enabled', p_enabled);
end;
$$;


--
-- Name: sai_staff_directory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_staff_directory() RETURNS TABLE(user_id uuid, full_name text, email text, roles text[])
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if not (public.sai_security_has_role('super_admin')
          or public.sai_security_has_role('admin')
          or public.sai_security_has_role('receptionist')) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  return query
    select ur.user_id,
           coalesce(p.full_name, 'Staff member')::text as full_name,
           p.email::text as email,
           array_agg(ur.role::text) as roles
    from public.user_roles ur
    left join public.profiles p on p.id = ur.user_id
    where ur.role in ('super_admin','admin','receptionist','teacher','accountant','librarian','content_editor')
    group by ur.user_id, p.full_name, p.email
    order by coalesce(p.full_name, 'Staff member');
end;
$$;


--
-- Name: sai_submit_application(text, text, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sai_submit_application(p_full_name text, p_guardian_name text, p_phone text, p_email text, p_program text, p_level text, p_notes text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_admin uuid;
  v_branch uuid;
  v_session uuid;
  v_year text := to_char(now(), 'YYYY');
  v_seq integer;
  v_no text;
  v_row public.admissions_enquiries;
  v_attempt integer;
begin
  if coalesce(length(btrim(p_full_name)), 0) < 2 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  if coalesce(btrim(p_phone), '') = '' and coalesce(btrim(p_email), '') = '' then
    raise exception 'missing_contact' using errcode = '22023';
  end if;
  if coalesce(length(p_notes), 0) > 1000 then
    raise exception 'notes_too_long' using errcode = '22023';
  end if;

  select r.user_id into v_admin from public.user_roles r where r.role = 'super_admin' limit 1;
  if v_admin is null then
    raise exception 'no_administrator' using errcode = '42501';
  end if;

  select b.id into v_branch from public.branches b where b.is_active order by b.created_at limit 1;
  if v_branch is null then
    select b.id into v_branch from public.branches b order by b.created_at limit 1;
  end if;
  select s.id into v_session from public.academic_sessions s where s.is_active order by s.starts_on desc limit 1;
  if v_session is null then
    select s.id into v_session from public.academic_sessions s order by s.starts_on desc limit 1;
  end if;
  if v_branch is null or v_session is null then
    raise exception 'college_not_configured' using errcode = '42501';
  end if;

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated', 'aud', 'authenticated')::text,
    true
  );

  select coalesce(max(substring(e.application_no from ('^SAI-' || v_year || '-(\d+)$'))::int), 0) + 1
    into v_seq
    from public.admissions_enquiries e
    where e.application_no ~ ('^SAI-' || v_year || '-\d+$');

  for v_attempt in 0..5 loop
    v_no := 'SAI-' || v_year || '-' || lpad((v_seq + v_attempt)::text, 4, '0');
    begin
      insert into public.admissions_enquiries (
        branch_id, academic_session_id, application_no, applicant_full_name, guardian_name,
        phone, email, preferred_program, preferred_level, source, notes, status
      ) values (
        v_branch, v_session, v_no, btrim(p_full_name), nullif(btrim(coalesce(p_guardian_name, '')), ''),
        nullif(btrim(coalesce(p_phone, '')), ''), nullif(btrim(coalesce(p_email, '')), ''),
        nullif(btrim(coalesce(p_program, '')), ''), nullif(btrim(coalesce(p_level, '')), ''),
        'website', nullif(btrim(coalesce(p_notes, '')), ''), 'new'
      )
      returning * into v_row;

      return jsonb_build_object(
        'application_no', v_row.application_no,
        'created_at', v_row.created_at,
        'program', v_row.preferred_program
      );
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'could_not_allocate_number' using errcode = '23505';
end;
$_$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.academic_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    starts_on date NOT NULL,
    ends_on date NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    CONSTRAINT academic_sessions_check CHECK ((ends_on > starts_on))
);


--
-- Name: admission_reminder_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admission_reminder_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    enquiry_id uuid NOT NULL,
    reminder_kind text DEFAULT 'stale_new'::text NOT NULL,
    sent_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admission_reminder_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admission_reminder_runs (
    run_date date NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_count integer DEFAULT 0 NOT NULL,
    finished_at timestamp with time zone
);


--
-- Name: admissions_enquiries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admissions_enquiries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id uuid NOT NULL,
    academic_session_id uuid NOT NULL,
    application_no text NOT NULL,
    applicant_full_name text NOT NULL,
    guardian_name text,
    phone text,
    email text,
    preferred_program text,
    preferred_level text,
    source text,
    notes text,
    status text DEFAULT 'new'::text NOT NULL,
    assigned_to uuid,
    created_by uuid DEFAULT auth.uid() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    closed_at timestamp with time zone,
    CONSTRAINT admissions_enquiries_applicant_full_name_check CHECK ((length(btrim(applicant_full_name)) > 0)),
    CONSTRAINT admissions_enquiries_status_check CHECK ((status = ANY (ARRAY['new'::text, 'contacted'::text, 'assessment'::text, 'accepted'::text, 'enrolled'::text, 'rejected'::text, 'withdrawn'::text])))
);


--
-- Name: admissions_application_no_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admissions_application_no_seq
    START WITH 1042
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admissions_application_no_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admissions_application_no_seq OWNED BY public.admissions_enquiries.application_no;


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_user_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: branch_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branch_memberships (
    user_id uuid NOT NULL,
    branch_id uuid NOT NULL,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: branches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.branches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    address text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    branch_id uuid NOT NULL,
    session_id uuid NOT NULL,
    name text NOT NULL,
    program text NOT NULL,
    capacity integer DEFAULT 20 NOT NULL,
    teacher_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT classes_capacity_check CHECK ((capacity > 0))
);


--
-- Name: parent_student_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parent_student_links (
    parent_user_id uuid NOT NULL,
    student_id uuid NOT NULL,
    verified_at timestamp with time zone,
    verified_by uuid
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text NOT NULL,
    email text,
    phone text,
    preferred_locale text DEFAULT 'ar'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    branch_id uuid NOT NULL,
    admission_no text NOT NULL,
    full_name text NOT NULL,
    date_of_birth date,
    class_id uuid,
    status text DEFAULT 'active'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT students_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'graduated'::text, 'withdrawn'::text])))
);


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    user_id uuid NOT NULL,
    role public.app_role NOT NULL,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admissions_enquiries application_no; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries ALTER COLUMN application_no SET DEFAULT ('SAI-APP-'::text || nextval('public.admissions_application_no_seq'::regclass));


--
-- Name: academic_sessions academic_sessions_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_sessions
    ADD CONSTRAINT academic_sessions_name_key UNIQUE (name);


--
-- Name: academic_sessions academic_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.academic_sessions
    ADD CONSTRAINT academic_sessions_pkey PRIMARY KEY (id);


--
-- Name: admission_reminder_log admission_reminder_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admission_reminder_log
    ADD CONSTRAINT admission_reminder_log_pkey PRIMARY KEY (id);


--
-- Name: admission_reminder_log admission_reminder_log_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admission_reminder_log
    ADD CONSTRAINT admission_reminder_log_unique UNIQUE (enquiry_id, reminder_kind);


--
-- Name: admission_reminder_runs admission_reminder_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admission_reminder_runs
    ADD CONSTRAINT admission_reminder_runs_pkey PRIMARY KEY (run_date);


--
-- Name: admissions_enquiries admissions_enquiries_application_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_application_no_key UNIQUE (application_no);


--
-- Name: admissions_enquiries admissions_enquiries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: branch_memberships branch_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_pkey PRIMARY KEY (user_id, branch_id);


--
-- Name: branches branches_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_code_key UNIQUE (code);


--
-- Name: branches branches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branches
    ADD CONSTRAINT branches_pkey PRIMARY KEY (id);


--
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- Name: parent_student_links parent_student_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_pkey PRIMARY KEY (parent_user_id, student_id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: students students_admission_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_admission_no_key UNIQUE (admission_no);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role);


--
-- Name: admission_reminder_log_enquiry_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admission_reminder_log_enquiry_idx ON public.admission_reminder_log USING btree (enquiry_id);


--
-- Name: admissions_assignee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admissions_assignee_idx ON public.admissions_enquiries USING btree (assigned_to, branch_id);


--
-- Name: admissions_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admissions_scope_idx ON public.admissions_enquiries USING btree (branch_id, academic_session_id, status, created_at DESC);


--
-- Name: audit_logs_entity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_logs_entity_idx ON public.audit_logs USING btree (entity_type, entity_id, created_at);


--
-- Name: classes_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX classes_scope_idx ON public.classes USING btree (branch_id, session_id);


--
-- Name: parent_links_student_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parent_links_student_idx ON public.parent_student_links USING btree (student_id);


--
-- Name: students_scope_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX students_scope_idx ON public.students USING btree (branch_id, class_id);


--
-- Name: admissions_enquiries admissions_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admissions_audit AFTER INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION public.sai_admissions_audit();


--
-- Name: admissions_enquiries admissions_prepare; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admissions_prepare BEFORE INSERT OR UPDATE ON public.admissions_enquiries FOR EACH ROW EXECUTE FUNCTION public.sai_admissions_prepare();


--
-- Name: branches audit_branches_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_branches_management AFTER INSERT OR UPDATE ON public.branches FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: classes audit_classes_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_classes_management AFTER INSERT OR UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: branch_memberships audit_memberships_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_memberships_management AFTER INSERT OR UPDATE ON public.branch_memberships FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: academic_sessions audit_sessions_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_sessions_management AFTER INSERT OR UPDATE ON public.academic_sessions FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: students audit_students_management; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_students_management AFTER INSERT OR UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.sai_management_audit_mutation();


--
-- Name: students students_validate_class_branch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER students_validate_class_branch BEFORE INSERT OR UPDATE OF class_id, branch_id ON public.students FOR EACH ROW EXECUTE FUNCTION public.sai_management_validate_student_class();


--
-- Name: admission_reminder_log admission_reminder_log_enquiry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admission_reminder_log
    ADD CONSTRAINT admission_reminder_log_enquiry_id_fkey FOREIGN KEY (enquiry_id) REFERENCES public.admissions_enquiries(id) ON DELETE CASCADE;


--
-- Name: admissions_enquiries admissions_enquiries_academic_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_academic_session_id_fkey FOREIGN KEY (academic_session_id) REFERENCES public.academic_sessions(id);


--
-- Name: admissions_enquiries admissions_enquiries_assigned_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES auth.users(id);


--
-- Name: admissions_enquiries admissions_enquiries_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: admissions_enquiries admissions_enquiries_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admissions_enquiries
    ADD CONSTRAINT admissions_enquiries_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: audit_logs audit_logs_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES auth.users(id);


--
-- Name: branch_memberships branch_memberships_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id) ON DELETE CASCADE;


--
-- Name: branch_memberships branch_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.branch_memberships
    ADD CONSTRAINT branch_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: classes classes_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: classes classes_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.academic_sessions(id);


--
-- Name: classes classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES auth.users(id);


--
-- Name: parent_student_links parent_student_links_parent_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_parent_user_id_fkey FOREIGN KEY (parent_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: parent_student_links parent_student_links_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: parent_student_links parent_student_links_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_student_links
    ADD CONSTRAINT parent_student_links_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES auth.users(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: students students_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES public.branches(id);


--
-- Name: students students_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);


--
-- Name: students students_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES auth.users(id);


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: academic_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.academic_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: academic_sessions academic_sessions_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_insert_super_admin ON public.academic_sessions FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: academic_sessions academic_sessions_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_select_authorized ON public.academic_sessions FOR SELECT TO authenticated USING (public.sai_security_can_read_session(id));


--
-- Name: academic_sessions academic_sessions_update_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY academic_sessions_update_super_admin ON public.academic_sessions FOR UPDATE TO authenticated USING (public.sai_security_has_role('super_admin'::public.app_role)) WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: admission_reminder_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admission_reminder_log ENABLE ROW LEVEL SECURITY;

--
-- Name: admission_reminder_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admission_reminder_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: admissions_enquiries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admissions_enquiries ENABLE ROW LEVEL SECURITY;

--
-- Name: admissions_enquiries admissions_insert_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_insert_staff ON public.admissions_enquiries FOR INSERT TO authenticated WITH CHECK (((created_by = ( SELECT auth.uid() AS uid)) AND (status = 'new'::text) AND (public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role))))));


--
-- Name: admissions_enquiries admissions_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_select_authorized ON public.admissions_enquiries FOR SELECT TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role) OR (public.sai_security_has_role('teacher'::public.app_role) AND (assigned_to = ( SELECT auth.uid() AS uid)))))));


--
-- Name: admissions_enquiries admissions_update_staff; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admissions_update_staff ON public.admissions_enquiries FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role))))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_branch_member(branch_id) AND (public.sai_security_has_role('admin'::public.app_role) OR public.sai_security_has_role('receptionist'::public.app_role)))));


--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs audit_logs_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_insert_self ON public.audit_logs FOR INSERT TO authenticated WITH CHECK ((actor_user_id = ( SELECT auth.uid() AS uid)));


--
-- Name: audit_logs audit_logs_select_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_logs_select_super_admin ON public.audit_logs FOR SELECT TO authenticated USING (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branch_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branch_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: branch_memberships branch_memberships_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_insert_super_admin ON public.branch_memberships FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branch_memberships branch_memberships_select_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_select_self_or_super_admin ON public.branch_memberships FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR public.sai_security_has_role('super_admin'::public.app_role)));


--
-- Name: branch_memberships branch_memberships_update_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branch_memberships_update_self_or_super_admin ON public.branch_memberships FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR ((user_id = ( SELECT auth.uid() AS uid)) AND public.sai_security_has_role('admin'::public.app_role))));


--
-- Name: branches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

--
-- Name: branches branches_insert_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_insert_super_admin ON public.branches FOR INSERT TO authenticated WITH CHECK (public.sai_security_has_role('super_admin'::public.app_role));


--
-- Name: branches branches_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_select_authorized ON public.branches FOR SELECT TO authenticated USING (public.sai_security_can_read_branch(id));


--
-- Name: branches branches_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY branches_update_scoped_admin ON public.branches FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(id))));


--
-- Name: classes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

--
-- Name: classes classes_insert_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_insert_scoped_admin ON public.classes FOR INSERT TO authenticated WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id) AND public.sai_security_can_read_session(session_id))));


--
-- Name: classes classes_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_select_authorized ON public.classes FOR SELECT TO authenticated USING (public.sai_security_can_read_class(id));


--
-- Name: classes classes_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY classes_update_scoped_admin ON public.classes FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: parent_student_links; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;

--
-- Name: parent_student_links parent_student_links_select_parent_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY parent_student_links_select_parent_or_super_admin ON public.parent_student_links FOR SELECT TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('parent'::public.app_role) AND (parent_user_id = ( SELECT auth.uid() AS uid)) AND (verified_at IS NOT NULL))));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_insert_self ON public.profiles FOR INSERT TO authenticated WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles profiles_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_self ON public.profiles FOR SELECT TO authenticated USING ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE TO authenticated USING ((id = ( SELECT auth.uid() AS uid))) WITH CHECK ((id = ( SELECT auth.uid() AS uid)));


--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: students students_insert_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_insert_scoped_admin ON public.students FOR INSERT TO authenticated WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: students students_select_authorized; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_select_authorized ON public.students FOR SELECT TO authenticated USING (public.sai_security_can_read_student(id));


--
-- Name: students students_update_scoped_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY students_update_scoped_admin ON public.students FOR UPDATE TO authenticated USING ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id)))) WITH CHECK ((public.sai_security_has_role('super_admin'::public.app_role) OR (public.sai_security_has_role('admin'::public.app_role) AND public.sai_security_branch_member(branch_id))));


--
-- Name: user_roles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

--
-- Name: user_roles user_roles_select_self_or_super_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_roles_select_self_or_super_admin ON public.user_roles FOR SELECT TO authenticated USING (((user_id = ( SELECT auth.uid() AS uid)) OR public.sai_security_has_role('super_admin'::public.app_role)));


--
-- PostgreSQL database dump complete
--

\unrestrict XwtrCe5WBcfVAHY6UE2XcgynDJPNm9ba8ep7fl8K6TomhXW9KueQ2Fo8Ig0APJA

