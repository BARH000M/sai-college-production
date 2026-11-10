-- Library circulation and scoped communications.
-- Scope: one college branch per record, RLS enforced, catalog read for all
-- authenticated members, circulation writes limited to library staff.
-- Issuing and returning are single-statement SQL functions so the copy count
-- and the loan row can never drift apart.

create table if not exists public.library_items (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  title text not null check (length(btrim(title)) > 0),
  author text,
  category text,
  isbn text,
  shelf_code text,
  copies_total integer not null default 1 check (copies_total > 0),
  copies_available integer not null default 1 check (copies_available >= 0),
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (copies_available <= copies_total)
);

create table if not exists public.library_loans (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.library_items(id),
  branch_id uuid not null references public.branches(id),
  student_id uuid not null references public.students(id),
  issued_by uuid not null references auth.users(id),
  issued_at timestamptz not null default now(),
  due_date date not null,
  returned_at timestamptz,
  returned_by uuid references auth.users(id),
  notes text
);

create index if not exists library_loans_item_idx on public.library_loans(item_id);
create index if not exists library_loans_student_idx on public.library_loans(student_id);
create index if not exists library_loans_open_idx on public.library_loans(item_id) where returned_at is null;
create index if not exists library_items_branch_idx on public.library_items(branch_id);

-- One open loan per copy is enforced at the item level by copies_available;
-- a student may not hold two open loans of the same title.
create unique index if not exists library_loans_one_open_per_student
  on public.library_loans(student_id, item_id) where returned_at is null;

alter table public.library_items enable row level security;
alter table public.library_loans enable row level security;

grant select, insert, update, delete on public.library_items to authenticated;
grant select, insert, update, delete on public.library_loans to authenticated;

drop policy if exists library_items_read on public.library_items;
create policy library_items_read on public.library_items for select to authenticated
  using (
    is_active
    or exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and r.role in ('super_admin', 'admin', 'librarian', 'teacher'))
  );

drop policy if exists library_items_write on public.library_items;
create policy library_items_write on public.library_items for all to authenticated
  using (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin', 'librarian') and public.sai_security_branch_member(branch_id))))
  )
  with check (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin', 'librarian') and public.sai_security_branch_member(branch_id))))
  );

drop policy if exists library_loans_read on public.library_loans;
create policy library_loans_read on public.library_loans for select to authenticated
  using (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin'
        or (r.role in ('admin', 'librarian', 'receptionist', 'teacher') and public.sai_security_branch_member(library_loans.branch_id))))
    or exists (select 1 from public.students s where s.id = library_loans.student_id and s.user_id = (select auth.uid()))
    or exists (select 1 from public.parent_student_links l
      join public.students s on s.id = l.student_id and s.id = library_loans.student_id
      where l.parent_user_id = (select auth.uid()) and l.verified_at is not null)
  );

drop policy if exists library_loans_write on public.library_loans;
create policy library_loans_write on public.library_loans for all to authenticated
  using (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin', 'librarian') and public.sai_security_branch_member(library_loans.branch_id))))
  )
  with check (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin', 'librarian') and public.sai_security_branch_member(library_loans.branch_id))))
  );

create or replace function public.sai_library_issue(p_item uuid, p_student uuid, p_due date)
returns uuid language sql security invoker as $$
  with updated as (
    update public.library_items
      set copies_available = copies_available - 1, updated_at = now()
    where id = p_item and is_active and copies_available > 0
    returning id, branch_id
  )
  insert into public.library_loans(item_id, branch_id, student_id, issued_by, due_date)
  select updated.id, updated.branch_id, p_student, auth.uid(), p_due from updated
  returning id;
$$;

create or replace function public.sai_library_return(p_loan uuid)
returns void language sql security invoker as $$
  with returned as (
    update public.library_loans
      set returned_at = now(), returned_by = auth.uid()
    where id = p_loan and returned_at is null
    returning item_id
  )
  update public.library_items i
    set copies_available = least(i.copies_total, i.copies_available + 1), updated_at = now()
    from returned r where i.id = r.item_id;
$$;

revoke all on function public.sai_library_issue(uuid, uuid, date) from public, anon;
revoke all on function public.sai_library_return(uuid) from public, anon;
grant execute on function public.sai_library_issue(uuid, uuid, date) to authenticated;
grant execute on function public.sai_library_return(uuid) to authenticated;

-- ---------------------------------------------------------------- communications

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid references public.branches(id),
  title text not null check (length(btrim(title)) > 0),
  body text not null check (length(btrim(body)) > 0),
  audience text not null default 'all' check (audience in ('all', 'staff', 'teachers', 'parents', 'students')),
  is_published boolean not null default false,
  published_at timestamptz,
  expires_at timestamptz,
  published_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists announcements_branch_idx on public.announcements(branch_id);
create index if not exists announcements_published_idx on public.announcements(is_published, published_at desc);

create table if not exists public.announcement_reads (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;

grant select, insert, update, delete on public.announcements to authenticated;
grant select, insert, update, delete on public.announcement_reads to authenticated;

drop policy if exists announcements_read on public.announcements;
create policy announcements_read on public.announcements for select to authenticated
  using (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin' or (r.role in ('admin', 'content_editor') and public.sai_security_branch_member(branch_id))))
    or (
      is_published
      and (expires_at is null or expires_at > now())
      and (branch_id is null or public.sai_security_branch_member(branch_id)
        or exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'super_admin'))
      and (
        audience = 'all'
        or exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and (
          (audience = 'staff' and r.role in ('super_admin', 'admin', 'teacher', 'accountant', 'receptionist', 'librarian', 'content_editor'))
          or (audience = 'teachers' and r.role = 'teacher')
          or (audience = 'parents' and r.role = 'parent')
          or (audience = 'students' and r.role = 'student')
        ))
      )
    )
  );

drop policy if exists announcements_write on public.announcements;
create policy announcements_write on public.announcements for all to authenticated
  using (
    published_by = (select auth.uid())
    or exists (select 1 from public.user_roles r where r.user_id = (select auth.uid()) and r.role = 'super_admin')
  )
  with check (
    exists (select 1 from public.user_roles r where r.user_id = (select auth.uid())
      and (r.role = 'super_admin'
        or (r.role in ('admin', 'content_editor')
          and (branch_id is null or public.sai_security_branch_member(branch_id)))))
  );

drop policy if exists announcement_reads_own on public.announcement_reads;
create policy announcement_reads_own on public.announcement_reads for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));