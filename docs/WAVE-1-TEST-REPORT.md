# Wave 1 test report

## Attendance preparation

- `npm test`: 27 passed, including five attendance unit tests. These use mocks
  and do not establish RLS, privacy, trigger or concurrency behavior.
- `npm run build`: passed; Vite reported existing chunk-size and React Router
  directive warnings.
- Migration SQL and PL/pgSQL parsing passed, with no destructive top-level
  statements. The linked staging dry run listed only 006; it was not applied.
- The rollback-only `supabase/tests/attendance_behavior.sql` contains
  authorization, validation and audit assertions, but has not been run. No
  database behavior or authenticated browser test has passed for 006.
  Staging reports `MIGRATIONS_FAILED`, and migration 006 is not installed.
  Concurrency behavior also needs a separate multi-connection test.

## Admissions preparation

- Migration 005 follow-up: `npm test` passed 22 tests and `npm run build`
  passed with the existing Vite warnings. SQL parsing passed for all five
  migration statements and three PL/pgSQL blocks; no destructive top-level
  statement was found. The linked dry run listed only 005; it was not applied.
  `npm run test:admissions:db` failed before assertions with
  `ECONNREFUSED 127.0.0.1:54322`. Real RLS and trigger behavior remain
  unverified. Local 004 differs from the already deployed 004; the isolated
  test suite requires 001 through 005, with 005 applied.

- `npm test`: exit 0; 22 unit tests passed. Coverage includes navigation,
  permissions, status/payload validation, branch query filters, mocked
  permission failures, directory response/error handling, required branch and
  session, and no-deletion source checks. Mocked errors do not validate RLS.
- `npm run build`: exit 0; 83 modules. Vite reported existing bundle-size and
  React Router directive warnings.
- Historical local migration 004 parsed as 24 SQL statements with five PL/pgSQL blocks; no
  destructive top-level statements. An earlier linked dry run listed 004 only;
  deployment was performed during that check. The user subsequently reported
  that 004 had already been applied.
- `npm run test:admissions:db`: exit 1; the isolated database on port 54322
  refused the connection because the Docker engine was unavailable. No
  database behavior assertions executed. The local-only test script and its
  synthetic fixtures are not yet execution-verified. Its new assertions cover
  directory role and active-membership checks, branch isolation, active
  sessions, unchanged inactive session references, and denied session writes.
- Authenticated UI, RLS, assignment validation, audit triggers, and atomicity
  remain unverified. Run the existing management test and the admissions test
  against an isolated Supabase with migrations 001–005 before deployment.

## Management UI follow-up

The shared browser remained at `/login`; the user indicated sign-in was
unavailable or failed. Authenticated super-admin browsing and live mutation
verification therefore remain unverified. No production records were changed.
The UI now prevents switching detail records or pages during an edit/save and
refuses to submit a student class assignment when its scoped class options are
stale, unavailable, or still loading. These are code-review fixes, not findings
from an authenticated live session. The isolated authorization gate described
below remains open.

- `npm test`: exit 0, 15 tests passed, including the new stale-class-options
  regression; Node reported its experimental type-stripping warning.
- `npm run build`: exit 0, 81 modules; Vite reported the existing chunk-size and
  React Router directive warnings.

## Management behavioral gate — latest run

**Overall: blocked; not a security sign-off.** No production test records or roles were created, and no data was deactivated or removed. The local-only suite at `supabase/tests/wave1_management_behavior.sql` sets up synthetic users and `WAVE1_TEST_` records in one transaction, checks behavior as the `authenticated` database role with each user's claims, deactivates its management fixtures, then rolls back the transaction. It also forces an audit insert failure inside the isolated transaction to check atomicity. The runner at `supabase/tests/run-wave1-local.cjs` invokes only `supabase db query --local`; never run the SQL against the linked project. Setup requires a running isolated local Supabase with migrations 001–003 applied.

| Requested check | Result |
|---|---|
| Super-admin branch create/edit | Unverified: local database connection failed. |
| Super-admin session create/edit | Unverified: local database connection failed. |
| Super-admin class/student create/edit | Unverified: local database connection failed. |
| Admin branch scope | Unverified: local database connection failed. |
| Seven non-management roles denied writes | Unverified at RLS level; client role-control unit test passed. |
| All roles denied self-assignment of super_admin | Unverified behaviorally; remote catalog reports no browser role-assignment insert/update column grants. |
| Deactivation is non-destructive | Unverified against the database; a source-level check found the deactivation payloads. |
| Successful mutations create audit entries atomically | Unverified: local database connection failed. |
| Failed mutations create no audit entries | Unverified: local database connection failed. |
| No delete/truncate UI | Source-level check passed for management page and data module; authenticated browser UI remains unverified. Remote catalog reports no browser DELETE or TRUNCATE privileges on the seven checked tables. |

- `npm run test`: exit 0, 14 unit tests passed; the Node type-stripping API emitted an experimental warning.
- `npm run build`: exit 0, 81 modules; Vite reported existing bundle-size and React Router directive warnings.
- `npm run test:management:db`: exit 1, no behavioral assertions executed; connection to `127.0.0.1:54322` was refused. Docker Desktop CLI was installed, but `docker info` could not connect to its engine; an attempted `docker desktop start` did not become ready within 120 seconds.
- `pglast` parsed eight SQL statements and two PL/pgSQL blocks; syntax parsing is not execution.
- Read-only remote checks confirmed RLS and no browser DELETE/TRUNCATE on the five management tables, `user_roles`, and `audit_logs`; no browser role-assignment insert/update or authenticated audit update; and no authenticated update of the checked IDs, ownership, or class scope fields.
- Browser smoke check: all four signed-out management routes redirected to login. No authenticated browser mutation or responsive-layout flow was tested.
- Next step: start an isolated local Supabase with migrations 001–003, then run `npm run test:management:db` in `web`. The local test harness itself has not yet been executed against PostgreSQL and may need correction before it provides evidence.

## Student and class management checks

- Post-deployment read-only checks: linked history lists 001, 002, and 003; the ten management write policies, two `is_active` columns, five audit triggers, and student/class validation trigger are present. RLS and selected effective browser grants were inspected. No mutation or role-behavior tests were performed; the pre-deployment results below are historical.
- Read-only linked catalog checks confirmed the current 12 policies, RLS on all nine tables, no browser insert/update on the five management tables, no public-schema CREATE for browser roles, and linked history entries for 001 and 002.
- PostgreSQL `pglast` parsed the prepared 003 migration; this is not execution or PL/pgSQL behavioral verification. Docker was unavailable, so isolated migration and RLS/JWT mutation tests were not run.
- `supabase db push --linked --dry-run` listed only 003 and did not apply it.
- The protected routes `/modules/branches`, `/modules/sessions`, `/modules/classes`, and `/modules/students` redirected signed-out browser visits to `/login`. Authenticated forms and mutations have not been tested against Supabase.
- `npm run build` passed with TypeScript and Vite (81 modules); the bundle-size and React Router directive warnings remain.
- `npm run test` passed 13 tests covering role navigation, management controls, immutable edit payloads, validation, active admin memberships, scoped queries, option pagination, unassigned students, and visible query/write failures. The tests use Node's experimental `stripTypeScriptTypes` API.

## Earlier results (historical)

Status: **incomplete; Wave 1 is not implemented**.

## Checks performed

- `npm run build` in `web`: passed (`tsc && vite build`, Vite 8.3.6, 61 modules transformed).
- Local migration inspection: no RLS enablement or policy statements and no Wave 1 operation tables were found in the only checked-in migration.
- Subsequent remote inspection: the CLI can access the named project, the workspace is linked, and the expected account has `super_admin`. All nine public tables have RLS enabled and zero policies. `anon` and `authenticated` hold broad grants, including `TRUNCATE`.
- Remote migration history query failed because `supabase_migrations.schema_migrations` does not exist. This is a migration reconciliation blocker, not evidence that the foundation schema is absent.
- Docker daemon: unavailable, so a local Supabase database could not be started for RLS or migration tests.
- Flutter and Dart commands are installed, but `mobile/pubspec.yaml` does not exist. Flutter package restore, analysis, and tests were not run because no Flutter project exists.
- Security remediation preparation: PostgreSQL `pglast` parsed both migrations, including 47 top-level statements and six SQL function bodies in migration 002. Static checks found 12 policies, nine RLS enables, six fixed-public-search-path helpers and no top-level DELETE, TRUNCATE, or DROP TABLE statements. This is a syntax check, not execution or authorization verification; migration 001 includes foreign-key ON DELETE actions.
- `supabase db lint --local --schema public --fail-on warning`: failed to connect to the local database (`127.0.0.1:54322`); it did not lint the migration.
- `supabase db push --linked --dry-run`: succeeded without applying migrations and lists both `001_initial_schema.sql` and `002_security_policies.sql`. Because the remote history is absent, a real push would incorrectly attempt to replay 001; migration history must be reconciled first.
- Remote catalog inspection found no explicit column ACLs, no memberships for the `anon`/`authenticated` database roles, no PUBLIC table grants, no existing policies, and no conflicting prepared helper names. Actual effective privileges and policy behavior after the migration remain untested.
- Latest read-only remote check: all nine tables still have RLS enabled, zero policies, and `TRUNCATE` for `anon` and `authenticated`; the account retains `super_admin`. `PUBLIC`, `anon`, and `authenticated` lack `CREATE` on schema `public`. These are current production results, not post-migration results.
- After the latest local migration edit, `npm run build` in `web` passed (`tsc && vite build`; 61 modules transformed).
- Web shell: `npm run build` passed with TypeScript and Vite after implementation (75 modules transformed); Vite reported React Router `"use client"` bundling warnings. Browser smoke testing verified that a signed-out visit to `/dashboard` redirects to `/login`, and that the signed-out screen does not overflow at widths 320, 390, 430, 768 and 1280 pixels. Authenticated shell, data queries, sign-out, and responsive dashboard remain unverified against a live authenticated session.
- Role-aware shell: `npm run test` runs four Node tests covering all nine roles, unknown roles, combined permissions, restricted navigation, and exact parity with the prototype role map. Node 24 reports `stripTypeScriptTypes` as experimental; the test runner requires a Node version supporting that API. `npm run build` passes with 78 modules; Vite reports a chunk-size warning and React Router `"use client"` warnings. These tests do not verify RLS or an authenticated browser session.

## Outstanding tests

The requested Wave 1 tests remain outstanding, including authentication/session handling, database ownership and branch/session policy tests, admission creation, duplicate attendance prevention, audit creation, and Flutter analysis/tests. Multi-role navigation is covered by the new unit tests, but server authorization is not. A passing web build does not verify remote authentication or authorization.
