-- Requires a synthetic active branch, active session and super admin fixture.
-- The transaction rolls back rows, but sequences may advance.
begin;
do $$
declare
  reference text;
  failed boolean := false;
begin
  if current_setting('sai.wave1_isolated_test', true) is distinct from 'yes' then
    raise exception 'Disposable marker missing';
  end if;
  if not exists (select 1 from public.branches where is_active)
     or not exists (select 1 from public.academic_sessions where is_active)
     or not exists (select 1 from public.user_roles where role = 'super_admin') then
    raise exception 'Synthetic active branch, session and super admin fixtures required';
  end if;
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
  begin
    perform public.sai_public_admission_submit('x', '123456', null, null, null);
  exception when invalid_parameter_value then failed := true;
  end;
  if not failed then raise exception 'Invalid public name accepted'; end if;
  reference := public.sai_public_admission_submit('Disposable Applicant', '123456789', 'test@example.invalid', 'Test', 'Synthetic only');
  if reference is null or reference = '' then raise exception 'Missing enquiry reference'; end if;
  if current_setting('sai.public_web_enquiry', true) is distinct from 'off' then
    raise exception 'Public enquiry flag was not cleared';
  end if;
  execute 'reset role';
  if not exists (
    select 1 from public.admissions_enquiries a
    join public.audit_logs l on l.entity_id = a.id and l.entity_type = 'admissions_enquiries'
    where a.application_no = reference and a.source = 'website'
      and a.applicant_full_name = 'Disposable Applicant'
  ) then raise exception 'Public enquiry or audit record missing'; end if;
end;
$$;
rollback;
