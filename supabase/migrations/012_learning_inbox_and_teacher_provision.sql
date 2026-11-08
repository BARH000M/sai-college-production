-- 012: server-side learning inbox marker + teacher account provisioning support
--
-- The "seen" timestamp used to live in browser localStorage, which meant the
-- notification badge differed between devices. It now lives per account.

create table if not exists public.learning_inbox_reads (
  user_id uuid primary key references auth.users(id) on delete cascade,
  seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.learning_inbox_reads enable row level security;

revoke all on public.learning_inbox_reads from anon;
grant select, insert, update on public.learning_inbox_reads to authenticated;

drop policy if exists learning_inbox_reads_select_own on public.learning_inbox_reads;
create policy learning_inbox_reads_select_own on public.learning_inbox_reads
  for select using (user_id = auth.uid());

drop policy if exists learning_inbox_reads_insert_own on public.learning_inbox_reads;
create policy learning_inbox_reads_insert_own on public.learning_inbox_reads
  for insert with check (user_id = auth.uid());

drop policy if exists learning_inbox_reads_update_own on public.learning_inbox_reads;
create policy learning_inbox_reads_update_own on public.learning_inbox_reads
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Teacher accounts are provisioned by the provision-learning-account edge function.
-- It reuses the existing structures: user_roles(role = 'teacher'),
-- branch_memberships(active) for the class branch, and classes.teacher_id.
-- No schema change is required for that flow.