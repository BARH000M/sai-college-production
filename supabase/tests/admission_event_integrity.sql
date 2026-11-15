-- Regression fixtures use a transaction and never persist.
begin;
do $$
begin
  if current_setting('sai.wave1_isolated_test', true) is distinct from 'yes' then
    raise exception 'Isolated test marker missing; refusing to run';
  end if;
end;
$$;
do $$
declare
  owner_id uuid := gen_random_uuid();
  attacker uuid := gen_random_uuid();
  branch_id uuid := gen_random_uuid();
  session_id uuid := gen_random_uuid();
  result jsonb;
  ref text;
  token text;
  other_token text;
  eid uuid;
  before_history jsonb;
  after_history jsonb;
  role_name text;
  operation text;
  denied boolean;
begin
  insert into auth.users(id) values(owner_id),(attacker);
  insert into public.user_roles(user_id,role) values(owner_id,'super_admin');
  insert into public.branches(id, name, code, is_active)
    values(branch_id, 'EVENT_TEST', 'EVENT_TEST_' || branch_id::text, true);
  insert into public.academic_sessions(id, name, starts_on, ends_on, is_active)
    values(session_id, 'EVENT_TEST_' || session_id::text, date '2031-01-01', date '2031-12-31', true);
  execute 'set local role service_role';
  result := public.admissions_public_submit('EVENT_TEST','777123456',null,'Chinese',null);
  execute 'reset role';
  ref := result->>'reference'; token := result->>'tracking_token';
  execute 'set local role service_role';
  result := public.admissions_public_submit('OTHER_EVENT_TEST','777123457',null,'Chinese',null);
  execute 'reset role';
  other_token := result->>'tracking_token';
  select id into eid from public.admissions_enquiries where application_no=ref;
  before_history := public.admissions_public_history(ref,token);
  if jsonb_array_length(before_history) <> 1 or before_history->0->>'action' <> 'insert'
    or before_history->0->>'status' <> 'new' then raise exception 'Genuine insert event missing'; end if;

  perform set_config('request.jwt.claim.sub',attacker::text,true);
  execute 'set local role authenticated';
  insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
    values(attacker,'status_change','admissions_enquiries',eid,
      '{"source":"sai_admissions_trigger","new_status":"enrolled"}');
  insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
    values(attacker,'insert','admissions_enquiries',eid,
      '{"source":"sai_admissions_trigger","new_status":"accepted"}');
  denied := false;
  begin
    perform public.sai_admissions_set_status(eid,'accepted');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Unauthorized status RPC succeeded'; end if;
  denied := false;
  begin
    update public.admissions_enquiries set status='accepted' where id=eid;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Direct status update permitted'; end if;
  execute 'reset role';
  if not exists(select 1 from public.audit_logs where entity_id=eid and actor_user_id=attacker)
    then raise exception 'Forgery fixture did not persist'; end if;
  if public.admissions_public_history(ref,token) is distinct from before_history
    then raise exception 'Forged audit affected trusted history'; end if;
  if public.admissions_public_history(ref,null) is not null
    or public.admissions_public_history(ref,'') is not null
    or public.admissions_public_history(ref,repeat('0',64)) is not null
    or public.admissions_public_history(ref,other_token) is not null
    or public.admissions_public_history('UNKNOWN',token) is not null
    then raise exception 'Invalid credential revealed history'; end if;

  foreach role_name in array array['anon','authenticated','service_role'] loop
    execute format('set local role %I',role_name);
    foreach operation in array array[
      format('insert into private.admission_status_events(enquiry_id,action,status) values(%L,''status_change'',''accepted'')',eid),
      'update private.admission_status_events set status=''accepted''',
      'delete from private.admission_status_events',
      'truncate private.admission_status_events',
      'select * from private.admission_status_events',
      'select private.record_admission_status_event()'
    ] loop
      denied := false;
      begin execute operation; exception when insufficient_privilege then denied:=true; end;
      if not denied then raise exception '% directly accessed protected events: %',role_name,operation; end if;
    end loop;
    execute 'reset role';
  end loop;
  perform set_config('request.jwt.claim.sub',owner_id::text,true);
  execute 'set local role authenticated';
  perform public.sai_admissions_set_status(eid,'accepted');
  execute 'reset role';
  after_history := public.admissions_public_history(ref,token);
  if jsonb_array_length(after_history) <> 2 or after_history->1->>'status' <> 'accepted'
    or after_history->1->>'action' <> 'status_change'
    or not exists(select 1 from private.admission_status_events where enquiry_id=eid and old_status='new' and status='accepted')
    then raise exception 'Authorized transition did not create correct event'; end if;
  perform public.sai_admissions_set_status(eid,'accepted');
  if public.admissions_public_history(ref,token) is distinct from after_history
    then raise exception 'No-op status generated event'; end if;

  alter table private.admission_status_events add constraint event_test_failure check(status <> 'rejected');
  execute 'set local role authenticated';
  denied := false;
  begin perform public.sai_admissions_set_status(eid,'rejected');
  exception when check_violation then denied:=true; end;
  execute 'reset role';
  if not denied or (select status from public.admissions_enquiries where id=eid) <> 'accepted'
    or public.admissions_public_history(ref,token) is distinct from after_history
    or exists(select 1 from public.audit_logs where entity_id=eid and metadata->>'new_status'='rejected')
    then raise exception 'Failed event write did not roll back entire mutation'; end if;
  if public.admissions_public_status(ref,token)->>'status' <> 'accepted'
    then raise exception 'Current status is not authoritative'; end if;
  if not (select relrowsecurity from pg_class where oid='private.admission_status_events'::regclass)
    or pg_has_role('authenticated','sai_admission_event_writer','MEMBER')
    or pg_has_role('anon','sai_admission_event_writer','MEMBER')
    or pg_has_role('service_role','sai_admission_event_writer','MEMBER')
    or has_function_privilege('anon','private.record_admission_status_event()','EXECUTE')
    or has_function_privilege('service_role','private.record_admission_status_event()','EXECUTE')
    or has_function_privilege('authenticated','private.record_admission_status_event()','EXECUTE')
    then raise exception 'Protected store/trigger privileges unsafe'; end if;
  raise notice 'PASS: forgery excluded; genuine events; authorization; tokens; direct access; atomic rollback';
end;
$$;
rollback;
