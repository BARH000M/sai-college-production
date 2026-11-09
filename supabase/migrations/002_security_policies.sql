-- Security baseline for the nine foundation tables. Apply only after the
-- migration history and this script have been verified in an isolated database.
-- The executing role must own these tables or bypass RLS; function ownership
-- must remain trusted and must not be transferred to a browser role.

-- A fixed public search path is safe only while untrusted users cannot create
-- objects there. Also fail closed if the application schema has changed.
do $$
begin
  if has_schema_privilege('public', 'public', 'CREATE')
     or has_schema_privilege('anon', 'public', 'CREATE')
     or has_schema_privilege('authenticated', 'public', 'CREATE') then
    raise exception 'Untrusted role can create objects in public schema';
  end if;
  if exists (
    select 1 from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
      and c.relname not in (
        'profiles', 'user_roles', 'branches', 'academic_sessions',
        'branch_memberships', 'classes', 'students',
        'parent_student_links', 'audit_logs'
      )
  ) then
    raise exception 'Unexpected public table: review security migration before proceeding';
  end if;
  if exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public'
      and (p.tablename, p.policyname) not in (
        ('profiles', 'profiles_select_self'),
        ('profiles', 'profiles_insert_self'),
        ('profiles', 'profiles_update_self'),
        ('user_roles', 'user_roles_select_self_or_super_admin'),
        ('branches', 'branches_select_authorized'),
        ('academic_sessions', 'academic_sessions_select_authorized'),
        ('branch_memberships', 'branch_memberships_select_self_or_super_admin'),
        ('classes', 'classes_select_authorized'),
        ('students', 'students_select_authorized'),
        ('parent_student_links', 'parent_student_links_select_parent_or_super_admin'),
        ('audit_logs', 'audit_logs_select_super_admin'),
        ('audit_logs', 'audit_logs_insert_self')
      )
  ) then
    raise exception 'Unexpected public RLS policy: review before proceeding';
  end if;
end;
$$;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.branches enable row level security;
alter table public.academic_sessions enable row level security;
alter table public.branch_memberships enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.parent_student_links enable row level security;
alter table public.audit_logs enable row level security;

-- Remove inherited PUBLIC grants and all existing table-level browser grants,
-- including TRUNCATE, REFERENCES and TRIGGER. Restore only the grants below.
revoke all privileges on table
  public.profiles, public.user_roles, public.branches,
  public.academic_sessions, public.branch_memberships, public.classes,
  public.students, public.parent_student_links, public.audit_logs
  from public, anon, authenticated;

grant select on table
  public.profiles, public.user_roles, public.branches,
  public.academic_sessions, public.branch_memberships, public.classes,
  public.students, public.parent_student_links, public.audit_logs
  to authenticated;

-- A user may create or update only their own profile and only these fields.
-- Email and timestamps cannot be spoofed through these column grants.
grant insert (id, full_name, phone, preferred_locale)
  on public.profiles to authenticated;
grant update (full_name, phone, preferred_locale)
  on public.profiles to authenticated;

-- Client-submitted audit entries are actor-bound, but their contents are
-- untrusted and must not substitute for server-generated security auditing.
grant insert (actor_user_id, action, entity_type, entity_id, metadata)
  on public.audit_logs to authenticated;

-- All helper decisions are based on auth.uid(); arguments identify resources,
-- never a principal whose privileges could be impersonated.
create or replace function public.sai_security_has_role(wanted_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$$;

create or replace function public.sai_security_branch_member(wanted_branch uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid()) and m.branch_id = wanted_branch
  );
$$;

create or replace function public.sai_security_can_read_student(wanted_student uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(s.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and public.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          public.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          public.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$$;

create or replace function public.sai_security_can_read_class(wanted_class uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        public.sai_security_has_role('super_admin')
        or (
          public.sai_security_has_role('admin')
          and public.sai_security_branch_member(c.branch_id)
        )
        or (
          public.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and public.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (public.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                public.sai_security_has_role('parent')
                and exists (
                  select 1 from public.parent_student_links l
                  where l.student_id = s.id
                    and l.parent_user_id = (select auth.uid())
                    and l.verified_at is not null
                )
              )
            )
        )
      )
  );
$$;

create or replace function public.sai_security_can_read_branch(wanted_branch uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.sai_security_has_role('super_admin')
    or (
      public.sai_security_branch_member(wanted_branch)
      and exists (
        select 1 from public.user_roles r
        where r.user_id = (select auth.uid())
          and r.role in (
            'admin', 'teacher', 'accountant', 'receptionist',
            'librarian', 'content_editor'
          )
      )
    )
    or exists (
      select 1 from public.students s
      where s.branch_id = wanted_branch
        and (
          (public.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            public.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$$;

create or replace function public.sai_security_can_read_session(wanted_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and public.sai_security_can_read_class(c.id)
    );
$$;

revoke all on function public.sai_security_has_role(public.app_role),
  public.sai_security_branch_member(uuid),
  public.sai_security_can_read_student(uuid),
  public.sai_security_can_read_class(uuid),
  public.sai_security_can_read_branch(uuid),
  public.sai_security_can_read_session(uuid)
  from public, anon, authenticated;

grant execute on function public.sai_security_has_role(public.app_role),
  public.sai_security_branch_member(uuid),
  public.sai_security_can_read_student(uuid),
  public.sai_security_can_read_class(uuid),
  public.sai_security_can_read_branch(uuid),
  public.sai_security_can_read_session(uuid)
  to authenticated;

-- Replace only policies owned by this migration; unexpected policies abort.
drop policy if exists profiles_select_self on public.profiles;
drop policy if exists profiles_insert_self on public.profiles;
drop policy if exists profiles_update_self on public.profiles;
drop policy if exists user_roles_select_self_or_super_admin on public.user_roles;
drop policy if exists branches_select_authorized on public.branches;
drop policy if exists academic_sessions_select_authorized on public.academic_sessions;
drop policy if exists branch_memberships_select_self_or_super_admin on public.branch_memberships;
drop policy if exists classes_select_authorized on public.classes;
drop policy if exists students_select_authorized on public.students;
drop policy if exists parent_student_links_select_parent_or_super_admin on public.parent_student_links;
drop policy if exists audit_logs_select_super_admin on public.audit_logs;
drop policy if exists audit_logs_insert_self on public.audit_logs;

-- Each user can read only their own profile.
create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

-- Users may insert and update their own profile, subject to column grants.
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (id = (select auth.uid()));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Users may read their own assignments; super admins can audit all roles.
-- No role write policy or browser write grant is provided.
create policy user_roles_select_self_or_super_admin on public.user_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or public.sai_security_has_role('super_admin'));

-- Branch access is limited to scoped staff and learners or linked parents.
create policy branches_select_authorized on public.branches
  for select to authenticated
  using (public.sai_security_can_read_branch(id));

-- Sessions are global records: non-super-admins see sessions only through a
-- class they are allowed to read.
create policy academic_sessions_select_authorized on public.academic_sessions
  for select to authenticated
  using (public.sai_security_can_read_session(id));

-- A user sees their own branch memberships; super admins may inspect all.
create policy branch_memberships_select_self_or_super_admin on public.branch_memberships
  for select to authenticated
  using (user_id = (select auth.uid()) or public.sai_security_has_role('super_admin'));

-- Teachers see their assigned classes; learners and parents see their own
-- classes; admins see only classes in their member branches.
create policy classes_select_authorized on public.classes
  for select to authenticated
  using (public.sai_security_can_read_class(id));

-- Student records follow ownership, verified links, assigned classes and scope.
create policy students_select_authorized on public.students
  for select to authenticated
  using (public.sai_security_can_read_student(id));

-- Parents see their verified links; super admins may inspect all links.
create policy parent_student_links_select_parent_or_super_admin on public.parent_student_links
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin')
    or (
      public.sai_security_has_role('parent')
      and parent_user_id = (select auth.uid())
      and verified_at is not null
    )
  );

-- Audit rows have no branch field: only super admins can read them.
-- No browser update, delete or truncate privilege is granted.
create policy audit_logs_select_super_admin on public.audit_logs
  for select to authenticated
  using (public.sai_security_has_role('super_admin'));

-- Actor attribution is enforced, but other client-submitted fields are untrusted.
create policy audit_logs_insert_self on public.audit_logs
  for insert to authenticated
  with check (actor_user_id = (select auth.uid()));
