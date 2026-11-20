# Release Commit Sequence — SAI College Portal

Prepared for the GitHub push. The database changes below are **already applied** to the
connected Supabase project; these commits bring the version-controlled files into sync.
Order matters only for readability — every migration is additive and idempotent.

## Prerequisites before the first commit

- `supabase link --project-ref <ref>` (the project ref is already in `web/supabase/.temp/project-ref`).
- Repository secrets for the nightly `pg_dump` worker:
  `SUPABASE_DB_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `BACKUP_ENCRYPTION_KEY`.
- No secrets or `.env` files staged: `.gitignore` already covers them.

## Commit 1 — `chore(db): examinations + results schema`

Files:
- `supabase/deployment/phase4a-examinations/001_examinations.sql`
- `supabase/migrations/20261117202825_production_examinations_results.sql`
- `supabase/tests/examinations_behavior.sql`, `supabase/tests/run_examinations.py`

Verification: `supabase db push --dry-run` reports no pending change.

## Commit 2 — `feat(backup): disaster recovery ledger, edge function and worker`

Files:
- `supabase/migrations/20261120000000_backup_disaster_recovery.sql`
- `supabase/functions/backup-manager/index.ts`
- `src/portal/pages/BackupManager.tsx`
- `src/portal/lib/navigation.ts` (route registration), `src/portal/pages/ModuleEntry.tsx`
- `.github/workflows/db-backup.yml`
- `docs/BACKUP-ARCHITECTURE.md`

Notes: create the private `backups` storage bucket (done) and deploy the function:
`supabase functions deploy backup-manager`.

## Commit 3 — `feat(settings): module on/off toggles`

Files:
- `supabase/migrations/20261120010000_module_toggles.sql`
- `src/portal/lib/moduleToggles.ts`
- `src/portal/pages/settings/ModuleTogglesPanel.tsx`
- `src/portal/AppRoot.tsx`, `src/portal/lib/sidebarSections.ts`

## Commit 4 — `feat(settings): per-role module overrides`

Files:
- `supabase/migrations/20261120020000_module_role_overrides.sql`
- `src/portal/lib/navigation.ts` (`isModuleEnabledFor`, `moduleRoleOverride`)
- `src/portal/lib/moduleToggles.ts`
- `src/portal/pages/settings/ModuleTogglesPanel.tsx`
- `src/portal/pages/ModuleEntry.tsx`, `src/portal/lib/systemInventory.ts`, `src/portal/pages/SystemInventory.tsx`

Behaviour: effective state = global toggle **and** at least one of the user's roles
resolves to enabled. `inherit → on → off → inherit` cycle; the row is deleted on
`inherit`. All writes audited into `audit_logs`.

## Commit 5 — `feat(settings): audit log viewer`

Files: `src/portal/pages/settings/AuditLogPanel.tsx`, `src/portal/pages/SystemSettings.tsx`.

## Commit 6 — `feat(portal): activate catalogue-built modules`

Download Center, Inventory, Transport, Portfolio, Housing, Certificates, Front CMS, Alumni —
tables, RLS and read policies already existed.

## Commit 7 — `ci(security): web + database pipelines`

Files: `.github/workflows/web-ci.yml`, `.github/workflows/database-ci.yml`,
`.github/workflows/mobile-ci.yml`.

## Post-push checks

1. `npm ci && npm run build` — green.
2. `supabase db push --dry-run` — no pending migration.
3. Actions → **Database Backup** → *Run workflow* — ledger row reaches `completed`.
4. Portal → Settings → تفعيل الوحدات: flip one module, confirm the sidebar updates live.
5. Portal → النسخ الاحتياطي: press **نسخ كائنات التخزين الآن**, then confirm the run appears
   as `completed` with a checksum and an `audit_logs` row (`backup.storage.run`).