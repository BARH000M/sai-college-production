-- SAI V2 read-only verification only. Safe for authorized SQL editor. No sensitive rows returned.
SELECT current_database() AS database_name,
  (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') AS public_tables,
  (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity) AS unprotected_public_tables,
  (SELECT count(*) FROM storage.buckets) AS storage_bucket_count;
SELECT c.relname AS table_name,c.relrowsecurity AS rls_enabled,
  has_table_privilege('anon',c.oid,'SELECT') AS anon_can_select,
  has_table_privilege('anon',c.oid,'INSERT') AS anon_can_insert,
  has_table_privilege('authenticated',c.oid,'DELETE') AS signed_in_has_delete_grant
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='public' AND c.relkind='r' AND c.relname LIKE 'sai_%'
ORDER BY c.relname;
SELECT id,public,file_size_limit,allowed_mime_types FROM storage.buckets ORDER BY id;
SELECT p.proname,
  has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prosecdef AND p.proname LIKE 'sai_%' ORDER BY p.proname;
-- This is structural verification, not a simulated authenticated-user denial test.
