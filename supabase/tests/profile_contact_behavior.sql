-- Synthetic own-contact tests; run only in the native isolated test cluster.
create schema auth;
create role anon nologin;
create role authenticated nologin;
create function auth.uid() returns uuid language sql stable as
  $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth,public to authenticated,anon;
grant execute on function auth.uid() to authenticated;
create table public.profiles (
  id uuid primary key, full_name text not null, email text, phone text,
  preferred_locale text not null default 'ar',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
grant select on public.profiles to authenticated;
grant update(full_name,phone,preferred_locale) on public.profiles to authenticated;
create policy profiles_select_self on public.profiles for select to authenticated using (id=(select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated
using (id=(select auth.uid())) with check (id=(select auth.uid()));
insert into public.profiles(id,full_name,email) values
('00000000-0000-0000-0000-000000000001','Original Name','own@example.test'),
('00000000-0000-0000-0000-000000000002','Other Name','other@example.test');
\ir ../deployment/phase3c-main/001_own_contact_validation.sql

set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
do $$
declare v_role text; v_count integer; v_before timestamptz;
begin
  -- All nine roles share authenticated SQL privileges; application roles never widen own-row access.
  foreach v_role in array array['super_admin','admin','teacher','accountant','receptionist','librarian','student','parent','content_editor'] loop
    perform set_config('request.jwt.claims',json_build_object('role','authenticated','app_role',v_role)::text,false);
    select updated_at into v_before from public.profiles where id=auth.uid();
    update public.profiles set full_name='  اسم المستخدم '||v_role||'  ',phone='+967 777 123 456',preferred_locale='en' where id=auth.uid();
    if not exists(select 1 from public.profiles where id=auth.uid() and full_name='اسم المستخدم '||v_role
        and phone='+967 777 123 456' and preferred_locale='en' and updated_at>=v_before) then
      raise exception 'Valid own update failed for %',v_role;
    end if;
    update public.profiles set full_name='Forbidden Other' where id='00000000-0000-0000-0000-000000000002';
    get diagnostics v_count=row_count;
    if v_count<>0 then raise exception 'Cross-account update permitted for %',v_role; end if;
    select count(*) into v_count from public.profiles;
    if v_count<>1 then raise exception 'Cross-account read permitted'; end if;
  end loop;
  begin update public.profiles set email='forged@example.test' where id=auth.uid(); raise exception 'email write accepted';
  exception when insufficient_privilege then null; end;
  begin update public.profiles set id='00000000-0000-0000-0000-000000000003' where id=auth.uid(); raise exception 'identity write accepted';
  exception when insufficient_privilege then null; end;
  begin update public.profiles set updated_at='2000-01-01' where id=auth.uid(); raise exception 'timestamp write accepted';
  exception when insufficient_privilege then null; end;
  begin update public.profiles set full_name='x' where id=auth.uid(); raise exception 'short name accepted'; exception when invalid_parameter_value then null; end;
  begin update public.profiles set full_name=repeat('中',121) where id=auth.uid(); raise exception 'long name accepted'; exception when invalid_parameter_value then null; end;
  begin update public.profiles set full_name=E'Name\nInjected' where id=auth.uid(); raise exception 'control accepted'; exception when invalid_parameter_value then null; end;
  begin update public.profiles set phone='+()---' where id=auth.uid(); raise exception 'phone accepted'; exception when invalid_parameter_value then null; end;
  begin update public.profiles set preferred_locale='xx' where id=auth.uid(); raise exception 'locale accepted'; exception when invalid_parameter_value then null; end;
  update public.profiles set phone=' ' where id=auth.uid();
  if not exists(select 1 from public.profiles where id=auth.uid() and phone is null) then raise exception 'empty phone not normalized'; end if;
end $$;
reset role;
set role anon;
do $$begin
  begin update public.profiles set full_name='Anonymous'; raise exception 'anon write accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$begin
  if (select full_name from public.profiles where id='00000000-0000-0000-0000-000000000002')<>'Other Name' then raise exception 'Other account changed'; end if;
end $$;
select 'PASS: nine roles, own contact, immutable identity/email/time, validation and anonymous denial';
