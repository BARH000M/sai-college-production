# Shared Supabase integration report
Project `aeryusbrulqdxjdynwfh` verified LIVE. Flutter `backendUrl` references it. Root React `src/portal/lib/supabase.ts` takes `VITE_PUBLIC_SUPABASE_URL` and `VITE_PUBLIC_SUPABASE_ANON_KEY`; website environment values in the remote repo are client-side public config, but deployment configuration must still be checked.

47 public tables, RLS on all, 7 Edge Functions active, one private Storage bucket, 8 new module tables with Realtime, 7 settings rows. Shared data contracts for modules exist in code, but no 9-role end-to-end CRUD tests run. No additional SQL was pushed by this package.

**Risk:** migration history does not correspond to repository numbering. Do not redeploy proposed SQL 029–033 or push all numbered migrations. See reconciliation runbook. Private media signed URLs and child privacy require testing.
