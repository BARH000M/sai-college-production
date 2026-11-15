# Admission history security correction

Security fix implemented in source and validated in isolated PostgreSQL 18.7.
Not deployed or verified in Supabase Preview.

The forward migration `20261115014149_protected_admission_status_events.sql`
creates an RLS-protected private event store. Only the non-login, insert-only
trigger writer receives write access. An AFTER ROW trigger records actual
admission inserts and changed statuses; failures abort the admission mutation.
Existing applicants receive a labelled current-state snapshot, never an audit
backfill. Token-validated public history reads this store exclusively.

The original secure-tracking migration is unchanged. Read-only migration-ledger
checks found neither secure tracking nor the correction in the five accessible
projects: reprjetryjveowspusxd, aeryusbrulqdxjdynwfh, foxnogisnpmtzsrlhyfq,
tcpzuzjprzooicjcirmu and vtnkdxxwfihlzrfetbog. This does not establish the state
of inaccessible databases or manually executed SQL without ledger entries.

## Validation from this run

- Web tests: PASS, 43/43 (`npm test` in `web`).
- Web type-check: PASS (`npm run type-check` at repository root).
- Flutter tests: PASS, 31/31 (`flutter test` in `mobile`).
- Flutter analysis: PASS, no issues (`flutter analyze` in `mobile`).
- Whitespace validation: PASS (`git diff --check`).
- Database security regression tests: PASS in the isolated local emulation.
- Migration replay: PASS for all 33 migrations in a new isolated PostgreSQL
  18.7 cluster, including an existing-enquiry snapshot fixture with a forged
  audit record.

PostgreSQL 17 is installed at `C:\Program Files\PostgreSQL\17\bin` and the
`postgresql-x64-17` service is running. A read-only, noninteractive connection
to `127.0.0.1:5432`, database `postgres`, user `postgres`, failed with
`fe_sendauth: no password supplied`. No PG credential environment variables or
default `%APPDATA%\postgresql\pgpass.conf` were available. No existing cluster
was changed. No Docker was used.

The successful replay used a separate task-owned cluster and minimal Supabase
role, Auth and Storage emulation. It does not validate hosted Supabase APIs,
real Auth behavior, or Preview configuration. The cluster was stopped afterward.

`supabase/tests/admission_event_integrity.sql` includes behavioral assertions for
forged insert/status-change audit entries claiming trigger provenance, genuine
events, invalid and cross-applicant tokens, unauthorized status changes,
anon/authenticated/service-role event-store access denial, trigger execution
privileges, no-op updates, and atomic rollback on event-write failure.
The existing admissions runner already includes this regression alongside
admissions, tracking and student/parent SQL coverage. These assertions are
passed locally; frontend passes alone do not establish database security.

All initial uncommitted work was preserved. No commit, push, merge, deployment,
hosted database writes, or changes to enrollment or parent-access functions.
