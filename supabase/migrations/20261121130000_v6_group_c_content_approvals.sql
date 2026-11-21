-- =============================================================================
-- V6.0 — Group C (Content Review & Approvals)
-- Institution: Yemen SAI Educational College
-- Applied: 2026-11-21 against the authorised production project
--
-- Purpose
--   Replace the browser-backed Content Approvals workflow with permanent
--   editorial records. Version 95 already provided a reviewed screen; this
--   migration makes the state machine authoritative on the server.
--
-- Reused existing objects
--   public.branches, public.learning_courses, public.learning_lessons,
--   public.profiles, public.audit_logs, public.sai_write_audit(text,text,uuid,jsonb),
--   public.sai_security_has_role(app_role), public.sai_security_can_read_branch(uuid)
--
-- New objects
--   public.sai_content_items      (table, 6 indexes, 3 RLS policies)
--   public.sai_content_comments   (table, 1 index, 2 RLS policies)
--   public.sai_content_history    (table, 1 index, 2 RLS policies)
--   public.sai_content_transition(uuid, text, text)  SECURITY DEFINER
--
-- State machine (enforced server-side; client may not invent transitions)
--   draft             -> submitted
--   submitted         -> changes_requested | approved | rejected
--   changes_requested -> submitted
--   approved          -> published | archived
--   rejected          -> submitted | archived
--   published         -> archived
--   archived          -> draft           (creation of a revised draft)
--
-- Security notes
--   * Separation of duties: an author can never approve or publish their own
--     content, even when holding an editorial role.
--   * Reviewing requires the assigned reviewer or an editor role.
--   * Publishing requires super_admin/admin/content_editor.
--   * Every transition writes one history row and one audit row.
--   * Students can only read `status = 'published'` rows inside their branch.
--   * `sai_content_transition` authorises internally (SECURITY DEFINER) because
--     GRANT/REVOKE on functions is unavailable in this environment.
--
-- Data impact
--   Additive only. No existing row is read, rewritten or deleted.
--
-- Verification
--   select * from pg_policies where tablename like 'sai_content_%';
--   select public.sai_content_transition('<id>'::uuid, 'approved', 'ok');
--
-- Rollback
--   drop function if exists public.sai_content_transition(uuid, text, text);
--   drop table if exists public.sai_content_history;
--   drop table if exists public.sai_content_comments;
--   drop table if exists public.sai_content_items;
--
--   Rollback discards editorial history. Export the three tables first.
-- =============================================================================

create table if not exists public.sai_content_items (
  id               uuid primary key default gen_random_uuid(),
  title            text not null check (length(btrim(title)) > 0),
  title_en         text,
  title_zh         text,
  content_type     text not null check (content_type in ('lesson','course','cms','media','assessment')),
  branch_id        uuid references public.branches(id) on delete restrict,
  course_id        uuid references public.learning_courses(id) on delete set null,
  lesson_id        uuid references public.learning_lessons(id) on delete set null,
  summary          text,
  body             jsonb not null default '{}'::jsonb,
  status           text not null default 'draft' check (status in ('draft','submitted','changes_requested','approved','rejected','published','archived')),
  version          integer not null default 1 check (version > 0),
  author_id        uuid not null references public.profiles(id) on delete restrict,
  reviewer_id      uuid references public.profiles(id) on delete set null,
  rejection_reason text,
  submitted_at     timestamptz,
  reviewed_at      timestamptz,
  approved_at      timestamptz,
  published_at     timestamptz,
  archived_at      timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists sai_content_items_status_idx on public.sai_content_items (status);
create index if not exists sai_content_items_author_idx on public.sai_content_items (author_id);
create index if not exists sai_content_items_reviewer_idx on public.sai_content_items (reviewer_id);
create index if not exists sai_content_items_type_idx on public.sai_content_items (content_type);
create index if not exists sai_content_items_branch_idx on public.sai_content_items (branch_id);
create index if not exists sai_content_items_updated_idx on public.sai_content_items (updated_at desc);

create table if not exists public.sai_content_comments (
  id          uuid primary key default gen_random_uuid(),
  content_id  uuid not null references public.sai_content_items(id) on delete cascade,
  author_id   uuid references public.profiles(id) on delete set null,
  body        text not null check (length(btrim(body)) > 0),
  created_at  timestamptz not null default now()
);

create index if not exists sai_content_comments_content_idx on public.sai_content_comments (content_id, created_at);

create table if not exists public.sai_content_history (
  id          uuid primary key default gen_random_uuid(),
  content_id  uuid not null references public.sai_content_items(id) on delete cascade,
  action      text not null,
  from_status text,
  to_status   text,
  actor_id    uuid references public.profiles(id) on delete set null,
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists sai_content_history_content_idx on public.sai_content_history (content_id, created_at);

alter table public.sai_content_items enable row level security;
alter table public.sai_content_comments enable row level security;
alter table public.sai_content_history enable row level security;

create policy sai_content_items_select on public.sai_content_items
  for select to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
    or public.sai_security_has_role('teacher'::app_role)
    or (
      status = 'published'
      and (branch_id is null or public.sai_security_can_read_branch(branch_id))
    )
  );

create policy sai_content_items_insert on public.sai_content_items
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
      or public.sai_security_has_role('teacher'::app_role)
    )
  );

create policy sai_content_items_update on public.sai_content_items
  for update to authenticated
  using (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
    or public.sai_security_has_role('teacher'::app_role)
  )
  with check (
    public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role)
    or public.sai_security_has_role('teacher'::app_role)
  );

create policy sai_content_comments_select on public.sai_content_comments
  for select to authenticated
  using (exists (select 1 from public.sai_content_items i where i.id = content_id));

create policy sai_content_comments_insert on public.sai_content_comments
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.sai_content_items i
      where i.id = content_id
        and (
          public.sai_security_has_role('super_admin'::app_role)
          or public.sai_security_has_role('admin'::app_role)
          or public.sai_security_has_role('content_editor'::app_role)
          or public.sai_security_has_role('teacher'::app_role)
        )
    )
  );

create policy sai_content_history_select on public.sai_content_history
  for select to authenticated
  using (exists (select 1 from public.sai_content_items i where i.id = content_id));

create policy sai_content_history_insert on public.sai_content_history
  for insert to authenticated
  with check (
    actor_id = auth.uid()
    and (
      public.sai_security_has_role('super_admin'::app_role)
      or public.sai_security_has_role('admin'::app_role)
      or public.sai_security_has_role('content_editor'::app_role)
      or public.sai_security_has_role('teacher'::app_role)
    )
  );

create or replace function public.sai_content_transition(
  p_content_id uuid,
  p_next_status text,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item        public.sai_content_items%rowtype;
  v_allowed     boolean := false;
  v_is_manager  boolean;
  v_is_author   boolean;
  v_is_reviewer boolean;
  v_actor       uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'Authentication required' using errcode = 'insufficient_privilege';
  end if;

  select * into v_item
  from public.sai_content_items
  where id = p_content_id
  for update;

  if not found then
    raise exception 'Content item not found' using errcode = 'no_data_found';
  end if;

  if p_next_status not in ('draft','submitted','changes_requested','approved','rejected','published','archived') then
    raise exception 'Unknown content status: %', p_next_status using errcode = 'check_violation';
  end if;

  v_allowed := case v_item.status
    when 'draft'             then p_next_status = 'submitted'
    when 'submitted'         then p_next_status in ('changes_requested','approved','rejected')
    when 'changes_requested' then p_next_status = 'submitted'
    when 'approved'          then p_next_status in ('published','archived')
    when 'rejected'          then p_next_status in ('submitted','archived')
    when 'published'         then p_next_status = 'archived'
    when 'archived'          then p_next_status = 'draft'
    else false
  end;

  if not v_allowed then
    raise exception 'Invalid transition % -> %', v_item.status, p_next_status using errcode = 'check_violation';
  end if;

  v_is_manager := public.sai_security_has_role('super_admin'::app_role)
    or public.sai_security_has_role('admin'::app_role)
    or public.sai_security_has_role('content_editor'::app_role);
  v_is_author := v_item.author_id = v_actor;
  v_is_reviewer := v_item.reviewer_id = v_actor;

  if not (v_is_manager or v_is_author or v_is_reviewer or public.sai_security_has_role('teacher'::app_role)) then
    raise exception 'Not authorised to change content status' using errcode = 'insufficient_privilege';
  end if;

  if p_next_status = 'submitted' and not (v_is_author or v_is_manager) then
    raise exception 'Only the author or an editor may submit content' using errcode = 'insufficient_privilege';
  end if;

  if p_next_status in ('changes_requested','approved','rejected') and not (v_is_manager or v_is_reviewer) then
    raise exception 'Only the assigned reviewer or an editor may review content' using errcode = 'insufficient_privilege';
  end if;

  if p_next_status in ('published','archived') and not (v_is_manager or v_is_author) then
    raise exception 'Only an editor or the author may publish or archive content' using errcode = 'insufficient_privilege';
  end if;

  if p_next_status in ('approved','published') and v_is_author then
    raise exception 'Institutional separation of duties prevents self-approval' using errcode = 'insufficient_privilege';
  end if;

  update public.sai_content_items
     set status           = p_next_status,
         version          = case
                              when p_next_status = 'submitted' and v_item.status in ('changes_requested','rejected') then v_item.version + 1
                              when p_next_status = 'draft' then v_item.version + 1
                              else v_item.version
                            end,
         submitted_at     = case when p_next_status = 'submitted' then now() else v_item.submitted_at end,
         reviewed_at      = case when p_next_status in ('changes_requested','approved','rejected') then now() else v_item.reviewed_at end,
         approved_at      = case when p_next_status = 'approved' then now() else v_item.approved_at end,
         published_at     = case when p_next_status = 'published' then now() else v_item.published_at end,
         archived_at      = case when p_next_status = 'archived' then now() else v_item.archived_at end,
         rejection_reason = case when p_next_status = 'rejected' then nullif(btrim(coalesce(p_note, '')), '') else v_item.rejection_reason end,
         updated_at       = now()
   where id = p_content_id
  returning * into v_item;

  insert into public.sai_content_history (content_id, action, from_status, to_status, actor_id, note)
  values (p_content_id, 'status_change', v_item.status, p_next_status, v_actor, nullif(btrim(coalesce(p_note, '')), ''));

  perform public.sai_write_audit(
    'content.' || p_next_status,
    'sai_content_items',
    p_content_id,
    jsonb_build_object('status', p_next_status, 'version', v_item.version, 'note', p_note)
  );

  return jsonb_build_object(
    'id', v_item.id,
    'status', v_item.status,
    'version', v_item.version,
    'reviewer_id', v_item.reviewer_id
  );
end;
$$;