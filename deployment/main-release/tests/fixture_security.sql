-- Runs inside the guarded setup transaction. Fixtures and these checks roll
-- back together on error. Test-only role grants do not establish MAIN ACLs.
do $$
declare
  denied boolean;
  count_visible integer;
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  perform set_config('sai.public_web_enquiry', 'on', true);
  execute 'set local role anon';
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
