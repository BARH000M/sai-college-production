-- REVIEW ONLY: requires 01. This moves existing teacher mutations into one
-- serialized transaction, preserving membership scope used by other staff roles.
begin;
create function private.sai_manage_teacher_assignment(p_actor_id uuid,p_target_id uuid,p_action text,p_class_id uuid)
returns jsonb language plpgsql security definer set search_path = ''
as $$ declare v_branch uuid; v_teacher uuid; v_name text; begin
 perform private.sai_assert_role_actor(p_actor_id);
 if p_action is null or p_action not in ('assign','reassign','remove') then
   raise exception 'invalid_teacher_action' using errcode='22023';
 end if;
 if p_action<>'remove' then
   perform u.id from auth.users u where u.id=p_target_id and u.email_confirmed_at is not null
     and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now()) for share;
   if not found then raise exception 'verified_usable_account_required' using errcode='22023'; end if;
   select c.branch_id,c.teacher_id,c.name into v_branch,v_teacher,v_name
     from public.classes c join public.branches b on b.id=c.branch_id
     where c.id=p_class_id and c.is_active and b.is_active for update of c;
   if not found then raise exception 'active_class_required' using errcode='22023'; end if;
   if v_teacher is not null and v_teacher<>p_target_id then
     raise exception 'class_already_assigned' using errcode='23505';
   end if;
 end if;
 if not exists(select 1 from public.user_roles where user_id=p_target_id and role='teacher') then
   if p_action<>'assign' then raise exception 'teacher_role_required' using errcode='42501'; end if;
   perform private.sai_manage_role_assignment(p_actor_id,p_target_id,'grant','teacher',array[v_branch],true,false,null,null);
 end if;
 if p_action in ('reassign','remove') then
   update public.classes set teacher_id=null where teacher_id=p_target_id and (p_action='remove' or id<>p_class_id);
   update public.learning_courses set teacher_id=null where teacher_id=p_target_id and (p_action='remove' or class_id<>p_class_id);
 end if;
 if p_action<>'remove' then
   update public.classes set teacher_id=p_target_id where id=p_class_id;
   update public.learning_courses set teacher_id=p_target_id where class_id=p_class_id and teacher_id is null;
   insert into public.branch_memberships(user_id,branch_id,is_active) values(p_target_id,v_branch,true)
     on conflict(user_id,branch_id) do update set is_active=true;
 end if;
 if not exists(select 1 from public.user_roles where user_id=p_target_id
   and role in ('super_admin','admin','accountant','receptionist','librarian','content_editor')) then
   update public.branch_memberships m set is_active=false where m.user_id=p_target_id and m.is_active
     and not exists(select 1 from public.classes c where c.teacher_id=p_target_id and c.branch_id=m.branch_id)
     and not exists(select 1 from public.learning_courses c where c.teacher_id=p_target_id and c.branch_id=m.branch_id);
 end if;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
   values(p_actor_id,'teacher_'||p_action,'profiles',p_target_id,jsonb_build_object('class_id',p_class_id,'source','learning_accounts'));
 return jsonb_build_object('ok',true,'action',p_action,'user_id',p_target_id);
end $$;
revoke all on function private.sai_manage_teacher_assignment(uuid,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function private.sai_manage_teacher_assignment(uuid,uuid,text,uuid) to service_role;
create function public.sai_manage_teacher_assignment(p_actor_id uuid,p_target_id uuid,p_action text,p_class_id uuid)
returns jsonb language sql security invoker set search_path = ''
as $$ select private.sai_manage_teacher_assignment($1,$2,$3,$4) $$;
revoke all on function public.sai_manage_teacher_assignment(uuid,uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.sai_manage_teacher_assignment(uuid,uuid,text,uuid) to service_role;
notify pgrst,'reload schema';
commit;
