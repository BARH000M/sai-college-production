-- 010: lesson media storage + homework authoring
-- Applied to the live project on 2026-11-08.
-- 1) A private storage bucket for lesson video/audio/documents.
-- 2) Object paths are "<lesson_id>/<timestamp>-<file>" so access can be derived from the lesson.
-- 3) Read access follows the lesson's own audience (enrolled students, linked parents,
--    assigned teacher, branch admins). Write access follows "can manage course".
-- 4) Homework creation needs no new table: the existing learning_homework_write policy
--    already allows super_admin / branch admin / assigned teacher.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lesson-media', 'lesson-media', false, 104857600,
        array['video/mp4','video/webm','video/ogg','audio/mpeg','audio/mp4','audio/ogg',
              'audio/wav','audio/webm','image/png','image/jpeg','application/pdf'])
on conflict (id) do update
  set public = false,
      file_size_limit = 104857600,
      allowed_mime_types = excluded.allowed_mime_types;

alter table public.learning_lessons
  add column if not exists content_path text,
  add column if not exists content_file_name text;

drop policy if exists "lesson_media_read" on storage.objects;
create policy "lesson_media_read" on storage.objects
for select to authenticated
using (
  bucket_id = 'lesson-media'
  and exists (
    select 1 from public.learning_lessons l
    where l.id::text = (storage.foldername(name))[1]
      and (
        public.sai_learning_can_manage_course(l.course_id)
        or (l.is_published and public.sai_learning_can_read_course(l.course_id))
      )
  )
);

drop policy if exists "lesson_media_write" on storage.objects;
create policy "lesson_media_write" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'lesson-media'
  and exists (
    select 1 from public.learning_lessons l
    where l.id::text = (storage.foldername(name))[1]
      and public.sai_learning_can_manage_course(l.course_id)
  )
);

drop policy if exists "lesson_media_update" on storage.objects;
create policy "lesson_media_update" on storage.objects
for update to authenticated
using (
  bucket_id = 'lesson-media'
  and exists (
    select 1 from public.learning_lessons l
    where l.id::text = (storage.foldername(name))[1]
      and public.sai_learning_can_manage_course(l.course_id)
  )
)
with check (
  bucket_id = 'lesson-media'
  and exists (
    select 1 from public.learning_lessons l
    where l.id::text = (storage.foldername(name))[1]
      and public.sai_learning_can_manage_course(l.course_id)
  )
);

drop policy if exists "lesson_media_delete" on storage.objects;
create policy "lesson_media_delete" on storage.objects
for delete to authenticated
using (
  bucket_id = 'lesson-media'
  and exists (
    select 1 from public.learning_lessons l
    where l.id::text = (storage.foldername(name))[1]
      and public.sai_learning_can_manage_course(l.course_id)
  )
);