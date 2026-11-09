-- SAI College production foundation
-- Apply in Supabase SQL Editor or save as supabase/migrations/001_initial_schema.sql

create extension if not exists pgcrypto;

create type public.app_role as enum (
  'super_admin','admin','teacher','accountant','receptionist',
  'librarian','student','parent','content_editor'
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  phone text,
  preferred_locale text not null default 'ar',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  assigned_by uuid references auth.users(id),
  assigned_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,
  address text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.academic_sessions (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  starts_on date not null,
  ends_on date not null,
  is_active boolean not null default false,
  check (ends_on > starts_on)
);

create table public.branch_memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  primary key (user_id, branch_id)
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches(id),
  session_id uuid not null references public.academic_sessions(id),
  name text not null,
  program text not null,
  capacity integer not null default 20 check (capacity > 0),
  teacher_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  branch_id uuid not null references public.branches(id),
  admission_no text not null unique,
  full_name text not null,
  date_of_birth date,
  class_id uuid references public.classes(id),
  status text not null default 'active' check (status in ('active','inactive','graduated','withdrawn')),
  created_at timestamptz not null default now()
);

create table public.parent_student_links (
  parent_user_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  verified_at timestamptz,
  verified_by uuid references auth.users(id),
  primary key (parent_user_id, student_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index classes_scope_idx on public.classes(branch_id, session_id);
create index students_scope_idx on public.students(branch_id, class_id);
create index parent_links_student_idx on public.parent_student_links(student_id);