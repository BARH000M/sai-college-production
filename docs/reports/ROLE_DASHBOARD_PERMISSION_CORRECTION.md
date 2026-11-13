# Role dashboard and permission correction

## Status

**Implementation stages 1–3 are implemented locally; production deployment and
authenticated backend verification remain pending.** No Supabase schema,
policy, migration, or production data was changed.

## Changes made

The web navigation and direct module-route role map now:

- Denies Teacher access to general admissions and the unrestricted student
  directory. Teacher class and student workflows remain in the assigned-class
  Teacher Portal.
- Denies Student and Parent access to the administrative student and class
  directories.
- Denies Student and Parent access to the generic attendance register. That
  screen loads class sessions and class attendance history; it is not a
  verified personal-attendance view.
- Removes Receptionist access to finance, including payment posting. Front
  office admissions remain available.
- Preserves additive access for legitimate multi-role accounts.

Flutter applies equivalent restrictions to its generic class and attendance
screens. Teachers retain the assigned-class entry point. The web Student and
verified-Parent dashboards now show only personal/verified-child attendance;
Flutter still has no corresponding personal attendance panel. Hiding the
unscoped register remains safer than exposing class-wide records.

These are client-side navigation and route guards. They do **not** prove or
replace Supabase RLS, RPC, or Edge Function authorization.

## Dashboard and module implementation

- The Super Administrator dashboard requests aggregate counts through the
  `manage-roles` Edge Function. It verifies the caller's session and
  `super_admin` role before running the summary action; the response contains
  counts only, not account PII. Auth accounts are paged through Auth Admin,
  while database metrics use exact counts. Failed counts produce an error
  state rather than a zero-valued dashboard.
- The dashboard covers accounts, roles, students, teachers, classes, branches,
  academic sessions, courses, lessons, active students assigned to classes,
  lesson progress, homework submissions, new admissions, content references,
  and notifications for the signed-in Super Administrator. Positive
  operational counts link to the corresponding existing module.
- A recorded `content_path` is counted only as a media reference; the Edge
  summary does not verify that an object exists in Storage. Assessment counts
  are homework submission activity only. There is no verified exam-attempt
  contract in the current repository.
- Student and verified-parent dashboards now show the most recent personal
  attendance records. Student identity is resolved by the authenticated
  `user_id`; parent records are derived from links with non-null `verified_at`.
  The attendance query filters by that student ID, then fetches only the
  referenced sessions. Existing RLS remains authoritative. The generic,
  class-wide attendance register remains hidden from Student and Parent roles.
- The Student dashboard includes real class courses, lessons, published
  homework, graded submissions, recent progress activity, and a resume link
  for a recorded in-progress lesson. Legacy completion states are still
  described as unverified, not mastery. No exam scores, achievements, or
  certificates are fabricated.
- Teacher dashboard code and approved Teacher screens were not changed during
  these stages. Six incomplete skill pages (listening, speaking, tones,
  handwriting, reading, and spaced review) are no longer presented as working
  modules; they are marked pending with their backend/content limitations.
- A Super Administrator-only system catalog lists all enabled routes and
  pending modules without linking pending items to placeholder pages. It
  summarizes all 32 reference categories and the 147 expected submenu entries.
  The checked-in report contains the category names and counts, but not the
  original submenu labels; the catalog therefore marks its mapping as
  category-level and does not claim a line-by-line audit of the 147 entries.

## Before/after permission corrections

| Role | Before | After |
|---|---|---|
| Super Admin | Existing broad module access | Dashboard summary and system catalog added; detailed submenu-label and governance audit remain pending |
| Admin | Existing institutional navigation | Unchanged; privileged permission-definition enforcement remains unverified |
| Teacher | Could open general admissions, student directory, and web class directory | Those generic routes are denied; assigned-class teaching and attendance entry points remain |
| Accountant | Finance access | Unchanged |
| Receptionist | Admissions, student directory, and finance/payment posting | Admissions and front-office access retained; finance and payment posting denied |
| Librarian | Library-scoped navigation | Unchanged |
| Student | Could open student/class directories and the generic attendance register | Those unscoped routes are denied; learning routes remain |
| Parent | Could open student/class directories and the generic attendance register | Those unscoped routes are denied; web personal attendance uses verified guardian links |
| Content Editor | Content-focused navigation | Unchanged |

Multi-role accounts continue to receive the union of their assigned role
navigation. The role selector in Flutter preview is demonstration-only and is
not an authorization mechanism.

## Role menu inventory

The web menu is generated from `navigation.ts` and filtered by role and module
availability. The corrections above change the affected roles' visible links
and their direct module-route authorization. A full before/after route,
backend-operation, data-scope, and read/write inventory for all nine roles has
not yet been completed.

The original role-reference menu counts remain reference figures only:
Super Admin 142, Admin 141, Accountant 14, Teacher 33, Receptionist 9,
Librarian 3, Student 11, Parent 8; Content Editor was not specified. They are
not implemented or verified menu totals.

## Required 32-category inventory

All reference categories and expected entry counts are recorded here for
tracking. The checked-in source specifies 147 submenu entries in total but
does not contain their individual labels. The Super Administrator catalog
links available modules at category level and marks categories partial; it
does not infer or fabricate submenu names. Individual routes, backend
operations, scopes, CRUD capabilities, and statuses remain to be mapped when
the original submenu list is available.

| # | Category | Reference entries | Current inventory assessment |
|---:|---|---:|---|
| 1 | Front Office | 7 | Not individually audited |
| 2 | Student Information | 15 | Not individually audited |
| 3 | Fees Collection | 9 | Not individually audited |
| 4 | Income | 2 | Not individually audited |
| 5 | Expenses | 2 | Not individually audited |
| 6 | Attendance | 3 | Not individually audited |
| 7 | Examinations | 4 | Not individually audited |
| 8 | CBSE Examinations | 10 | Not individually audited |
| 9 | CBSE Exam | 8 | Not individually audited |
| 10 | Academics | 6 | Not individually audited |
| 11 | Homework | 1 | Not individually audited |
| 12 | Download Center | 2 | Not individually audited |
| 13 | Library | 3 | Not individually audited |
| 14 | Transport | 3 | Not individually audited |
| 15 | Hostel | 1 | Not individually audited |
| 16 | Inventory | 2 | Not individually audited |
| 17 | Human Resources | 5 | Not individually audited |
| 18 | Communicate | 3 | Not individually audited |
| 19 | Online Courses | 5 | Not individually audited |
| 20 | Live Classes | 2 | Not individually audited |
| 21 | Behaviour Records | 2 | Not individually audited |
| 22 | Certificates and Cards | 3 | Not individually audited |
| 23 | Front CMS | 1 | Not individually audited |
| 24 | Alumni | 2 | Not individually audited |
| 25 | Continuity Center | 1 | Not individually audited |
| 26 | Calendar | 1 | Not individually audited |
| 27 | Reports | 6 | Not individually audited |
| 28 | Internal Messaging | 1 | Not individually audited |
| 29 | Student Personal Services | 2 | Not individually audited |
| 30 | Parent Personal Services | 3 | Not individually audited |
| 31 | Backup and Restore | 1 | Not individually audited |
| 32 | System Settings | 31 | Not individually audited |
| **Total** | **32 categories** | **147** | **Entry-level mapping pending** |

The separate earlier role reference of 142 Super Admin menu entries is
preserved; it is not forced to equal the 147-entry functional inventory.

## Existing implementation reused

- Web role definitions, available-module filtering, sidebars, mobile tabs, and
  direct module routing in `src/portal/lib/navigation.ts` and
  `src/portal/lib/sidebarSections.ts`.
- Existing Teacher Portal and assigned-class workflows.
- Existing finance permissions and payment workflow; the Receptionist
  capability was removed from the client permission helper as well as the
  navigation.
- Flutter's shared `Access` policy and Teacher Portal routing.

## Backend dependencies and limitations

- Client-side role checks are UX controls only. RLS and privileged operations
  must enforce each role and row scope independently.
- The personal-attendance UI relies on the existing migration 006 RLS policy
  for student-own and verified-parent access. No authenticated role accounts
  were available to perform live positive/negative policy tests.
- Parent finance and homework visibility continue to rely on their existing
  RLS policies; this change adds no broader access.
- The new Edge Function summary action must be deployed before the new
  Super Administrator dashboard can load in production. Hostinger VPS and
  Supabase are identified as targets, but the approved deployment mechanism
  and server deployment configuration are not confirmed. Deno and Supabase
  CLIs are not installed here.
- The PR's Supabase Preview check currently fails while applying a CMS policy:
  `relation "public.cms_programs" does not exist`. No database or migration
  changes were made to bypass this preview failure.
- Storage object existence, exam-attempt statistics, achievements, and
  certificate issuance/verification are not supported by a verified backend
  contract in this repository.
- The original 147 submenu labels are not present in the checked-in report or
  source inventory, preventing a truthful per-entry audit.

## Remaining work

- Provide the original submenu labels to complete the 147-entry audit and map
  each item to its authorized route, data scope, CRUD support, and status.
- Deploy the `manage-roles` Edge Function and web application using the
  approved production target, then validate the dashboard with an authorized
  Super Administrator account.
- Obtain authorized Student and Parent test accounts for live RLS checks of
  personal attendance and verified-child scoping.
- Verify actual Storage object availability if the product needs a
  ready/missing media status rather than the current path-reference counts.
- Implement assessment attempts, achievements, and certificates only after
  their backend contracts are approved.

## Changed files

- `src/portal/lib/navigation.ts`
- `src/portal/lib/attendance.ts`
- `src/portal/lib/roles.ts`
- `src/portal/lib/sidebarSections.ts`
- `src/portal/lib/systemInventory.ts`
- `src/portal/lib/finance.ts`
- `src/portal/pages/LearnerHome.tsx`
- `src/portal/pages/PortalHome.tsx`
- `src/portal/pages/SystemInventory.tsx`
- `src/portal/pages/home/FamilyHome.tsx`
- `src/portal/pages/home/PersonalAttendancePanel.tsx`
- `src/portal/pages/home/StaffHome.tsx`
- `src/portal/pages/home/SuperAdminOverview.tsx`
- `src/portal/pages/learning/CoursesView.tsx`
- `src/portal/pages/ModuleEntry.tsx`
- `supabase/functions/manage-roles/index.ts`
- `mobile/lib/core/access.dart`
- `tests/role-navigation.test.mjs`
- `tests/system-inventory.test.mjs`
- `mobile/test/access_test.dart`
- `docs/reports/ROLE_DASHBOARD_PERMISSION_CORRECTION.md`

## Verification

- `node --test tests/role-navigation.test.mjs tests/student-learning.test.mjs tests/teacher-portal.test.mjs tests/system-inventory.test.mjs` — passed, 14 tests, including the 32-category/147-count invariant and scoped attendance-query checks.
- From `web\`, `npm test` — passed, 39 compatibility and unit tests after aligning legacy role expectations with the access corrections.
- `npm run type-check` — passed.
- `npm run lint` — passed.
- `npm run build` — passed. Vite reported the existing large JavaScript chunk warning (about 1.29 MB minified).
- From `mobile\`, `flutter analyze --no-pub` — passed with no issues.
- From `mobile\`, `flutter test --no-pub` — passed, 26 tests.
- `git diff --check` — passed; Git emitted expected Windows line-ending conversion warnings for edited files.
- Authenticated UI and backend role-boundary tests — not run; authorized test accounts were unavailable. Edge Function type-check was unavailable because Deno is not installed.
