# Finance completion — 15 November 2026

Branch: `feature/v2-completion`. Work continues the existing ledger and RPCs; no new finance tables, migrations, hosted database changes, deployments, commits, or pushes were made.

## Implemented and retained

- The active web application is the root Vite application (`src/main.tsx` → router → portal). Finance lives in `src/portal/pages/Finance.tsx`. `web/tests` tests the root portal source. The separate `web/src/main.tsx` references missing modules and is not a complete application.
- Existing web fee-group creation/editing, student assignments, fixed discounts, due-date overrides, payments, payment recovery, receipts, voids, waivers, cancellation, refunds, and finance audit viewing remain in place.
- Web now filters invoices by student name/admission number, historical assignment class, branch, payment status, overdue status, and inclusive due-date range. Summaries show invoiced amounts, outstanding balances, and overdue balances using integer cents. Cancelled assignments are excluded from totals. Due today is not overdue.
- Added a branded printable invoice statement with assignment UUID as the existing invoice reference, student, original amount, discount, net fee, due date, current balance, and status. Existing payment receipts remain separately printable. Payment history now includes posting timestamps.
- Flutter now creates/edits fee groups and assigns fees through the existing RPCs. Student options follow branch/session eligibility. Group changes preserve previously assigned invoice amounts.
- Flutter now opens actual transaction history and prints branded payment receipts and student invoices. It records cash, bank-transfer, wallet, and card payments through `sai_finance_pay`, with electronic references required.
- Flutter persists the exact pending payment request before transmission using a user-specific preference key. Retries use the same UUID and amount/method/reference after errors or restart. Another invoice cannot replace an unresolved request. Clearing a request requires the operator to confirm they checked receipts. Failed history/recovery loading blocks payment entry.
- Flutter supports student/admission search, historical class, status/overdue and due-date filters, exact outstanding/overdue totals, and printing the filtered balance report. Empty accounts still allow authorized staff to create groups and assignments.
- Browser startup now rejects other Supabase project URLs, secret keys, service-role JWTs, and anon JWTs for a different project. Flutter already had its approved-project/public-key guard. Authorized project: `aeryusbrulqdxjdynwfh`.

## Permissions and integrity

The implementation retains existing server authorization; frontend visibility does not grant database privileges.

| Role | Finance access |
| --- | --- |
| super_admin | Global finance management, including refunds |
| admin | Active member branches: groups, assignments, payments and assignment cancellation; no waivers, voids or refunds |
| accountant | Active member branches: groups, assignments, payments, waivers, voids and audit; no refund issuance |
| student | Own linked invoices and receipts; no writes |
| parent | Verified linked children's invoices and receipts; no writes |
| teacher, receptionist, librarian, content_editor | No Finance access |

SQL regressions verify branch isolation, verified parent/student links, all nine roles, denied anonymous/client bypass, payment and refund idempotency, duplicate references, overpayment rejection, decimal rounding, finite amounts, unchanged historical assignments, receipt uniqueness, waiver/void/refund balance behavior and audit creation. The ledger and policies were reused unchanged.

The older `finance_behavior.sql` fixtures were updated to use authorized account-linking RPCs and confirmed users. Its obsolete receptionist-payment expectation now asserts denial, then exercises the authorized admin payment path. Financial amount and integrity assertions were retained.

## Validation

- Fresh disposable PostgreSQL 18 cluster: all 34 repository migrations replayed; `finance_behavior.sql`, `finance_completion_behavior.sql`, `security_invariants.sql`, and `helper_execute_permissions.sql` passed. The cluster identity was checked and the server stopped in `finally`; output confirmed `OWN CLUSTER STOPPED`.
- SQL run artifacts: `C:/Users/STR/AppData/Local/Temp/sai-finance-pg18-466629c7-2e5c-4de4-9196-812fee14726d/replay.log`.
- `node --test web/tests/*.test.cjs`: 48 passed, including Finance, Admissions, Attendance, role navigation and startup configuration tests.
- Root `npm run type-check` and `npm run build`: passed. Existing bundle-size warning remains.
- `flutter analyze --no-pub`: no issues.
- Full `flutter test --no-pub`: 36 passed. After adding the filter widget regression, focused Finance tests passed 4/4 (including the decimal rounding test).
- `git diff --check`: passed.

## Limits and remaining gaps

- Hosted migration state and authenticated browser/device behavior were not checked. Local SQL uses the existing Supabase compatibility fixture, not a running Auth/PostgREST stack. No hosted endpoint was queried or modified. Deployment readiness depends on the authorized project already having the repository's existing Finance migrations, especially the scoped-directory/owner-grant migration.
- The separate `web/` build fails on missing `./components/ErrorBoundary` and `./AppRoot`. The active root application builds successfully; no duplicate application was introduced to repair that unused shell.
- Class filters use assignment class UUIDs because the existing Finance directory exposes class IDs, not class names. They deliberately use the historical assignment class rather than the student's current class.
- The new reports cover invoices and balances; they are not a cash-flow or accounting reconciliation report. No tax-specific invoice numbering or separate invoice table was introduced.
- Advanced waivers, voids, cancellations, refunds, and audit viewing remain available through the existing web workflows. Flutter adds core group/assignment/payment/history/printing workflows; it displays voided payment status but does not add those advanced management forms or refund history.
- Pending-payment recovery is device/browser scoped. Operators must review receipts before discarding ambiguous attempts, including when switching clients.

## Changed files

- Web: `src/portal/lib/finance.ts`, `src/portal/lib/financeApi.ts`, `src/portal/lib/supabase.ts`, `src/portal/pages/Finance.tsx`, `src/portal/pages/finance/FinanceStatement.tsx`.
- Flutter: `mobile/lib/data/finance_repository.dart`, `mobile/lib/ui/finance_detail.dart`, `mobile/lib/ui/finance_setup.dart`, Finance portion of `mobile/lib/ui/live_academic.dart`, and the Finance route in `mobile/lib/ui/screens.dart`.
- Tests: `web/tests/finance.test.cjs`, `web/tests/startup.test.cjs`, `mobile/test/finance_amount_test.dart`, `mobile/test/live_finance_test.dart`, `supabase/tests/finance_behavior.sql`, and `supabase/tests/finance-pg18/replay.ps1`.
- Report: this file.

The pre-existing changes to `mobile/pubspec.lock` and `mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` were left untouched and unstaged. No dependency upgrades were performed. Admissions and Attendance logic was preserved.
