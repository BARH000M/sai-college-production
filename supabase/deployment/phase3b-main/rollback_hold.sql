-- OPERATOR-APPROVED EMERGENCY HOLD ONLY. NOT PART OF THE FORWARD PACKAGE.
-- Run only after all three forward proposals exist. Keeps role/table guards,
-- existing records and last-admin protection; never reopens legacy writers.
begin;
revoke execute on function public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text),
 private.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text),
 public.sai_manage_teacher_assignment(uuid,uuid,text,uuid),
 private.sai_manage_teacher_assignment(uuid,uuid,text,uuid),
 public.admissions_link_student_account(uuid,uuid),public.admissions_unlink_student_account(uuid),
 public.admissions_verify_parent_student(uuid,uuid)
 from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
