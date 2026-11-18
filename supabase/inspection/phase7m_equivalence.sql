with checks as (
select '20261116013951'::text version,'public.user_roles:SELECT:user_id' contract,has_column_privilege('service_role','public.user_roles','user_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.user_roles:SELECT:role' contract,has_column_privilege('service_role','public.user_roles','role','SELECT') equivalent
union all
select '20261116013951'::text version,'public.profiles:SELECT:id' contract,has_column_privilege('service_role','public.profiles','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.profiles:SELECT:full_name' contract,has_column_privilege('service_role','public.profiles','full_name','SELECT') equivalent
union all
select '20261116013951'::text version,'public.profiles:SELECT:email' contract,has_column_privilege('service_role','public.profiles','email','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branches:SELECT:id' contract,has_column_privilege('service_role','public.branches','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branches:SELECT:name' contract,has_column_privilege('service_role','public.branches','name','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branches:SELECT:is_active' contract,has_column_privilege('service_role','public.branches','is_active','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:SELECT:user_id' contract,has_column_privilege('service_role','public.branch_memberships','user_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:SELECT:branch_id' contract,has_column_privilege('service_role','public.branch_memberships','branch_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:SELECT:is_active' contract,has_column_privilege('service_role','public.branch_memberships','is_active','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:id' contract,has_column_privilege('service_role','public.students','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:full_name' contract,has_column_privilege('service_role','public.students','full_name','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:admission_no' contract,has_column_privilege('service_role','public.students','admission_no','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:class_id' contract,has_column_privilege('service_role','public.students','class_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:user_id' contract,has_column_privilege('service_role','public.students','user_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:status' contract,has_column_privilege('service_role','public.students','status','SELECT') equivalent
union all
select '20261116013951'::text version,'public.students:SELECT:branch_id' contract,has_column_privilege('service_role','public.students','branch_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.parent_student_links:SELECT:parent_user_id' contract,has_column_privilege('service_role','public.parent_student_links','parent_user_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.parent_student_links:SELECT:student_id' contract,has_column_privilege('service_role','public.parent_student_links','student_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.parent_student_links:SELECT:verified_at' contract,has_column_privilege('service_role','public.parent_student_links','verified_at','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:id' contract,has_column_privilege('service_role','public.classes','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:name' contract,has_column_privilege('service_role','public.classes','name','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:program' contract,has_column_privilege('service_role','public.classes','program','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:branch_id' contract,has_column_privilege('service_role','public.classes','branch_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:teacher_id' contract,has_column_privilege('service_role','public.classes','teacher_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.classes:SELECT:is_active' contract,has_column_privilege('service_role','public.classes','is_active','SELECT') equivalent
union all
select '20261116013951'::text version,'public.academic_sessions:SELECT:id' contract,has_column_privilege('service_role','public.academic_sessions','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:id' contract,has_column_privilege('service_role','public.learning_courses','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:class_id' contract,has_column_privilege('service_role','public.learning_courses','class_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:teacher_id' contract,has_column_privilege('service_role','public.learning_courses','teacher_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:title' contract,has_column_privilege('service_role','public.learning_courses','title','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:is_active' contract,has_column_privilege('service_role','public.learning_courses','is_active','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:SELECT:branch_id' contract,has_column_privilege('service_role','public.learning_courses','branch_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:id' contract,has_column_privilege('service_role','public.learning_lessons','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:is_published' contract,has_column_privilege('service_role','public.learning_lessons','is_published','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:content_path' contract,has_column_privilege('service_role','public.learning_lessons','content_path','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:content_body' contract,has_column_privilege('service_role','public.learning_lessons','content_body','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:content_url' contract,has_column_privilege('service_role','public.learning_lessons','content_url','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lessons:SELECT:content_kind' contract,has_column_privilege('service_role','public.learning_lessons','content_kind','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lesson_progress:SELECT:lesson_id' contract,has_column_privilege('service_role','public.learning_lesson_progress','lesson_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_lesson_progress:SELECT:status' contract,has_column_privilege('service_role','public.learning_lesson_progress','status','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_homework:SELECT:id' contract,has_column_privilege('service_role','public.learning_homework','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_homework:SELECT:course_id' contract,has_column_privilege('service_role','public.learning_homework','course_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_homework_submissions:SELECT:id' contract,has_column_privilege('service_role','public.learning_homework_submissions','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_homework_submissions:SELECT:homework_id' contract,has_column_privilege('service_role','public.learning_homework_submissions','homework_id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.learning_homework_submissions:SELECT:status' contract,has_column_privilege('service_role','public.learning_homework_submissions','status','SELECT') equivalent
union all
select '20261116013951'::text version,'public.admissions_enquiries:SELECT:id' contract,has_column_privilege('service_role','public.admissions_enquiries','id','SELECT') equivalent
union all
select '20261116013951'::text version,'public.admissions_enquiries:SELECT:status' contract,has_column_privilege('service_role','public.admissions_enquiries','status','SELECT') equivalent
union all
select '20261116013951'::text version,'public.profiles:INSERT:id' contract,has_column_privilege('service_role','public.profiles','id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.profiles:INSERT:full_name' contract,has_column_privilege('service_role','public.profiles','full_name','INSERT') equivalent
union all
select '20261116013951'::text version,'public.profiles:INSERT:email' contract,has_column_privilege('service_role','public.profiles','email','INSERT') equivalent
union all
select '20261116013951'::text version,'public.profiles:UPDATE:id' contract,has_column_privilege('service_role','public.profiles','id','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.profiles:UPDATE:full_name' contract,has_column_privilege('service_role','public.profiles','full_name','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.profiles:UPDATE:email' contract,has_column_privilege('service_role','public.profiles','email','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.user_roles:INSERT:user_id' contract,has_column_privilege('service_role','public.user_roles','user_id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.user_roles:INSERT:role' contract,has_column_privilege('service_role','public.user_roles','role','INSERT') equivalent
union all
select '20261116013951'::text version,'public.user_roles:INSERT:assigned_by' contract,has_column_privilege('service_role','public.user_roles','assigned_by','INSERT') equivalent
union all
select '20261116013951'::text version,'public.user_roles:DELETE:None' contract,has_table_privilege('service_role','public.user_roles','DELETE') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:INSERT:user_id' contract,has_column_privilege('service_role','public.branch_memberships','user_id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:INSERT:branch_id' contract,has_column_privilege('service_role','public.branch_memberships','branch_id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:INSERT:is_active' contract,has_column_privilege('service_role','public.branch_memberships','is_active','INSERT') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:UPDATE:user_id' contract,has_column_privilege('service_role','public.branch_memberships','user_id','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:UPDATE:branch_id' contract,has_column_privilege('service_role','public.branch_memberships','branch_id','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:UPDATE:is_active' contract,has_column_privilege('service_role','public.branch_memberships','is_active','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.branch_memberships:DELETE:None' contract,has_table_privilege('service_role','public.branch_memberships','DELETE') equivalent
union all
select '20261116013951'::text version,'public.classes:UPDATE:teacher_id' contract,has_column_privilege('service_role','public.classes','teacher_id','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.learning_courses:UPDATE:teacher_id' contract,has_column_privilege('service_role','public.learning_courses','teacher_id','UPDATE') equivalent
union all
select '20261116013951'::text version,'public.audit_logs:INSERT:actor_user_id' contract,has_column_privilege('service_role','public.audit_logs','actor_user_id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.audit_logs:INSERT:action' contract,has_column_privilege('service_role','public.audit_logs','action','INSERT') equivalent
union all
select '20261116013951'::text version,'public.audit_logs:INSERT:entity_type' contract,has_column_privilege('service_role','public.audit_logs','entity_type','INSERT') equivalent
union all
select '20261116013951'::text version,'public.audit_logs:INSERT:entity_id' contract,has_column_privilege('service_role','public.audit_logs','entity_id','INSERT') equivalent
union all
select '20261116013951'::text version,'public.audit_logs:INSERT:metadata' contract,has_column_privilege('service_role','public.audit_logs','metadata','INSERT') equivalent
union all
select '030', 'exact authenticated admission INSERT/UPDATE boundary',
      not has_table_privilege('authenticated','public.admissions_enquiries','INSERT')
      and not has_table_privilege('authenticated','public.admissions_enquiries','UPDATE')
      and not exists (
        select 1 from information_schema.columns c
        cross join (values ('INSERT'),('UPDATE')) p(privilege)
        where c.table_schema='public' and c.table_name='admissions_enquiries'
          and has_column_privilege('authenticated','public.admissions_enquiries',c.column_name,p.privilege)
            is distinct from (c.column_name=any(case when p.privilege='INSERT' then
              array['branch_id','academic_session_id','applicant_full_name','guardian_name','phone','email','preferred_program','preferred_level','source','notes','assigned_to']
              else array['academic_session_id','applicant_full_name','guardian_name','phone','email','preferred_program','preferred_level','source','notes','status','assigned_to'] end))
      )
) select version,count(*) as contracts,bool_and(equivalent) as equivalent,jsonb_agg(contract) filter(where not equivalent) as failures from checks group by version order by version;
