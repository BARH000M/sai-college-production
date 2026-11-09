-- Runs inside the guarded setup transaction. Fixtures and these checks roll
-- back together on error. Test-only role grants do not establish MAIN ACLs.
do $$
declare
  denied boolean;
  count_visible integer;
  enquiry_id uuid;
  application_number text;
  error_message text;
begin
  if not has_sequence_privilege('authenticated', 'public.admissions_application_no_seq', 'USAGE')
     or has_sequence_privilege('authenticated', 'public.admissions_application_no_seq', 'UPDATE')
     or has_sequence_privilege('anon', 'public.admissions_application_no_seq', 'USAGE')
     or has_sequence_privilege('anon', 'public.admissions_application_no_seq', 'UPDATE') then
    raise exception 'Unexpected effective admission sequence privileges';
  end if;
  insert into public.academic_sessions(id, name, starts_on, ends_on, is_active)
  values ('30000000-0000-4000-8000-000000000002', 'Synthetic Inactive Session', '2020-01-01', '2099-12-31', false);
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
  perform set_config('sai.public_web_enquiry', 'off', true);
  execute 'set local role authenticated';
  denied := false;
  begin
    perform setval('public.admissions_application_no_seq', 1);
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Authenticated role can reset admission sequence'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries(branch_id, academic_session_id, applicant_full_name)
    values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'Synthetic Inactive');
  exception when check_violation then
    get stacked diagnostics error_message = message_text;
    if error_message <> 'Active session is required' then raise; end if;
    denied := true;
  end;
  if not denied then raise exception 'Inactive session was accepted'; end if;
  insert into public.admissions_enquiries(branch_id, academic_session_id, applicant_full_name)
  values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'Synthetic Staff Enquiry')
  returning id, application_no into enquiry_id, application_number;
  if application_number not like 'SAI-APP-%' then raise exception 'Unexpected generated application number'; end if;
  execute 'reset role';
  if not exists (select 1 from public.audit_logs where entity_id = enquiry_id and entity_type = 'admissions_enquiries') then
    raise exception 'Staff enquiry audit record missing';
  end if;
  delete from public.admissions_enquiries where id = enquiry_id;
  delete from public.academic_sessions where id = '30000000-0000-4000-8000-000000000002';
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('sai.public_web_enquiry', 'on', true);
  execute 'set local role anon';
  denied := false;
  begin
    perform nextval('public.admissions_application_no_seq');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Anonymous role can advance admission sequence directly'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries(branch_id, academic_session_id, applicant_full_name)
    values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'Unauthorized Synthetic');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Anonymous direct admission insert succeeded'; end if;
  denied := false;
  begin
    perform public.sai_public_admission_submit('x', '123456', null, null, null);
  exception when invalid_parameter_value then denied := true;
  end;
  if not denied then raise exception 'Invalid public submission accepted'; end if;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
  execute 'set local role authenticated';
  select count(*) into count_visible from public.students
  where id = '50000000-0000-4000-8000-000000000002';
  if count_visible <> 0 then raise exception 'Student read another student through RLS'; end if;
  denied := false;
  begin
    insert into public.admissions_enquiries(branch_id, academic_session_id, applicant_full_name)
    values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'Unauthorized Synthetic');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Student inserted admission with public bypass flag'; end if;
  execute 'reset role';
  perform set_config('sai.public_web_enquiry', 'off', true);
  perform set_config('request.jwt.claim.sub', '', true);
end;
$$;
