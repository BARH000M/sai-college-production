# Phase 1 security and role repair

Date: 2026-11-16. Workspace: `D:\SAI-College-Production-v2-completion`.
Baseline confirmed: `feature/v2-completion`.

## Safety and Preview verification

- Initial uncommitted files: `.mcp.json`, `auto-imports.d.ts`, `mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`, `mobile/pubspec.lock`, and untracked `.codex/`. These were preserved; dependency changes were not reverted.
- Inspected workspace `.mcp.json` and `.codex/config.toml`. Both already configure only `supabase-preview`, scoped to `mgibjusuglafbnlrkbep`, with `read_only=true`. Neither connection was replaced or widened.
- `supabase-preview.get_project_url` returned exactly `https://mgibjusuglafbnlrkbep.supabase.co`. PASS. This verifies the server's project identity, not authenticated application role isolation.
- The tracked `.mcp.json` working copy contains only the Preview HTTP endpoint, no executable server command or inline credentials. A regression test rejects another server, another project, missing read-only mode, or inline headers. The existing uncommitted configuration repair must be included in any later reviewed commit; historical Git blobs are unchanged.
- Added `.codex/config-backups/` to `.gitignore`; `git check-ignore .codex/config-backups/probe.txt` confirmed exclusion. No backup content was read or printed.
- No Production access, database queries, database writes, migrations, deployment, commits, pushes, pulls, resets, cleans, merges, or rebases were performed.

## Files changed

| File | Change |
| --- | --- |
| `.gitignore` | Excludes local Codex configuration backups. |
| `mobile/lib/core/access.dart` | Settings management requires explicit `super_admin`, before the general Admin management shortcut. |
| `mobile/test/access_test.dart` | Nine-role settings checks, all 512 role subsets, preservation of Admin management for other authorized pages. |
| `src/portal/pages/academics/AcademicAffairs.tsx` | Explicit bilingual demonstration notice; removed local approval/notification success state; disabled simulated actions and official printing. |
| `src/portal/pages/academics/Timetable.tsx` | Explicit bilingual sample schedule notice; disabled official printing. |
| `tests/phase1-repair.test.mjs` | Web nine-role privileged destination checks, multi-role restrictions, academic safeguards, Preview configuration and backup exclusion checks. |
| `docs/reports/PHASE_1_SECURITY_AND_ROLE_REPAIR.md` | This report. |

`.mcp.json` and `.codex/config.toml` were already configured correctly and were preserved. Other initial HOME changes remain outside the repair scope. A temporary local transformation script was removed after use.

## Role behavior before and after

| Role | Result |
| --- | --- |
| Super Admin | Settings view/manage retained; sensitive settings still require explicit Super Admin. |
| Admin | Flutter previously reported settings management allowed; now view only for permitted settings. Other authorized management remains unchanged. Web already disables global-setting editing for Admin. |
| Teacher | Settings denied; assigned-class learning and attendance restrictions retained and covered by existing frontend tests. |
| Accountant | Settings denied; existing financial permissions retained; no role-administration escalation. |
| Receptionist | Settings denied; front-office/admissions scope retained; finance management denied without another authorized role. |
| Librarian | Settings denied; library management retained. |
| Student | Settings/staff administration denied; personal learning and financial scope retained. |
| Parent | Settings/staff administration denied; existing verified-child loading retained. |
| Content Editor | Settings/role administration denied; content scope retained. |

All 512 Flutter role combinations now require explicit `super_admin` for settings management, including Admin combined with every ordinary role. Settings visibility requires Admin or Super Admin. Existing multi-role additive module permissions remain intact. Backend authorization remains authoritative.

Web direct module entry checks `canAccessModule` before rendering. Existing tests inspect this guard, while new tests exercise privileged destination decisions for all nine roles and unknown destinations. These are local frontend/source-contract checks, not authenticated browser or server security tests.

## Academic demonstration correction

Targeted inspection covered the two views, existing portal adapters, and matching migration contract names. Existing class/session/student management, assigned-class learning, attendance, and verified-parent contracts serve their own implemented workflows. No matching implemented contract was found for academic-plan approval, exam scheduling approval, academic requests, document notifications, or the fixed weekly/monthly timetable. No contract was invented or repurposed for unrelated operations.

The approved layout, CSS classes, tabs, search, calendar browsing, and fixtures remain. Both screens now prominently state in Arabic and English that all names, records, numbers, and dates are illustrative and do not represent actual students or teachers. Approval and document-notification buttons are disabled and their success handlers/state removed. Official printing is disabled and the official letterhead/archive/signature exports removed from these two views, preventing sample records from becoming apparently official documents. Working academic management elsewhere is unchanged.

## Automated validation

| Command | Result |
| --- | --- |
| `npm run type-check` | PASS, no TypeScript errors. |
| `npm run lint` | PASS, no lint diagnostics. |
| `npm run build` | PASS, 260 modules; non-fatal bundle-size and plugin-timing warnings. |
| `node --experimental-strip-types --test tests/*.test.mjs` | PASS, 23 tests, 0 failures, 0 skipped. |
| `npm --prefix web test` | PASS, 60 tests, 0 failures, 0 skipped. |
| `node --experimental-strip-types --test tests/phase1-repair.test.mjs` | PASS, 4 targeted tests, 0 failures. |
| `flutter analyze` (in `mobile`) | PASS, no issues found (42.6 seconds). |
| `flutter test` (in `mobile`) | PASS, 48 tests, all passed (1 minute 2 seconds), exit code 0. |
| `git diff --check` | PASS; Git emitted line-ending conversion notices only. |

No database replay suites were run because they create/write database state and this phase prohibits database writes and migrations. Tests named `live_*` use local test harnesses; their names do not establish hosted security verification.

## Remaining authenticated testing requirements

Use approved disposable Preview identities for all nine roles and multi-role accounts. Record identity, environment, timestamp, request, expected/actual result, response status, and relevant audit evidence. Required follow-up includes:

- Cross-student and cross-branch reads of records, progress, financial data, and files must be denied.
- Teachers must be denied unrelated class reads/mutations, including attendance, homework, exams, and grades.
- Unverified, revoked, and unrelated parent-child links must be denied; only verified permitted children may be read.
- Accountant financial access must not grant settings, roles, or unrelated student administration. Check scoped invoice/payment reads.
- Admin settings reads must exclude sensitive categories; global settings writes require Super Admin, including multi-role accounts.
- Content Editor must be denied unrelated financial, student, settings, and role operations.
- Exercise direct URLs, refreshed sessions, direct REST/RPC calls, expired sessions, and unknown roles. Frontend route denial does not replace RLS/function authorization.
- Mutation-denial tests require a separately authorized test phase; none were attempted here.

## Failures and limitations

The sandbox shell failed to initialize (`helper_unknown_error: setup refresh had errors`); approved escalated local commands allowed implementation and verification to continue. No hosted application role-isolation claims are made. No authenticated browser exercise or visual screenshot comparison was performed. Academic backend integration remains incomplete and is visibly labeled as such.
