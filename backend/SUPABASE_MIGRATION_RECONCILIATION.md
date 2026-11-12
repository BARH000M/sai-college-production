# Safe migration reconciliation — IMPORTANT

Target production project: `aeryusbrulqdxjdynwfh` only. Never touch deprecated projects.

Observed GitHub repository contains numbered files `001` to `028` with gaps. The remote migration history exposes 001–006, 008–014, and timestamped `20261110172940`, `20261110173339`, `20261110173506`. The live schema includes modules and business tables even though the numbered migration history does not account for all of them.

**DO NOT run** `supabase db push --linked`, `supabase migration repair` or `supabase db reset` automatically. Do not run older proposed SQL 029–033: the ten new tables already exist.

Read-only commands on the developer's Windows PC, after `supabase --help` confirms support:
```powershell
Set-Location 'D:\SAI-College-Production'
supabase --version
supabase migration list --linked
supabase db diff --help
```

1. Save a remote backup using the user's tested pg_dump tooling; verify the backup is readable.
2. Inspect migration history, public schema, public functions, grants and policies in a disposable staging clone.
3. Use `supabase migration new` to generate any NEW migration filename and add reviewed SQL.
4. Reconcile local/remote history in a separate Git branch. Never call migration repair on production without comparing exact remote version numbers and verifying that the corresponding SQL has already taken effect.
5. Run RLS denial and cross-role tests in staging before allowing a production change.

This package performs NO database DDL, no data changes and no migration repair.
