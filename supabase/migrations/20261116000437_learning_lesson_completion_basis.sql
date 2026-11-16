-- Migration 016 created the vocabulary bank and notification read marker with
-- RLS policies but never granted table privileges to the client role, so
-- policy-checked vocabulary writes fail with 42501. Grant them now; the
-- existing policies still decide which rows each operation may touch.
grant select, insert, update, delete on public.learning_vocabulary to authenticated;
grant select, insert, update, delete on public.learning_vocab_progress to authenticated;
grant select, insert, update on public.notification_reads to authenticated;

-- Records how a lesson was completed. Completion through the exercise screens
-- is written by the student's own account, so it is self-reported practice
-- completion, not server-verified mastery. Rows predating this workflow keep
-- completion_basis = null and stay labelled unverified in the UI.
alter table public.learning_lesson_progress
  add column if not exists completion_basis text;

alter table public.learning_lesson_progress
  drop constraint if exists learning_lesson_progress_completion_basis_check;
alter table public.learning_lesson_progress
  add constraint learning_lesson_progress_completion_basis_check
  check (completion_basis is null or completion_basis = 'self_reported');

-- RLS and grants are unchanged: only the student's own account writes their
-- progress rows; the new column inherits the existing column-level access.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'learning_lesson_progress'
      and policyname = 'learning_progress_write'
  ) then
    raise exception 'Expected learning_progress_write policy is missing';
  end if;
end;
$$;
