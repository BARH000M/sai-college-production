-- 014_public_read_and_status_permissions.sql
--
-- Repairs two permission gaps verified against the live main project
-- (aeryusbrulqdxjdynwfh). Both were confirmed by calling the public REST API with
-- only the anon key, exactly like an unauthenticated website visitor:
--
--   1. GET /rest/v1/cms_programs  -> 401 {"code":"42501","message":"permission denied for function sai_security_has_role"}
--      GET /rest/v1/cms_news      -> 401 (same)
--      Cause: the SELECT policies referenced private.sai_security_has_role(), which the
--      anonymous role is not allowed to execute, so the policy itself failed.
--   2. POST /rest/v1/rpc/sai_public_admission_status -> 401 permission denied for function
--      Cause: anon had no EXECUTE grant on the public application-status functions.
--
-- Nothing here widens what an anonymous visitor can see: published rows only.
-- On a clean migration replay, the CMS schema and private helpers are installed
-- by migration 020. Defer only this CMS block when those prerequisites are absent.

begin;

-- ---------------------------------------------------------------------------
-- 1. CMS read policies: give the anonymous visitor a helper-free path, and keep
--    the staff helper path for scheduled (unpublished) content.
-- ---------------------------------------------------------------------------

do $cms$
declare
  v_programs boolean := to_regclass('public.cms_programs') is not null;
  v_news boolean := to_regclass('public.cms_news') is not null;
  v_site_content boolean := to_regclass('public.cms_site_content') is not null;
  v_role_helper boolean :=
    to_regprocedure('private.sai_security_has_role(public.app_role)') is not null;
begin
  if not v_programs and not v_news and not v_site_content then
    raise notice 'CMS policies deferred until migration 020 creates the CMS schema';
  elsif v_programs and v_news and v_site_content and v_role_helper then
    -- Preserve the existing write predicates; only prevent their evaluation
    -- for anon. The content schema must be present before these statements run.
    execute 'alter policy cms_programs_write on public.cms_programs to authenticated';
    execute 'alter policy cms_news_write on public.cms_news to authenticated';
    execute 'alter policy cms_site_content_write on public.cms_site_content to authenticated';

    execute 'drop policy if exists cms_programs_public_read on public.cms_programs';
    execute $policy$
      create policy cms_programs_public_read on public.cms_programs
        for select to public
        using (is_published)
    $policy$;

    execute 'drop policy if exists cms_programs_staff_read on public.cms_programs';
    execute $policy$
      create policy cms_programs_staff_read on public.cms_programs
        for select to authenticated
        using (
          private.sai_security_has_role('super_admin'::public.app_role)
          or private.sai_security_has_role('admin'::public.app_role)
          or private.sai_security_has_role('content_editor'::public.app_role)
        )
    $policy$;

    execute 'drop policy if exists cms_news_public_read on public.cms_news';
    execute $policy$
      create policy cms_news_public_read on public.cms_news
        for select to public
        using (is_published)
    $policy$;

    execute 'drop policy if exists cms_news_staff_read on public.cms_news';
    execute $policy$
      create policy cms_news_staff_read on public.cms_news
        for select to authenticated
        using (
          private.sai_security_has_role('super_admin'::public.app_role)
          or private.sai_security_has_role('admin'::public.app_role)
          or private.sai_security_has_role('content_editor'::public.app_role)
        )
    $policy$;
  elsif v_programs and v_news and v_site_content and not v_role_helper then
    raise notice 'CMS policies deferred until migration 020 creates the private helpers';
  else
    raise exception 'Partial CMS schema detected; refusing to apply CMS policies';
  end if;
end
$cms$;

-- ---------------------------------------------------------------------------
-- 2. Public application-status page.
--    sai_public_admission_submit is already executable by anon; the two read
--    functions used by the status page were missed.
-- ---------------------------------------------------------------------------

grant execute on function public.sai_public_admission_status(text) to anon, authenticated;
grant execute on function public.sai_public_admission_history(text) to anon, authenticated;
grant execute on function public.sai_public_admission_submit(text, text, text, text, text) to authenticated;

commit;

-- Verification (run after the script, should return HTTP 200 and a JSON array):
--   curl "https://aeryusbrulqdxjdynwfh.supabase.co/rest/v1/cms_programs?select=id&limit=2" \
--     -H "apikey: <anon key>"
--   curl -X POST "https://aeryusbrulqdxjdynwfh.supabase.co/rest/v1/rpc/sai_public_admission_status" \
--     -H "apikey: <anon key>" -H "Content-Type: application/json" \
--     -d '{"p_reference":"none"}'