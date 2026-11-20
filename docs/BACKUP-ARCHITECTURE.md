# Backup & Disaster Recovery Architecture

Hybrid, production-grade backup. No simulated backups, no frontend-only SQL exports,
no service-role credentials in the browser or mobile apps.

## Layers

1. **Supabase managed backups + PITR** — configured in the Supabase Dashboard
   (Database → Backups). Turn on Point-in-Time Recovery on a plan that supports it.
   This is the fastest path to a recent restore point; it is a project setting, not app code.

2. **Independent PostgreSQL dumps (pg_dump)** — performed by a secure server-side
   worker that CANNOT live inside the Vite SPA or Deno Edge Functions (neither has the
   `pg_dump` binary). Delivered as `.github/workflows/db-backup.yml`:
   - runs on a GitHub-hosted runner (native tools, no Docker),
   - daily schedule + manual `workflow_dispatch`,
   - `pg_dump --format=plain | gzip | openssl aes-256-cbc`,
   - uploads the encrypted artifact to the restricted private `backups` bucket,
   - records `provider=github-actions`, `size_bytes`, `checksum`, `location`, `status`
     into `public.sai_backup_runs` using the service role.

3. **Storage object backup** — performed for real by the `backup-manager` Edge Function
   (`action: run-storage`). It walks every bucket (except `backups`), copies each object
   into `backups/<timestamp>/<bucket>/<path>`, computes a SHA-256 manifest checksum, and
   updates the run row. Requires the private `backups` bucket (auto-created if missing).

4. **Coordinator / dashboard** — `backup-manager` Edge Function + the
   **النسخ الاحتياطي والاستعادة** page (Super Admin only):
   - list history, status, size, checksum, retention, failures,
   - request a DB backup (records a `requested` row for the worker),
   - run a storage backup now,
   - signed short-lived download URLs (120s),
   - request a restore (records an authorized request only — never executes).

5. **Audit + restore safety** — every backup/restore action writes to `public.audit_logs`.
   Restoration requires human review and an isolated-environment verification first.
   No destructive production restoration is ever automated.

## Security invariants
- Edge Function uses TWO clients: anon client only for `auth.getUser()`, service-role
  client only for privileged DB/Storage work.
- `sai_backup_runs` RLS: super_admin SELECT only; INSERT/UPDATE/DELETE only via service role.
- `backups` bucket is private; downloads go through short-lived signed URLs.
- Service-role / DB passwords never reach clients.

## One-time setup (operator)
1. Supabase Dashboard → Storage → create private bucket `backups` (or let the function auto-create).
2. Supabase Dashboard → Database → Backups → enable PITR if the plan supports it.
3. GitHub repo → Settings → Secrets: `SUPABASE_DB_URL`, `SUPABASE_URL`,
   `SUPABASE_SERVICE_ROLE_KEY`, `BACKUP_ENCRYPTION_KEY` (and optional `BACKUP_RETENTION_CLASS`).
4. Run the workflow once via `workflow_dispatch` to confirm, then it runs daily.

## Restore runbook
1. Super Admin files a restore request from the dashboard (audited).
2. Operator restores the chosen encrypted dump into an isolated database first.
3. Verify integrity, then perform the approved production restore during a maintenance window.