# SAI V2 Admissions Completion Validation

## Release summary

This report covers the local Admissions implementation only. Production and
Preview were not changed during this validation. Nothing was deployed, committed, pushed,
or merged. Finance and the later roadmap remain out of scope until Admissions
release blockers are cleared.

| Deliverable | Implementation | Verification / release status |
| --- | --- | --- |
| Secure public admission submission and tracking | LOCAL PASS; NOT RELEASE READY | Isolated SQL tests pass. Client-IP header trust and hosted behavior remain unverified. |
| Approved enquiry-to-student enrollment | LOCAL PASS | Isolated SQL tests cover authorization and idempotent enrollment. |
| Student authentication and verified parent linking | LOCAL PASS | Isolated SQL tests cover confirmed accounts, guarded linking, and parent access. Hosted Auth behavior remains unverified. |
| Web and Flutter implementation | PASS | Web type-check, lint, build and 43 tests passed; Flutter analysis and 31 tests passed. |
| Release readiness | FAIL | Preview compatibility/configuration checks and other blockers below remain outstanding. |

## Security and workflow changes

- Public submission, status, and history use the `admission-tracking` Edge
  Function. Tracking requires both an application reference and a 64-character
  random token. Only its SHA-256 hash is stored in the private schema.
- Public tracking responses contain status and timestamps only; history omits
  applicant and staff identity. Responses are marked `no-store`. The
  forward-only protected-events migration replaces the history RPC's use of
  client-writable general audit rows with a private event store written by a
  restricted trigger. Existing enquiries get a current-status snapshot, not
  unverified old history. Failed event writes abort the original mutation.
- Database RPCs for public tracking are restricted to `service_role`; legacy
  public status/history/submit RPC grants are revoked when those functions
  exist. The Edge Function applies HMAC-scoped rate limits. The closeout removed
  the first-X-Forwarded-For behavior: public requests now fail closed until an
  explicitly configured ingress header is verified by the deployment operator.
  See `supabase/functions/ADMISSIONS_SECURITY.md`; hosted trust is not established
  by local tests.
- Migration 031's idempotent enrollment behavior is preserved. New guarded
  RPCs restrict student account linking, unlinking, and parent-link
  verification to super-admins or branch admins. The receptionist cannot
  bypass those checks. Account invitations do not pre-confirm users or
  automatically attach accounts.
- Existing applicants have no tracking token until authorized staff verify
  identity and issue a new token. Public form input cannot create accounts or
  assign roles.
- Staff history, printed history, CSV rows and the dashboard now identify
  general audit entries as unverified. Status emails no longer show the
  untrusted previous status; the date is labelled as the last enquiry update.

## Validation evidence

Earlier baseline evidence:

- Migrations 001–031 and the prior Admissions SQL/security checks passed in
  the baseline environment.
- All 33 migrations, including both timestamped Admissions migrations, replayed
  successfully on a fresh PostgreSQL 18.7 cluster isolated from existing
  databases. A pre-migration existing-enquiry fixture produced only a labelled
  current-status snapshot, despite a forged audit entry.
- `security_invariants.sql`, `helper_execute_permissions.sql`,
  `admissions_behavior.sql`, `admissions_tracking_behavior.sql`,
  `admission_event_integrity.sql`, and `student_parent_access.sql` passed.
  The integrity test exercised forged audit insertion, trusted transitions,
  token rejection, unauthorized mutation, direct-access denial and atomic
  rollback.
- The replay uses a minimal local emulation of Supabase roles, Auth and Storage,
  not hosted Auth, PostgREST, Storage API or Edge runtime behavior. It does not
  prove compatibility with Preview or hosted migration history.

Application checks from the target worktree:

- Web: 43 tests passed; type-check, lint, and production build passed.
- Flutter: analyze passed; all 31 tests passed.
- Admission tracking: Deno check and a mocked history-response test passed.
- Subsequent focused checks: Deno type-check passed for admission-notify,
  admission-tracking, link-student-account and provision-learning-account.
  Two mocked Deno tests passed, including PII filtering and notification
  previous-status handling. Ten focused Admissions web tests passed; web
  type-check, lint and build passed. No database replay was repeated for these
  application-only changes.
- `git diff --check` passed; only line-ending warnings were reported.

The generated Flutter registrant was reported by Git as modified despite
identical `HEAD`, index, and worktree content hashes; it has no content diff.

## Remaining release blockers

1. The schema backup defines staff history, history export, and notification
   context functions that read client-writable `audit_logs`. UI, print and CSV
   warnings do not secure direct RPC consumers. Verify hosted definitions and
   migrate any consumers requiring verified history to protected events; the
   backup is not proof of current Preview/Production definitions.
2. Before release, verify migration ordering/history, function deployment
   configuration, trusted client-IP header behavior and rate limits, and Auth
   invitation email configuration in Supabase Preview. No Preview behavior has
   been verified.
3. Have authorized staff reissue tracking tokens to existing applicants after
   identity verification.
4. Reconcile recovered Production migrations and the completion chain before
   deploying; the clean local replay omitted the recovered migrations.

## Recovered migration compatibility

The three recovered source files are in the separate original checkout, not
this completion chain:

- `20261110172940_sai_system_settings_shared_20261110.sql` creates settings,
  its audit table, triggers and policies. It depends on `private` role helpers
  supplied locally by migration 020.
- `20261110173339_sai_unified_modules_web_mobile_secure.sql` creates eight
  `sai_*` module tables, triggers and RLS policies. It depends on the private
  helpers, existing branch/student/class/verified-parent data and audit table.
  Web and mobile modules already reference those tables, which the 33-file
  completion replay does not create.
- `20261110173506_sai_unified_module_realtime.sql` requires those eight tables
  and the Supabase-managed `supabase_realtime` publication.

The first two use unconditional CREATE statements: replaying them against
existing objects can fail. The prior 2026-11-13 read-only Production/Preview
report records the three timestamps in Production but not Preview, different
numbered migration ledgers, a missing Production 007 ledger entry, and Preview
missing CMS prerequisites for 014. That evidence is a snapshot, not a current
hosted comparison or proof of matching definitions. Do not copy, push or replay
the recovered migrations blindly; compare current ledgers, object definitions,
dependencies and data first, then plan an environment-specific forward repair.

## Student Management and Attendance: next workflow

Reuse `students`, `classes`, `academic_sessions`, `parent_student_links`,
`attendance_sessions` and `attendance_records`; do not add duplicate models.
The existing management page/forms support student selection and class assignment;
attendance page, roster and personal panels cover substantial parts of marking
and family views. Flutter's live attendance screen currently lists sessions,
not personal attendance records.

1. Validate enrolled-student profile and assignment using `ManagementPage.tsx`,
   `management.ts` and `managementForms.ts`: same branch/session and authorized
   admin only, including unassigned students and clear error states.
2. Verify teacher assignment and marking in `Attendance.tsx`,
   `attendance.ts` and migration 006's existing RLS/RPCs; preserve the
   existing branch-scoped receptionist correction permission.
3. Verify `LearnerHome.tsx`, `FamilyHome.tsx` and `PersonalAttendancePanel.tsx`
   for own student and verified linked children. Extend the existing Flutter
   `live_academic.dart` and data repository for real personal records with
   loading, empty and error states, not demo data.
4. Verify administrator report and print paths in `Reports.tsx`,
   `DashboardReportPrint.tsx`, `StudentProgressReport.tsx` and
   `AttendanceRegisterSheet.tsx`. Keep Arabic RTL, Cairo and the approved red
   theme.
5. Test cross-branch assignments, assigned versus other teachers, student and
   parent isolation, revoked/unverified links, report scope, duplicate marking
   and all nine roles using `attendance_behavior.sql`, `student_parent_access.sql`,
   `attendance.test.cjs` and focused Flutter tests. Add a forward database
   change only if these tests identify a genuine missing invariant.

For this workflow, retain the current role boundaries: super-admin across
branches; admin within authorized branches; assigned teacher for their class;
receptionist branch-scoped read/correction under existing rules; student for
their own record; parent for verified linked children. Accountant, librarian
and content editor receive no additional attendance privileges merely from
those roles. Accounts with multiple roles retain the union of authorized roles.

## Commit review candidates

These are candidates for review, not a deployment authorization. The current
worktree already contained Admissions-related changes before the latest
notification and history-label corrections:

- `supabase/migrations/20261115001316_secure_admission_tracking_and_verified_links.sql`
- `supabase/migrations/20261115014149_protected_admission_status_events.sql`
- `supabase/functions/admission-tracking/index.ts`
- `supabase/functions/admission-tracking/index_test.ts`
- `supabase/functions/admission-notify/index.ts`
- `supabase/functions/admission-notify/index_test.ts`
- `supabase/functions/link-student-account/index.ts`
- `supabase/functions/provision-learning-account/index.ts`
- `supabase/tests/admission_event_integrity.sql`
- `supabase/tests/admissions_tracking_behavior.sql`
- `supabase/tests/student_parent_access.sql`
- `supabase/tests/run-wave1-local.cjs`
- `src/pages/application-status/page.tsx`
- `src/pages/home/components/Admissions.tsx`
- `src/portal/lib/admissionExport.ts`
- `src/portal/lib/admissions.ts`
- `src/portal/lib/learningAccounts.ts`
- `src/portal/lib/managementForms.ts`
- `src/portal/lib/studentAccounts.ts`
- `src/portal/pages/Admissions.tsx`
- `src/portal/pages/Dashboard.tsx`
- `src/portal/pages/ManagementPage.tsx`
- `src/portal/pages/admissions/AdmissionPrintSheet.tsx`
- `src/portal/pages/roles/LearningAccountPanel.tsx`
- `src/portal/pages/students/StudentAccountLink.tsx`
- `src/portal/pages/students/StudentParentLink.tsx`
- `mobile/lib/data/admissions_repository.dart`
- `mobile/lib/ui/live_admissions.dart`
- `mobile/test/live_admissions_test.dart`
- `web/tests/admissions.test.cjs`
- `web/tests/learning-accounts.test.cjs`
- `docs/reports/SAI_V2_Admissions_Validation_2026-11-13.md`
- `docs/reports/SAI_V2_Admission_History_Security_2026-11-14.md`

`auto-imports.d.ts` and the Flutter generated registrant were already reported
modified and should be reviewed separately rather than included automatically.

No Production or Preview changes are authorized by this report. Do not apply
the migration or deploy based solely on these local results.


## Local closeout checks (2026-11-14)

- All seven Edge Function entry points pass `deno check --frozen`.
- Five mocked Edge tests pass with `deno test --frozen --allow-env
  supabase/functions/`: IP trust/no fallback, tracking PII and error-code
  allowlisting, notification status/credential omission, verified student linking
  with caller-scoped RPC credentials, and role-summary authorization/counts.
- The initially reported admission-notify type error was already absent in the
  current working source and that correction was preserved. The broader check
  found two manage-roles SDK generic errors; replacing generic factory
  `ReturnType` with the SDK's `SupabaseClient` type fixes both without disabling
  checking. The SDK version is pinned to the version already used in validation.
- Web tests: 44/44 passed in this closeout. Root TypeScript check passed.
- Flutter's 31 passing tests and SQL's 33 migrations/six suites are prior
  confirmed evidence; neither was rerun in this closeout. No cluster was created.
- The repository-owned `supabase/tests/admissions-pg18/` package passes its
  no-server validation mode (33 migrations, six suites, three fixtures) and
  PowerShell parser checks. A complete execution of the packaged driver has
  intentionally not been repeated. Its default invocation never starts a server.
- Recovered migration differences and next milestone are recorded in
  `SAI_V2_Recovered_Migrations_Review_2026-11-14.md`. No recovered SQL was copied
  into the V2 migration chain or deployed.
- Service credentials are read only on the server. Public tracking fields and
  error codes are allowlisted. Linking never forwards its service-role key as
  the caller RPC credential; malformed requests, IDs and unverified targets are
  rejected. Notifications no longer log email-provider response bodies.

Public admission submission/tracking/token email requires verified ingress and
`ADMISSIONS_TRUSTED_IP_HEADER` configuration before release. Local tests establish
the parser and no-fallback behavior, not the managed gateway's trust guarantee.
All earlier hosted-release blockers remain until separately verified. No hosted
queries or deployment occurred in this closeout. Admissions changes are prepared
for a local commit; unrelated generated/backup/lockfile edits are preserved
outside the staged change set. No commit, push or merge was performed.
