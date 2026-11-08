-- 015_cleanup_and_schema_history.sql
-- Housekeeping only. No schema changes are made to application tables.
--
-- 1. Remove the leftover diagnostic function created during the earlier
--    cross-project connectivity probe.
-- 2. Record the migrations that were applied to the live project before the
--    history table was being tracked, so `supabase db push` sees the schema
--    as fully up to date.
--
-- NOTE: 007_finance.sql is intentionally NOT recorded here. The finance
-- tables were never created in this project and the finance module is
-- deliberately disabled in the portal navigation. Recording it would make
-- the history claim objects that do not exist.

begin;

-- 1. Drop the leftover probe function (safe if already gone).
drop function if exists public.sai_probe_fn();

-- 2. Backfill migration history for the schema that is already live.
insert into supabase_migrations.schema_migrations (version, name) values
  ('005', 'admissions_session_directory'),
  ('006', 'attendance'),
  ('008', 'learning_portal'),
  ('009', 'lesson_content'),
  ('010', 'lesson_media_and_homework'),
  ('011', 'homework_management'),
  ('012', 'learning_inbox_and_teacher_provision'),
  ('013', 'teacher_account_management'),
  ('014', 'public_read_and_status_permissions')
on conflict (version) do nothing;

commit;