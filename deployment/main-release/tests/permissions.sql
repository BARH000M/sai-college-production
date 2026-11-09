begin;
do $$
declare
  denied boolean := false;
  branch_id uuid;
  session_id uuid;
begin
  if current_setting('sai.wave1_isolated_test', true) is distinct from 'yes' then
    raise exception 'Disposable marker missing';
  end if;
  execute 'set local role anon';
  begin
    perform public.sai_admissions_sessions(null);
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Anonymous directory call was not denied'; end if;
  denied := false;
  begin
    perform * from sai_finance.payments limit 1;
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'Anonymous finance access was not denied'; end if;
  execute 'reset role';
  select id into branch_id from public.branches where is_active limit 1;
  select id into session_id from public.academic_sessions where is_active limit 1;
  if branch_id is null or session_id is null then raise exception 'Synthetic fixtures missing'; end if;
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('sai.public_web_enquiry', 'on', true);
  execute 'set local role authenticated';
  denied := false;
  begin
    insert into public.admissions_enquiries (branch_id, academic_session_id, applicant_full_name)
      values (branch_id, session_id, 'Unauthorized synthetic');
  exception when insufficient_privilege then denied := true;
  end;
  if not denied then raise exception 'GUC-enabled unauthorized insert was not denied'; end if;
  execute 'reset role';
end;
$$;
rollback;
