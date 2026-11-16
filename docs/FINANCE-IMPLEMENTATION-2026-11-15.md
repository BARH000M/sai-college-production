# Finance implementation — 2026-11-15

Starting branch: `feature/v2-completion`. Verified HEAD:
`1b97f3e9dc8d20c8e56b6743b3e6d7228777f9ab` (different from the supplied `6b8c11c`).

## Delivered

The existing public Finance ledger and scoped RPCs are retained. No database
tables, API endpoints, migrations, dependencies, or role definitions were added.
Both clients remain configured for `aeryusbrulqdxjdynwfh`.

- Existing web and Android fee-group setup and fee assignment remain connected
  to `sai_finance_save_group` and `sai_finance_assign`.
- Web invoice rows now print individual student invoices through the existing
  Arabic letterhead/print layout, including original fee, discount, net fee,
  outstanding balance, due date, status, and invoice reference.
- Android invoice detail reloads the authorized assignment after payment and
  refresh, rather than continuing to use its opening balance. If the invoice
  becomes unavailable, printing and payment entry remain unavailable.
- Android adds reason-confirmed cancellation, balance waiver, and payment void
  through the existing cancel, waive, and void RPCs. Admins may cancel; only
  accountants and super admins receive waiver and payment-void controls.
- Android adds refund history and printable refund vouchers for accountants
  and super admins. Only super admins receive refund-entry controls.
- Refund requests are stored per user before transmission. An uncertain request
  retains its exact payload and idempotency key across retry/restart. Recovery
  works even when opening another invoice. Pending refunds block new payments
  and adjustments; deletion requires explicit confirmation after reviewing history.
- Android adds the existing branch-scoped financial audit history for accountants
  and super admins. Students and verified parents retain read/print access within
  their server-authorized scope. Database authorization remains authoritative.
- Arabic status labels and the existing RTL, SAI styling, and print components
  are retained.
- Web payment entry now waits for invoice/payment loading and blocks new payments
  against unavailable, paid, cancelled, waived, or nonpositive-balance invoices.
  Recovery of a saved idempotent payment remains available once loading succeeds.
- Android balance statements now include invoice reference, admission number,
  and Arabic payment status, including cancelled invoices.

## Files

- `src/portal/pages/Finance.tsx`
- `src/portal/pages/finance/FinanceStatement.tsx`
- `src/portal/lib/finance.ts`
- `web/tests/finance.test.cjs`
- `mobile/lib/data/finance_repository.dart`
- `mobile/lib/ui/finance_detail.dart`
- `mobile/test/finance_detail_test.dart`
- `mobile/lib/ui/live_academic.dart`
- `mobile/test/live_finance_test.dart`
- This report.

The pre-existing `mobile/pubspec.lock` and Android
`GeneratedPluginRegistrant.java` modifications were preserved and are outside
the Finance change set. The web build's generated auto-import file was restored.

## Validation

- Finance web helper and API tests: **12 passed**, zero failed.
  `node --test web/tests/finance.test.cjs web/tests/finance-api.test.cjs`
- Finance Flutter tests: **8 passed**, zero failed.
  `flutter test test/finance_detail_test.dart test/finance_amount_test.dart test/live_finance_test.dart`
  New regressions cover current balances, lost invoice visibility, role controls,
  waiver refresh, and recovery of an uncertain refund from another invoice.
  Additional coverage verifies statement invoice identities/statuses and blocks
  new payments against settled, unavailable, and invalid-balance invoices.
- `npm run type-check`: passed.
- `npm run build`: passed, with a bundle-size advisory.
- ESLint on the two changed web files: passed.
- Flutter analysis on the changed repository, detail screen, and new tests: passed.
- Local PostgreSQL 18 Finance replay: 34 migrations and four SQL suites passed:
  `finance_behavior.sql`, `finance_completion_behavior.sql`,
  `security_invariants.sql`, and `helper_execute_permissions.sql`.
  The harness created and stopped only its own disposable cluster; it did not
  run Attendance behavior validation or change installed PostgreSQL software.
- `git diff --check`: passed.

Earlier new-test runs failed on test harness timers/scrolling/viewport assumptions;
those were corrected. Initial analysis style findings were also corrected.
The formatter initially encountered a sandbox restriction on its telemetry file;
the approved rerun succeeded.

## Limits and commit readiness

Local checks support reviewing and committing the Finance source changes.
No commit, push, deployment, or hosted Supabase change was performed.
Live web/Android reconciliation against authenticated hosted accounts, an Android
APK build/device smoke test, and physical printer verification remain unperformed.
The shared RPC contract, decimal rounding, role scope, and ledger behavior were
verified locally; this does not establish the hosted project's migration state.

On continuation, Git and Attendance validation were not repeated. Flutter checks
used `--no-pub` to avoid changing dependency resolution. The added report test
initially failed to compile because of an extra parenthesis; this was corrected
before the final passing run. Database SQL validation above is the prior verified
local result; this continuation introduces no database changes.
