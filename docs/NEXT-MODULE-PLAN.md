# Next production modules

## Gate before implementation

The management authorization gate remains open: the isolated PostgreSQL role,
audit-atomicity, and mutation tests have not run, and the live authenticated
management flow has not been verified. Make an isolated Supabase environment
available, run `npm run test:management:db` from `web`, resolve failures, and
verify an authenticated super-admin flow before starting these modules. Review
the current audit design: authenticated clients can submit untrusted audit
entries that imitate trigger metadata.

For each module: inspect the deployed schema and grants first; define data
ownership, branch/session scoping, retention, validation, and role permissions;
prepare a non-destructive migration with RLS and transactional auditing; test
positive and negative role cases in isolation; obtain deployment approval;
then implement the UI using the authenticated client, real data, accessible RTL
states, and non-destructive workflows. Build and run relevant tests after each
dependency. A migration is required before a new database-backed module is
enabled. Record any newly required product decisions before implementing them.

## 1. Admissions

- Define enquiry fields, statuses, branch/session ownership, assignment, and
  conversion to a student record; agree on duplicate detection and retention.
- Migrate enquiry records, constraints, indexes, scoped RLS, and audit triggers.
- Implement scoped list, search, details, create, and status changes. Test allowed
  staff, cross-branch denials, validation, and atomic audit entries.

## 2. Attendance

- Decide attendance statuses, correction rules, date/time zone, and whether
  records follow current student/class assignments or historical enrolments.
- Migrate attendance records with a database-enforced uniqueness rule and
  scoped RLS; preserve historical records and audit corrections.
- Implement assigned-teacher entry, administrative review, and student/verified
  parent read access. Test duplicates, date boundaries, ownership, assignment,
  branch/session isolation, and concurrent submissions.

## 3. Fees and receipts

- Agree on fee schedules, currency, rounding, balances, adjustments, refunds,
  receipt numbering, and financial retention before schema design.
- Migrate immutable or append-only financial transactions and receipts with
  appropriate constraints, scoped RLS, server-controlled operations, and audit
  trails; define reconciliation and correction procedures.
- Implement authorized views and payment/receipt workflows only after financial
  invariants are verified. Test concurrent payments, idempotency, exact decimal
  arithmetic, permissions, and audit/reconciliation.

## 4. Library

- Define catalog items, physical copies, circulation, loan limits, due dates,
  and branch ownership.
- Migrate catalog and circulation records with scoped RLS, inventory integrity,
  historical retention, and audit coverage.
- Implement search, item details, issue and return. Test duplicate issue,
  availability, authorized roles, and branch scope.

## 5. Communications

- Define message types, audience eligibility, delivery channels, consent,
  retention, and how recipients are authorized without exposing other users.
- Migrate scoped messages, recipients and delivery state; enforce RLS and use a
  trusted server-side delivery mechanism with audit and retry handling.
- Implement authorized announcements and recipient inbox states. Test
  audience isolation, duplicate delivery, failures, and role changes.

## 6. Reports

- Agree on each report's definitions, filters, access scope, historical semantics,
  and export/print retention; do not infer missing data as zero.
- Add any required database views/functions through reviewed migrations with
  explicit caller authorization and row-level scope.
- Implement parameterized report views and exports only from approved sources.
  Test totals against fixtures, filtering, cross-branch denials, large datasets,
  and empty/error states.
