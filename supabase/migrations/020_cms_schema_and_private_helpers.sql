-- 020 — Reconstruct the minimum CMS contract used by the checked-in clients
-- and install private helper prerequisites before migration 022.
--
-- The original CMS DDL and write-policy predicates are not present in this
-- repository or its local Git history. This is a new additive bootstrap, not a
-- recovered historical migration. Existing tables and existing write-policy
-- predicates are left intact; clean Preview databases receive the minimum
-- schema required by src/portal/lib/cms.ts.

begin;

-- Migration 025 normalizes these functions, but migration 022 already uses
-- them. Create the same implementations here so a clean replay has the
-- prerequisites before 022 runs.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.sai_security_has_role(wanted_role public.app_role)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$function$;

create or replace function private.sai_security_branch_member(wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.branch_memberships m
    where m.user_id = (select auth.uid())
      and m.branch_id = wanted_branch and m.is_active
  );
$function$;

create or replace function private.sai_security_can_read_branch(wanted_branch uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_security_has_role('super_admin')
    or (
      private.sai_security_branch_member(wanted_branch)
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
          (private.sai_security_has_role('student')
            and s.user_id = (select auth.uid()))
          or (
            private.sai_security_has_role('parent')
            and exists (
              select 1 from public.parent_student_links l
              where l.student_id = s.id
                and l.parent_user_id = (select auth.uid())
                and l.verified_at is not null
            )
          )
        )
    );
$function$;

create or replace function private.sai_security_can_read_class(wanted_class uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1
    from public.classes c
    where c.id = wanted_class
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(c.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and c.teacher_id = (select auth.uid())
          and private.sai_security_branch_member(c.branch_id)
        )
        or exists (
          select 1 from public.students s
          where s.class_id = c.id and s.branch_id = c.branch_id
            and (
              (private.sai_security_has_role('student')
                and s.user_id = (select auth.uid()))
              or (
                private.sai_security_has_role('parent')
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
$function$;

create or replace function private.sai_security_can_read_session(wanted_session uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select private.sai_security_has_role('super_admin')
    or exists (
      select 1 from public.classes c
      where c.session_id = wanted_session
        and private.sai_security_can_read_class(c.id)
    );
$function$;

create or replace function private.sai_security_can_read_student(wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1
    from public.students s
    where s.id = wanted_student
      and (
        private.sai_security_has_role('super_admin')
        or (
          private.sai_security_has_role('admin')
          and private.sai_security_branch_member(s.branch_id)
        )
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(s.branch_id)
          and exists (
            select 1 from public.classes c
            where c.id = s.class_id and c.branch_id = s.branch_id
              and c.teacher_id = (select auth.uid())
          )
        )
        or (
          private.sai_security_has_role('student')
          and s.user_id = (select auth.uid())
        )
        or (
          private.sai_security_has_role('parent')
          and exists (
            select 1 from public.parent_student_links l
            where l.student_id = s.id
              and l.parent_user_id = (select auth.uid())
              and l.verified_at is not null
          )
        )
      )
  );
$function$;

create or replace function private.sai_learning_can_manage_course(wanted_course uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course
      and (
        private.sai_security_has_role('super_admin')
        or (private.sai_security_has_role('admin') and private.sai_security_branch_member(c.branch_id))
        or (
          private.sai_security_has_role('teacher')
          and private.sai_security_branch_member(c.branch_id)
          and (
            c.teacher_id = (select auth.uid())
            or exists (
              select 1 from public.classes cl
              where cl.id = c.class_id and cl.teacher_id = (select auth.uid())
            )
          )
        )
      )
  );
$function$;

create or replace function private.sai_learning_can_read_course(wanted_course uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_courses c
    where c.id = wanted_course and private.sai_security_can_read_class(c.class_id)
  );
$function$;

create or replace function private.sai_learning_can_read_homework(wanted_homework uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_homework h
    join public.learning_courses c on c.id = h.course_id
    where h.id = wanted_homework
      and (h.is_published or private.sai_learning_can_manage_course(c.id))
      and private.sai_security_can_read_class(c.class_id)
  );
$function$;

create or replace function private.sai_learning_can_grade_homework(wanted_homework uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.learning_homework h
    where h.id = wanted_homework and private.sai_learning_can_manage_course(h.course_id)
  );
$function$;

create or replace function private.sai_learning_own_student(wanted_student uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog, public, private
as $function$
  select exists (
    select 1 from public.students s
    where s.id = wanted_student and s.user_id = (select auth.uid())
  );
$function$;

revoke execute on function
  private.sai_security_has_role(public.app_role),
  private.sai_security_branch_member(uuid),
  private.sai_security_can_read_branch(uuid),
  private.sai_security_can_read_class(uuid),
  private.sai_security_can_read_session(uuid),
  private.sai_security_can_read_student(uuid),
  private.sai_learning_can_manage_course(uuid),
  private.sai_learning_can_read_course(uuid),
  private.sai_learning_can_read_homework(uuid),
  private.sai_learning_can_grade_homework(uuid),
  private.sai_learning_own_student(uuid)
from public, anon;

grant execute on function
  private.sai_security_has_role(public.app_role),
  private.sai_security_branch_member(uuid),
  private.sai_security_can_read_branch(uuid),
  private.sai_security_can_read_class(uuid),
  private.sai_security_can_read_session(uuid),
  private.sai_security_can_read_student(uuid),
  private.sai_learning_can_manage_course(uuid),
  private.sai_learning_can_read_course(uuid),
  private.sai_learning_can_read_homework(uuid),
  private.sai_learning_can_grade_homework(uuid),
  private.sai_learning_own_student(uuid)
to authenticated;

-- These are the minimum columns read or written by the checked-in CMS client.
-- CREATE TABLE IF NOT EXISTS never replaces deployed tables or their data.
create table if not exists public.cms_programs (
  id uuid primary key default gen_random_uuid(),
  title_ar text not null default '',
  title_en text not null default '',
  summary_ar text not null default '',
  summary_en text not null default '',
  duration_ar text not null default '',
  duration_en text not null default '',
  icon text not null default '',
  is_published boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cms_news (
  id uuid primary key default gen_random_uuid(),
  title_ar text not null default '',
  title_en text not null default '',
  summary_ar text not null default '',
  summary_en text not null default '',
  tag_ar text not null default '',
  tag_en text not null default '',
  image_url text,
  published_at date not null default current_date,
  is_published boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cms_site_content (
  key text primary key,
  section text not null default '',
  label_ar text not null default '',
  value_ar text not null default '',
  value_en text not null default '',
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists cms_programs_sort_created_idx
  on public.cms_programs (sort_order, created_at);
create index if not exists cms_news_sort_published_idx
  on public.cms_news (sort_order, published_at desc);
create index if not exists cms_site_content_sort_idx
  on public.cms_site_content (sort_order);

alter table public.cms_programs enable row level security;
alter table public.cms_news enable row level security;
alter table public.cms_site_content enable row level security;

grant select on table
  public.cms_programs, public.cms_news, public.cms_site_content
to anon, authenticated;
grant insert, update, delete on table
  public.cms_programs, public.cms_news
to authenticated;
grant update on table public.cms_site_content to authenticated;

do $cms$
begin
  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_programs'
      and policyname = 'cms_programs_public_read'
  ) then
    create policy cms_programs_public_read on public.cms_programs
      for select to public using (is_published);
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_programs'
      and policyname = 'cms_programs_staff_read'
  ) then
    create policy cms_programs_staff_read on public.cms_programs
      for select to authenticated
      using (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      );
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_programs'
      and policyname = 'cms_programs_write'
  ) then
    create policy cms_programs_write on public.cms_programs
      for all to authenticated
      using (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      )
      with check (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      );
  else
    alter policy cms_programs_write on public.cms_programs to authenticated;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_news'
      and policyname = 'cms_news_public_read'
  ) then
    create policy cms_news_public_read on public.cms_news
      for select to public using (is_published);
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_news'
      and policyname = 'cms_news_staff_read'
  ) then
    create policy cms_news_staff_read on public.cms_news
      for select to authenticated
      using (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      );
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_news'
      and policyname = 'cms_news_write'
  ) then
    create policy cms_news_write on public.cms_news
      for all to authenticated
      using (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      )
      with check (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      );
  else
    alter policy cms_news_write on public.cms_news to authenticated;
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_site_content'
      and policyname = 'cms_site_content_public_read'
  ) then
    create policy cms_site_content_public_read on public.cms_site_content
      for select to public using (true);
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies
    where schemaname = 'public' and tablename = 'cms_site_content'
      and policyname = 'cms_site_content_write'
  ) then
    create policy cms_site_content_write on public.cms_site_content
      for all to authenticated
      using (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      )
      with check (
        private.sai_security_has_role('super_admin'::public.app_role)
        or private.sai_security_has_role('admin'::public.app_role)
        or private.sai_security_has_role('content_editor'::public.app_role)
      );
  else
    alter policy cms_site_content_write on public.cms_site_content to authenticated;
  end if;
end
$cms$;

commit;
