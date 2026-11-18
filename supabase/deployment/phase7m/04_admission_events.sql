-- Forward correction for 20261115001316. Never import audit_logs: clients can
-- forge their action, entity and source metadata. Historical states cannot be
-- reconstructed safely; existing applicants receive a labelled snapshot only.
begin;
-- Serialize installation, snapshot and trigger activation with admissions writes.
lock table public.admissions_enquiries in share row exclusive mode;
create table private.admission_status_events (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid not null references public.admissions_enquiries(id) on delete restrict,
  action text not null check (action in ('insert', 'status_change', 'current_status_snapshot')),
  old_status text,
  status text not null check (status in ('new','contacted','assessment','accepted','enrolled','rejected','withdrawn')),
  occurred_at timestamptz not null default clock_timestamp()
);
create index admission_status_events_history_idx
  on private.admission_status_events(enquiry_id, occurred_at, id);
alter table private.admission_status_events enable row level security;
revoke all on private.admission_status_events from public, anon, authenticated, service_role;

-- No audit backfill: only the authoritative current state is verifiable.
insert into private.admission_status_events(enquiry_id, action, status)
select id, 'current_status_snapshot', status from public.admissions_enquiries;

-- Dedicated non-login writer cannot read applicants, update events or bypass RLS.
create role sai_admission_event_writer nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;
do $$
begin
  execute format('grant sai_admission_event_writer to %I with set true, inherit false', current_user);
end;
$$;
grant usage on schema private to sai_admission_event_writer;
grant insert on private.admission_status_events to sai_admission_event_writer;
create policy admission_events_trigger_insert on private.admission_status_events
  for insert to sai_admission_event_writer with check (true);

create function private.record_admission_status_event()
returns trigger language plpgsql security definer set search_path = pg_catalog
as $$
begin
  if tg_table_schema <> 'public' or tg_table_name <> 'admissions_enquiries'
    or tg_when <> 'AFTER' or tg_level <> 'ROW' then
    raise exception 'Admission event writer requires the admissions row trigger';
  end if;
  if tg_op = 'INSERT' then
    insert into private.admission_status_events(enquiry_id, action, status)
      values (new.id, 'insert', new.status);
  elsif old.status is distinct from new.status then
    insert into private.admission_status_events(enquiry_id, action, old_status, status)
      values (new.id, 'status_change', old.status, new.status);
  end if;
  -- No exception handler: event failure aborts the admission mutation.
  return new;
end;
$$;
-- Install and restrict the trigger while the migration role still owns its
-- function. The writer membership deliberately does not inherit privileges.
revoke all on function private.record_admission_status_event() from public, anon, authenticated, service_role;
create trigger admissions_trusted_status_event
  after insert or update of status on public.admissions_enquiries
  for each row execute function private.record_admission_status_event();
-- Ownership transfer requires temporary CREATE; leave no schema creation right.
grant create on schema private to sai_admission_event_writer;
alter function private.record_admission_status_event() owner to sai_admission_event_writer;
revoke create on schema private from sai_admission_event_writer;
create or replace function public.admissions_public_history(p_reference text, p_tracking_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, private
as $$
declare
  v_enquiry_id uuid;
  result jsonb;
begin
  if p_reference is null or length(btrim(p_reference)) < 6 or length(btrim(p_reference)) > 80
    or p_tracking_token is null or p_tracking_token !~ '^[0-9a-f]{64}$' then
    return null;
  end if;

  select e.id into v_enquiry_id
  from public.admissions_enquiries e
  join private.admission_tracking_tokens t on t.enquiry_id = e.id
  where upper(e.application_no) = upper(btrim(p_reference))
    and t.token_hash = pg_catalog.sha256(convert_to(p_tracking_token, 'UTF8'))
  limit 1;

  if v_enquiry_id is null then
    return null;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'action', a.action,
    'status', a.status,
    'occurred_at', a.occurred_at
  ) order by a.occurred_at, a.id), '[]'::jsonb)
  into result
  from private.admission_status_events a
  where a.enquiry_id = v_enquiry_id;

  return result;
end;
$$;


revoke all on function public.admissions_public_history(text,text) from public, anon, authenticated;
grant execute on function public.admissions_public_history(text,text) to service_role;
commit;
