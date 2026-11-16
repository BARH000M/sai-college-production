alter table public.students
  add column admission_enquiry_id uuid
    references public.admissions_enquiries(id) on delete restrict;

create unique index students_admission_enquiry_id_uidx
  on public.students (admission_enquiry_id)
  where admission_enquiry_id is not null;

revoke update (status) on public.admissions_enquiries from authenticated;

create function public.sai_admissions_set_status(
  p_enquiry_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  enquiry_branch uuid;
  current_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_status is null or p_status not in (
    'new', 'contacted', 'assessment', 'accepted', 'rejected', 'withdrawn'
  ) then
    raise exception 'Unsupported admission status' using errcode = '22023';
  end if;

  select e.branch_id, e.status
    into enquiry_branch, current_status
    from public.admissions_enquiries e
    where e.id = p_enquiry_id
    for update;

  if not found then
    raise exception 'Admission enquiry not found' using errcode = 'P0002';
  end if;

  if current_status = 'enrolled' then
    raise exception 'Enrolled enquiries cannot change status' using errcode = '22023';
  end if;

  if not (
    private.sai_security_has_role('super_admin')
    or (
      private.sai_security_branch_member(enquiry_branch)
      and (
        private.sai_security_has_role('admin')
        or private.sai_security_has_role('receptionist')
      )
    )
  ) then
    raise exception 'Not authorized for this branch' using errcode = '42501';
  end if;

  update public.admissions_enquiries
    set status = p_status
    where id = p_enquiry_id;
end;
$$;

revoke all on function public.sai_admissions_set_status(uuid, text)
  from public, anon, authenticated;
grant execute on function public.sai_admissions_set_status(uuid, text)
  to authenticated;

create function public.sai_admissions_enroll(p_enquiry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  enquiry public.admissions_enquiries%rowtype;
  student public.students%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select e.*
    into enquiry
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
      and private.sai_security_branch_member(enquiry.branch_id)
    )
  ) then
    raise exception 'Not authorized to enroll students in this branch'
      using errcode = '42501';
  end if;

  if enquiry.status not in ('accepted', 'enrolled') then
    raise exception 'Only accepted enquiries can be enrolled' using errcode = '22023';
  end if;

  select s.*
    into student
    from public.students s
    where s.admission_enquiry_id = enquiry.id;

  if not found then
    if enquiry.status = 'enrolled' then
      raise exception 'Enrolled enquiry has no linked student record'
        using errcode = '23514';
    end if;

    insert into public.students (
      branch_id,
      admission_no,
      full_name,
      admission_enquiry_id
    )
    values (
      enquiry.branch_id,
      enquiry.application_no,
      enquiry.applicant_full_name,
      enquiry.id
    )
    returning * into student;
  end if;

  if enquiry.status <> 'enrolled' then
    update public.admissions_enquiries
      set status = 'enrolled'
      where id = enquiry.id;
  end if;

  return jsonb_build_object(
    'student_id', student.id,
    'admission_no', student.admission_no,
    'admission_enquiry_id', enquiry.id
  );
end;
$$;

revoke all on function public.sai_admissions_enroll(uuid)
  from public, anon, authenticated;
grant execute on function public.sai_admissions_enroll(uuid)
  to authenticated;
