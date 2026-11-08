-- 011 · Homework management and release tracking
-- Adds the columns needed so a homework row can be edited, drafted, re-published
-- and deleted, and so learners can be told when something new was released.

alter table public.learning_homework
  add column if not exists published_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

-- Existing published homework is treated as released when it was created.
update public.learning_homework
set published_at = created_at
where is_published is true
  and published_at is null;

-- No new tables or policies are required:
--   * learning_homework_write (ALL) already allows managers of the course to
--     update and delete rows.
--   * learning_homework_select already hides drafts from students, so the
--     notification badge can only ever count published homework.
comment on column public.learning_homework.published_at is
  'When the homework last became visible to students; null while it is a draft.';
comment on column public.learning_homework.updated_at is
  'Last edit of the homework row.';