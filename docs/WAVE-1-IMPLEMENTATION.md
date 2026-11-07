# Wave 1 implementation status

## Finance (local preparation; migration 007 not applied)

Migration 007 prepares branch/session fee groups, immutable assignment
snapshots, YER payments and receipts, waivers, voids, refunds, and a separate
finance audit log. Its non-login finance owner is subject to forced RLS, and
browser roles access finance through scoped server functions rather than
direct table privileges. The web module displays database errors if the
migration has not been installed; it does not substitute sample records.

The client retains an unconfirmed payment or refund request and its idempotency key in
the current browser tab's session storage across reloads. Before explicitly
discarding an uncertain request, staff must reconcile its receipt. This does
not coordinate separate tabs or devices. Verify receipt or refund history
before discarding an uncertain request.

The SQL and database behavior suite have not been executed against PostgreSQL.
A dry run only lists migrations; it does not validate SQL execution, RLS,
privileges, financial invariants, concurrency, receipt generation, or audit
atomicity. The behavior test can advance sequences even when rolled back; run
it only in a verified disposable database, never shared staging or production.
Do not deploy 007 until those checks and a security review pass in an isolated
environment. The existing management authorization gate remains
open. The finance page currently requires real branch, session and student
identifiers from administrative records when creating fees.

## Web startup configuration

The web app needs `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in its
Vite environment. Set them in an untracked `web/.env.local` using the
authorized project URL and public client key; never put a service-role key or
database password in browser configuration. Restart Vite after changing
environment files, then reload the page. A missing or invalid configuration
now displays a branded Arabic error instead of a blank screen. The error
boundary does not establish that Supabase is reachable or authentication works.

## Attendance (prepared for staging; migration 006 not applied)

The attendance route uses migration 006's session and record tables and
role-scoped class and roster directories. Super admins, branch-member admins
and assigned branch-member teachers can open, mark, close and cancel sessions;
branch-member receptionists can view and correct existing records only.
Students and verified parents see only their own or linked students' records.
Attendance dates use `Asia/Aden`. A cancelled or closed session is read-only,
and the unique class/date constraint also prevents recreating a cancelled
session for that date. Corrections of existing records remain possible if a
student later changes class; new records require current class membership.
Records are saved individually, not as one bulk transaction.

The linked branch was identified as `sai-college-staging`. Supabase reported
`MIGRATIONS_FAILED` for that branch even though its history lists 001–005.
Migration 006 is unapplied; the new route requires it and will surface database
errors until it exists. Confirm branch health and execute the isolated
authorization suite before any staging or production deployment approval.

## Admissions implementation

`supabase/migrations/004_admissions.sql` creates the enquiry table, restricted
column grants, RLS, a branch-scoped active-staff directory function, validation
and timestamp handling, and transaction-bound audit triggers. Migration 004 has
been applied to the linked project. Its local file was subsequently modified and
does not match the deployed version; do not rerun it against that project.
The session-directory changes are now also in the pending
`005_admissions_session_directory.sql`. Until 005 is deployed, the admissions
session directory used by `/modules/admissions` is unavailable.

Per the approved workflow, all seven valid statuses may transition to one
another; `enrolled`, `rejected`, and `withdrawn` have a server-managed closure
time. A super admin manages all enquiries, branch-member admins and
receptionists manage their branch, and branch-member teachers read only
enquiries assigned to them. Role permissions combine for multi-role users.
Assignment to an active member with a staff role does not itself grant an
accountant, librarian, or content editor access to an enquiry. Names in the
staff directory are exposed only to authorized admissions managers for their
branch (or super admins).

Both branch and session are required. The existing general session-read policy
is unchanged. The admissions session directory returns only active session IDs
and names to super admins and active branch-member admins or receptionists for
the requested branch. The database validates active sessions on creation and
session changes; a previously selected inactive session may remain unchanged.
Teacher-only users do not call the directory. Existing super-admin session
management remains available; the directory does not confer write privileges.
Migration 005 is unapplied; these changes remain unverified against a running
database.

Migration 005 has been parsed and dry-run only. Isolated role, trigger and
audit-atomicity tests must pass before any deployment approval. The existing
audit table also accepts untrusted authenticated inserts that can imitate trigger
metadata, so it is not a tamper-proof ledger.

## Student and class management update

**Post-deployment update:** The linked migration history now lists 003 as applied. Read-only catalog checks confirmed its management policies, deactivation columns, and audit and validation triggers. The descriptions of 003 as unapplied and its class column as missing below are historical. The migration and role behavior still need isolated execution tests before a security sign-off.

The linked migration history now reports 001 and 002 applied. A read-only catalog check found RLS enabled and the 002 policies on the nine foundation tables. The five management tables have no effective `anon` or `authenticated` column-level insert or update privileges. This supersedes the earlier inspection recorded below.

The protected web entry points `/modules/branches`, `/modules/sessions`, `/modules/classes`, and `/modules/students` provide scoped lists, filters, details, and role-aware forms. The application uses the authenticated Supabase client and keeps database errors visible. Classes and students require branch and session filters; the student list also has an explicitly branch-scoped unassigned option. Existing session SELECT privacy can prevent an admin from seeing a session until an accessible class already uses it; a super admin must bootstrap the first class in that case.

`supabase/migrations/003_staff_management_policies.sql` is prepared **locally only**. It adds `is_active` to classes and memberships without removing historical records, adds restricted write grants and policies, checks class/student branch consistency, and adds transaction-bound audit triggers. Branch creation and global session management are super-admin-only. Admins may edit their assigned branches and manage students and classes within those branches; class creation also requires a session already visible to them. To preserve membership privacy, only super admins can manage other users' memberships; admins may deactivate their own membership, but cannot reactivate it after access is removed. Primary IDs, branch/session scope, student account ownership, and teacher assignment are immutable through these browser update grants. No membership-management UI is provided.

Migration 003 is not applied and needs isolated execution and role/JWT security tests before deployment. Until then, management writes are denied, and the class list requires the new column and will report a database error. Client-submitted audit rows permitted by 002 can imitate trigger metadata; the audit table is not a tamper-proof security ledger.

## Earlier inspection (historical)

The following paragraphs and the unblocking plan document the earlier state, before migrations 001 and 002 appeared in the linked migration history.

The Supabase CLI can access `sai-college-production`, and the local workspace is linked to that project. A read-only database query verified that `info@saicollege.com` exists and has the `super_admin` role. This does not verify password sign-in or application access.

The nine existing public tables have RLS enabled remotely, unlike the checked-in `supabase/migrations/001_initial_schema.sql`, but have no RLS policies. `anon` and `authenticated` also have broad table grants, including `TRUNCATE`, which RLS does not govern. The remote `supabase_migrations.schema_migrations` relation does not exist; migration history was therefore not established. Remote public table columns inspected match the nine foundation tables at a structural level, but defaults, constraints, indexes, functions, grants and data were not comprehensively reconciled.

The locally prepared `supabase/migrations/002_security_policies.sql` contains security policies, helper functions, and grants only; it has not been applied. It includes actor-bound client audit inserts, whose contents remain untrusted. No Wave 1 operation tables or mobile screens were added; `mobile` does not contain a Flutter project.

## Earlier web shell implementation

The web app provides `/login`, a protected `/dashboard`, protected `/modules/:moduleId` entry states, a root redirect, and a not-found state. All nine supported roles can enter with an authenticated session and loaded profile. Assigned `super_admin` users see the existing data-backed dashboard; all other roles see a role-aware entry page. Failed lookups, missing profiles, and no supported roles have explicit retry/access states. Client checks control presentation only and do not replace RLS.

The shell uses the approved logo and Cairo assets copied from the prototype, a responsive sidebar, role-filtered mobile navigation, search across allowed modules, and a profile/sign-out menu. Navigation follows the prototype role/module map, combining the permissions of all assigned roles. Its module routes are explicitly labelled unavailable and enforce the role map for direct navigation; the full module functionality is not implemented. The super-admin dashboard has database-backed branch/session selectors. The notification control is disabled because notifications are not implemented. Dashboard queries read branches, academic sessions, active students in the selected branch/session through their class, classes in that scope, and recent audit records. Audit entries are explicitly presented as global because the current table has no branch or session columns.

Attendance, admissions, finance and upcoming timetables are marked unavailable rather than showing sample numbers. The current schema has no class-active flag, so the class count is labelled as all scoped classes. RLS may hide rows without returning an error; empty states say that access policies can be the cause. The user reports that migrations 001 and 002 are applied and security verification has passed; this update did not independently verify the live database or authenticated role/profile/dashboard behavior.

## Safe migration and unblocking plan

1. Establish a verified backup and a representative isolated Supabase/Postgres test environment. Docker was not available during this inspection. Never test destructive SQL against production.
2. Compare remote constraints, defaults, indexes, types, functions, triggers, grants, and applicable data invariants against migration 001. Establish a migration-history baseline reflecting what is actually deployed; do not rerun 001 blindly or mark an unverified schema as applied.
3. Review the prepared non-destructive security migration, which revokes browser privileges including `TRUNCATE`, `REFERENCES`, `TRIGGER`, and `MAINTAIN`, and defines scoped reads and self-profile writes. Validate effective privileges, helper ownership, role and scope behavior, and application access in isolation before production use.
4. Add core operations tables, constraints, indexes, audit triggers, and policies only after confirming actual data and intended authorization semantics. Preserve existing rows and avoid dropping or recreating tables. In particular, reconcile `students.class_id` with the proposed enrolment model before any backfill.
5. Apply the migration first in isolation and run positive and negative tests with real database roles/JWT claims, including denied role writes, audit changes and `TRUNCATE`, and branch/session and ownership cases. Verify super-admin access and regression-test existing accounts. Review rollback/recovery and obtain appropriate production deployment authorization before applying remotely.
6. Only after the security gate passes, implement and validate the web and mobile features against the secured database. Do not start Wave 2 until the requested Wave 1 security and build gates pass.
