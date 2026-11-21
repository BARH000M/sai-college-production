-- =============================================================================
-- V5.0 — Group A (shared audit writer) + Group B (permanent media library)
-- Institution: Yemen SAI Educational College
-- Applied: 2026-11-21 against project reprjetryjveowspusxd
--
-- Purpose
--   Replace the browser-backed Media Library catalogue with an authoritative
--   table plus a private storage bucket. Group A provides one audit writer that
--   Groups C–F reuse so every institutional mutation leaves one audit trail.
--
-- Reused existing objects
--   public.branches, public.learning_courses, public.learning_lessons,
--   public.profiles, public.audit_logs,
--   public.sai_security_has_role(app_role), public.sai_security_can_read_branch(uuid)
--
-- New objects
--   public.sai_media_assets (table, 5 indexes, 3 RLS policies)
--   public.sai_write_audit(text, text, uuid, jsonb)  -- SECURITY INVOKER
--   storage bucket "media" (private) + 3 object policies
--
-- Security notes
--   * The bucket is PRIVATE. Private media is served through signed URLs only;
--     no asset is reachable through an unrestricted public URL.
--   * `sai_write_audit` is SECURITY INVOKER, not DEFINER, so public.audit_logs
--     RLS (policy `audit_logs_insert_self`) remains the only authority. A
--     SECURITY DEFINER variant was rejected deliberately: it would have been
--     executable by PUBLIC and allowed anonymous audit spam.
--   * There is intentionally NO delete policy on either object. Referenced media
--     is archived (status = 'archived'), never destroyed.
--   * Students can read only `status = 'published'` rows inside their branch.
--
-- Data impact
--   Additive only. No existing row is read, rewritten or deleted. Workspace data
--   already in browser storage is NOT uploaded by this migration.
--
-- Verification
--   select * from pg_policies where tablename = 'sai_media_assets';
--   select id, public from storage.buckets where id = 'media';  -- public = false
--   select prosecdef from pg_proc where proname = 'sai_write_audit'; -- false
--
-- Rollback (only if the group is abandoned before any media is stored)
--   drop policy if exists sai_media_objects_read   on storage.objects;
--   drop policy if exists sai_media_objects_write  on storage.objects;
--   drop policy if exists sai_media_objects_modify on storage.objects;
--   delete from storage.buckets where id = 'media' and not exists
--     (select 1 from storage.objects where bucket_id = 'media');
--   drop function if exists public.sai_write_audit(text, text, uuid, jsonb);
--   drop table if exists public.sai_media_assets;
--
--   Once media rows exist, rollback is ARCHIVE-ONLY: set status = 'archived'.
--   Dropping the table would orphan stored binaries.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Group A — shared audit writer (SECURITY INVOKER: audit_logs RLS applies)
-- -----------------------------------------------------------------------------
create or replace function public.sai_write_audit(
  p_action      text,
  p_entity_type text,
  p_entity_id   uuid,
  p_metadata    jsonb default '{}'::jsonb
) returns void
language sql
security invoker
set search_path = public
as $$
  insert into public.audit_logs (action, entity_type, entity_id, actor_user_id, metadata)
  values (
    coalesce(nullif(btrim(p_action), ''), 'unknown'),
    coalesce(nullif(btrim(p_entity_type), ''), 'unknown'),
    p_entity_id,
    auth.uid(),
    coalesce(p_metadata, '{}'::jsonb)
  );
$$;

-- -----------------------------------------------------------------------------
-- Group B — permanent media catalogue
-- -----------------------------------------------------------------------------
create table if not exists public.sai_media_assets (
  id             uuid primary key default gen_random_uuid(),
  media_type     text not null check (media_type in ('image', 'audio', 'video', 'document')),
  title_ar       text not null check (length(btrim(title_ar)) > 0),
  title_en       text,
  title_zh       text,
  description    text,
  category       text,
  storage_bucket text not null default 'media' check (storage_bucket = 'media'),
  storage_path   text not null check (length(btrim(storage_path)) > 0),
  mime_type      text,
  size_bytes     bigint check (size_bytes is null or size_bytes >= 0),
  branch_id      uuid references public.branches(id) on delete restrict,
  course_id      uuid references public.learning_courses(id) on delete set null,
  lesson_id      uuid references public.learning_lessons(id) on delete set null,
  status         text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  version        integer not null default 1 check (version > 0),
  uploaded_by    uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  archived_at    timestamptz,
  constraint sai_media_assets_storage_path_key unique (storage_bucket, storage_path)
);

comment on table public.sai_media_assets is
  'V5.0 permanent media catalogue. Binaries live in the private "media" bucket; this table is the only authoritative reference. Archived assets are never hard-deleted while referenced.';

create index if not exists sai_media_assets_branch_idx on public.sai_media_assets (branch_id);
create index if not exists sai_media_assets_course_idx on public.sai_media_assets (course_id);
create index if not exists sai_media_assets_lesson_idx on public.sai_media_assets (lesson_id);
create index if not exists sai_media_assets_status_idx on public.sai_media_assets (status);
create index if not exists sai_media_assets_type_idx   on public.sai_media_assets (media_type);

alter table public.sai_media_assets enable row level security;

create policy sai_media_assets_select on public.sai_media_assets
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
    or public.sai_security_has_role('teacher'::app_role)
    or public.sai_security_has_role('librarian'::app_role)
    or (
      status = 'published'
      and (branch_id is null or public.sai_security_can_read_branch(branch_id))
    )
  );

create policy sai_media_assets_insert on public.sai_media_assets
  for insert to authenticated
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
  );

create policy sai_media_assets_update on public.sai_media_assets
  for update to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
  )
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
  );

-- -----------------------------------------------------------------------------
-- Group B — private storage bucket + object policies
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict (id) do update set public = false;

create policy sai_media_objects_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'media'
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
      or public.sai_security_has_role('teacher'::app_role)
      or public.sai_security_has_role('librarian'::app_role)
      or exists (
        select 1 from public.sai_media_assets a
        where a.storage_bucket = 'media'
          and a.storage_path = storage.objects.name
          and a.status = 'published'
      )
    )
  );

create policy sai_media_objects_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'media'
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
    )
  );

create policy sai_media_objects_modify on storage.objects
  for update to authenticated
  using (
    bucket_id = 'media'
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
    )
  )
  with check (
    bucket_id = 'media'
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
    )
  );