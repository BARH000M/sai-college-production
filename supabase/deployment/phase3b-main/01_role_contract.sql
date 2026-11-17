-- REVIEW PACKAGE ONLY. Main aeryusbrulqdxjdynwfh; never execute through db push.
-- Existing migrations are unchanged. Apply only after the documented backup,
-- isolated restore, tests and coordinated Edge cutover have been approved.
begin;
set local lock_timeout = '10s';
set local statement_timeout = '60s';

do $$ begin
  if to_regclass('public.sai_system_settings') is null
    or to_regclass('public.sai_system_settings_audit') is null
    or to_regclass('public.branch_memberships') is null
    or to_regprocedure('private.sai_security_has_role(public.app_role)') is null then
    raise exception 'Expected Main baseline is missing';
  end if;
  if (select count(*) from pg_enum where enumtypid='public.app_role'::regtype) <> 9 then
    raise exception 'Unexpected app_role contract';
  end if;
end $$;

-- Narrow privileged Auth lookup. No Auth-table grant is added to service_role.
create or replace function private.sai_has_other_usable_super_admin(p_target_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
 select exists(select 1 from public.user_roles r join auth.users u on u.id=r.user_id
   where r.role='super_admin' and r.user_id is distinct from p_target_id
   and u.email_confirmed_at is not null and u.deleted_at is null
   and (u.banned_until is null or u.banned_until<=pg_catalog.now()));
$$;
revoke all on function private.sai_has_other_usable_super_admin(uuid) from public,anon,authenticated,service_role;
grant execute on function private.sai_has_other_usable_super_admin(uuid) to service_role;

create or replace function private.sai_assert_role_actor(p_actor_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$ begin
 -- RPCs use the default PostgREST isolation. Reject stale transaction snapshots.
 if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
   raise exception 'read_committed_required' using errcode='25001';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(831704,1);
 -- Lock usable-account evidence through commit, including the actor/remaining
 -- admins. Auth ban/unconfirm updates cannot invalidate this proof mid-call.
 perform u.id from auth.users u where u.id=p_actor_id or exists
   (select 1 from public.user_roles r where r.user_id=u.id and r.role='super_admin')
   order by u.id for share;
 if not exists(select 1 from public.user_roles r join auth.users u on u.id=r.user_id
   where r.user_id=p_actor_id and r.role='super_admin'
   and u.email_confirmed_at is not null and u.deleted_at is null
   and (u.banned_until is null or u.banned_until<=pg_catalog.now())) then
   raise exception 'usable_super_admin_required' using errcode='42501';
 end if;
end $$;
revoke all on function private.sai_assert_role_actor(uuid) from public,anon,authenticated,service_role;

-- Defense in depth: even an overlooked privileged DELETE/UPDATE or Auth-delete
-- cascade cannot remove the last usable Super Admin role. No rows change here.
create or replace function private.sai_guard_last_super_admin()
returns trigger language plpgsql security definer set search_path = ''
as $$ begin
 if old.role='super_admin' and (tg_op='DELETE' or
   (new.user_id,new.role) is distinct from (old.user_id,old.role)) then
   if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
     raise exception 'read_committed_required' using errcode='25001';
   end if;
   perform pg_catalog.pg_advisory_xact_lock(831704,1);
   if not private.sai_has_other_usable_super_admin(old.user_id) then
     raise exception 'last_usable_super_admin_protected' using errcode='23514';
   end if;
 end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
revoke all on function private.sai_guard_last_super_admin() from public,anon,authenticated,service_role;
create trigger sai_guard_last_super_admin before delete or update of user_id,role
on public.user_roles for each row execute function private.sai_guard_last_super_admin();

-- Privileged implementation is private. The public API below remains invoker.
create or replace function private.sai_manage_role_assignment(
 p_actor_id uuid,p_target_id uuid,p_action text,p_role public.app_role,
 p_branch_ids uuid[],p_email_confirmed boolean,p_confirm_super_admin boolean,
 p_target_email text,p_full_name text
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_email text; v_name text; v_scoped boolean;
begin
 perform private.sai_assert_role_actor(p_actor_id);
 if p_target_id is null or p_action is null or p_action not in ('grant','revoke') or p_role is null then
   raise exception 'invalid_request' using errcode='22023';
 end if;
 v_scoped := p_role in ('admin','teacher','accountant','receptionist','librarian','content_editor');
 if (p_action='revoke' or not v_scoped) and coalesce(cardinality(p_branch_ids),0)<>0 then
   raise exception 'branch_not_allowed' using errcode='22023';
 end if;
 if p_action='grant' then
   -- Auth is authoritative; the service's boolean/email/name cannot forge it.
   select u.email,coalesce(nullif(pg_catalog.btrim(u.raw_user_meta_data->>'full_name'),''),u.email,'مستخدم جديد')
     into v_email,v_name from auth.users u where u.id=p_target_id
     and u.email_confirmed_at is not null and u.deleted_at is null
     and (u.banned_until is null or u.banned_until<=pg_catalog.now()) for share;
   if not found or p_email_confirmed is not true then
     raise exception 'verified_usable_account_required' using errcode='22023';
   end if;
   if p_role='super_admin' and p_confirm_super_admin is not true then
     raise exception 'super_admin_confirmation_required' using errcode='22023';
   end if;
   if v_scoped then
     if coalesce(cardinality(p_branch_ids),0)=0 or cardinality(p_branch_ids)<>
       (select count(distinct id) from unnest(p_branch_ids) b(id)) then
       raise exception 'distinct_branches_required' using errcode='22023';
     end if;
     perform b.id from public.branches b where b.id=any(p_branch_ids) and b.is_active order by b.id for share;
     if (select count(*) from public.branches where id=any(p_branch_ids) and is_active)<>cardinality(p_branch_ids) then
       raise exception 'active_branches_required' using errcode='22023';
     end if;
   end if;
   if exists(select 1 from public.user_roles where user_id=p_target_id and role=p_role) then
     raise exception 'role_already_assigned' using errcode='23505';
   end if;
   insert into public.profiles(id,full_name,email) values(p_target_id,v_name,v_email) on conflict(id) do nothing;
   insert into public.user_roles(user_id,role,assigned_by) values(p_target_id,p_role,p_actor_id);
   if v_scoped then
     -- Account-level scope is additive. Never erase another role's memberships.
     insert into public.branch_memberships(user_id,branch_id,is_active)
       select p_target_id,id,true from unnest(p_branch_ids) b(id)
       on conflict(user_id,branch_id) do update set is_active=true;
   end if;
 else
   if not exists(select 1 from public.user_roles where user_id=p_target_id and role=p_role) then
     raise exception 'role_not_assigned' using errcode='P0002';
   end if;
   delete from public.user_roles where user_id=p_target_id and role=p_role;
   if v_scoped and not exists(select 1 from public.user_roles where user_id=p_target_id
     and role in ('super_admin','admin','teacher','accountant','receptionist','librarian','content_editor')) then
     update public.branch_memberships set is_active=false where user_id=p_target_id and is_active;
   end if;
 end if;
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id,metadata)
 values(p_actor_id,case when p_action='grant' then 'role_grant' else 'role_revoke' end,
   'user_roles',p_target_id,jsonb_build_object('role',p_role,'source','role_management',
   'branch_ids',coalesce(to_jsonb(p_branch_ids),'[]'::jsonb)));
 return jsonb_build_object('ok',true,'action',p_action,'role',p_role);
end $$;
revoke all on function private.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)
 from public,anon,authenticated,service_role;
grant execute on function private.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text) to service_role;

create or replace function public.sai_manage_role_assignment(
 p_actor_id uuid,p_target_id uuid,p_action text,p_role public.app_role,
 p_branch_ids uuid[],p_email_confirmed boolean,p_confirm_super_admin boolean,p_target_email text,p_full_name text
) returns jsonb language sql security invoker set search_path = ''
as $$ select private.sai_manage_role_assignment($1,$2,$3,$4,$5,$6,$7,$8,$9) $$;
revoke all on function public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)
 from public,anon,authenticated,service_role;
grant execute on function public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text) to service_role;

-- Keep the old signature for diagnostics/rollback; no audited rows are deleted.
-- Checked-in clients and captured catalog dependencies contain no callers.
create or replace function public.sai_set_role(p_user_id uuid,p_role public.app_role,p_enabled boolean)
returns jsonb language plpgsql security invoker set search_path = ''
as $$ begin raise exception 'Use manage-roles with explicit branch/confirmation inputs' using errcode='42501'; end $$;
revoke all on function public.sai_set_role(uuid,public.app_role,boolean) from public,anon,authenticated,service_role;

-- No service-role REST fallback can bypass the private contract.
revoke insert,update,delete,truncate on public.user_roles from public,anon,authenticated,service_role;
revoke insert(user_id,role,assigned_by,assigned_at),update(user_id,role,assigned_by,assigned_at)
 on public.user_roles from public,anon,authenticated,service_role;

revoke insert,update,delete,truncate on public.branch_memberships from public,anon,authenticated,service_role;
revoke insert(user_id,branch_id,is_active),update(user_id,branch_id,is_active)
 on public.branch_memberships from public,anon,authenticated,service_role;
drop policy if exists branch_memberships_update_self_or_super_admin on public.branch_memberships;
create policy branch_memberships_update_super_admin on public.branch_memberships for update to authenticated
 using(private.sai_security_has_role('super_admin')) with check(private.sai_security_has_role('super_admin'));

-- Existing policies already use private helpers. Close only the public layer.
revoke execute on function public.sai_security_branch_member(uuid),public.sai_security_can_read_branch(uuid),
 public.sai_security_can_read_class(uuid),public.sai_security_can_read_session(uuid),
 public.sai_security_can_read_student(uuid),public.sai_security_has_role(public.app_role),
 public.sai_learning_can_grade_homework(uuid),public.sai_learning_can_manage_course(uuid),
 public.sai_learning_can_read_course(uuid),public.sai_learning_can_read_homework(uuid),public.sai_learning_own_student(uuid),
 public.sai_finance_can_read_student(uuid,uuid),public.sai_finance_has_role(text[]),public.sai_finance_staff(uuid,text[])
 from public,anon,authenticated;
grant execute on function public.sai_security_branch_member(uuid),public.sai_security_can_read_branch(uuid),
 public.sai_security_can_read_class(uuid),public.sai_security_can_read_session(uuid),
 public.sai_security_can_read_student(uuid),public.sai_security_has_role(public.app_role),
 public.sai_learning_can_grade_homework(uuid),public.sai_learning_can_manage_course(uuid),
 public.sai_learning_can_read_course(uuid),public.sai_learning_can_read_homework(uuid),public.sai_learning_own_student(uuid),
 public.sai_finance_can_read_student(uuid,uuid),public.sai_finance_has_role(text[]),public.sai_finance_staff(uuid,text[])
 to service_role;
notify pgrst,'reload schema';
commit;
