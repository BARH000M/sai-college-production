# SAI V2 Admissions Validation

## Scope and result

This report covers local migration and application work only. No Production or
Preview database was queried or changed, and no deployment, commit, or push was
performed.

| Area | Result |
| --- | --- |
| Fresh migration replay, 001–031 | PASS |
| Migration 027 security invariant gate | PASS; migration 027 was not changed |
| Public-helper effective EXECUTE checks | PASS in isolated PostgreSQL |
| Admissions and student/verified-parent SQL regressions | PASS |
| Web type-check, lint, production build, admissions tests | PASS |
| Flutter analyze and full test suite | PASS |
| Production admission RPC verification/restoration | BLOCKED |
| Public applicant status/history privacy | BLOCKED pending a safe tracking-token design |

## Implemented

- Migration 029 revokes inherited `PUBLIC`, `anon`, and `authenticated` EXECUTE
  from the internal public helper wrappers while retaining `service_role`.
- Migration 030 restores the intended admissions write-column grants after
  migration 021's table-level grants.
- Migration 031 removes direct authenticated writes to admission status and
  adds branch-authorized status and enrollment RPCs. Enrollment is restricted
  to super-admins and branch admins, locks the enquiry, creates one linked
  student row, and updates the enquiry in the same transaction. A unique
  `students.admission_enquiry_id` index prevents duplicate student records.
- The web and Flutter staff screens use those RPCs. The Flutter flow confirms
  enrollment and does not create an account or parent link.
- The student/parent regression fixture now establishes the super-admin
  context required by the existing student-management trigger.

## Validation evidence

The replay used PostgreSQL 18.7 in a new disposable cluster outside
`D:\pgsql\data`. A minimal Supabase-compatible bootstrap supplied the `auth`,
`storage`, and migration-ledger prerequisites because the Supabase CLI and
Docker were unavailable. This validates PostgreSQL migration execution, not
equivalence with Supabase Preview CI.

The replay passed migrations 001–031, followed by:

- `security_invariants.sql`: zero RLS dependencies on public helpers, zero
  private-to-public helper calls, and all 14 wrappers delegate to `private.*`.
- `helper_execute_permissions.sql`: `anon` and `authenticated` cannot execute
  the wrappers; `service_role` retains execution; no wrapper grants EXECUTE to
  `PUBLIC`.
- `admissions_behavior.sql`: direct status writes are denied, guarded status
  updates work, receptionist enrollment is denied, and admin enrollment is
  idempotent.
- `student_parent_access.sql`: students see only their own record and parents
  see only records with a verified link.

Application checks:

- `npm run type-check` — PASS
- `npm run lint` — PASS
- `npm run build` — PASS (existing large-chunk warning)
- `node --test web/tests/admissions.test.cjs` — 8 passed
- `flutter analyze` — PASS
- `flutter test` — 30 passed

## Blockers and remaining risks

1. The Production definitions of `sai_public_admission_status(text)`,
   `sai_public_admission_history(text)`, and
   `sai_public_admission_submit(text,text,text,text,text)` were not available
   through a read-only database connection. The backup schema is secondary
   evidence only; these functions have not been restored or live-verified.
2. The backup status/history functions use the application reference as a
   lookup key and return applicant data. Do not restore them unchanged: the
   reference may be enumerable and expose personal information. A
   high-entropy tracking token or verified-contact challenge must be selected
   and integrated with the applicant UI first.
3. The existing online form and public status/history page still depend on the
   missing public RPCs; their end-to-end workflow is not complete on a clean
   database.
4. Enrollment creates a student record only. It does not create an Auth
   account or parent/student link. The existing student-management trigger
   permits enrollment only for a super-admin or branch admin; receptionists
   can manage enquiry status but cannot enroll without a separately approved
   role-boundary change.
5. Before deployment, compare the Production/Preview migration ledgers and
   schema with migrations 029–031 and confirm no conflicting function or
   column already exists. This local replay does not establish hosted-project
   compatibility.

No changes were made to Production or Preview. Do not treat this report as
approval to apply migrations.
