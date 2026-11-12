# Teacher portal implementation

## Scope and status

The existing React and Flutter applications now include teacher workspaces
backed by the configured Supabase project `aeryusbrulqdxjdynwfh`. These
changes are not a certification of a complete live teacher journey: no
authorized teacher account was available for authenticated verification.
The previously outstanding authenticated student login test remains a
**release blocker**. No production data, schema, migrations, or deployment
were changed.

## Implemented

- Web: the teacher dashboard loads assigned classes and active rosters, links
  to assigned courses and homework, shows loaded pending submissions, and
  displays the ten most recent available attendance sessions. It exposes
  loading, empty, retry and error states.
- Web: teacher-only learning queries restrict classes to `teacher_id` and
  constrain students, courses, lessons, homework, progress and submissions to
  those classes. Existing course and homework views provide lesson access and
  the existing grading interface. Past completion records are explicitly
  labelled unverified, not established achievement.
- Web: teacher-only attendance displays sessions and rosters for assigned
  classes. Attendance writes are disabled for teacher-only accounts pending
  verification of live authorization. Existing administrative and
  receptionist capabilities are retained.
- Flutter: the live teacher dashboard and class pages show assigned classes,
  active student rosters, active courses and lesson links, available
  homework/submissions and progress records, and attendance sessions and
  records. Attendance is read-only. Teacher course lists use assigned
  classes. Loading, empty and error states are shown.
- Existing access/role definitions remain in place. Client-side filtering is
  data minimization and navigation, **not an authorization boundary**.

## Existing data and authorization

The portal reads existing `classes`, `students`, `branches`,
`learning_courses`, `learning_lessons`, `learning_lesson_progress`,
`learning_homework`, `learning_homework_submissions`,
`attendance_sessions` and `attendance_records`; existing role/session
mechanisms and attendance directory RPCs are reused. Existing course lesson
views may also read existing learning content and vocabulary.

Repository migration history contains assigned-class read policies, attendance
write policies and homework grading policies. It is not proof of the current
deployed grants or RLS: previous reports identify migration-history drift.
Teacher-only attendance mutation is therefore disabled. The pre-existing web
grading operation is reused but has not been verified against live grants or
negative-role cases. Flutter displays submissions and existing scores but
does not grade. Live RLS validation is required before release.

Assignment is conservatively based on `classes.teacher_id`. A teacher
assigned only via a course may not see that course here. Some learning and
mobile queries are subject to the API row limit and are not fully paginated;
loaded counts are labelled as potentially incomplete and do not establish
totals. The web attendance dashboard deliberately shows at most ten sessions.
Large datasets need complete pagination and batching before counts can be
relied on; no database change is required merely to implement pagination.

## Verification

The focused automated tests cover teacher navigation, class data mapping and
cross-class filtering, empty/error states, and absence of mobile attendance
write controls. They do not prove deployed RLS or actual production data.

- `npm run type-check`, `npm run lint`, and `npm run build`: passed. Vite
  reported a JavaScript chunk over 500 kB.
- `node --test tests\student-learning.test.mjs tests\teacher-portal.test.mjs`:
  five tests passed. The web teacher query test checks source patterns rather
  than exercising a live database.
- `flutter analyze --no-pub`: passed with no issues.
- `flutter test --no-pub`: 25 tests passed. An earlier concurrent test run
  encountered a missing temporary compiler output; a subsequent run passed.
- `git diff --check`: passed, with Windows line-ending conversion warnings.
- A targeted scan of changed files found no private-key, Supabase secret-key
  or GitHub token patterns. This is not a comprehensive secret audit.

Authenticated teacher login/session restore, actual assigned classes, lesson
content, homework grading, attendance records, logout, and negative-role RLS
checks are **NOT VERIFIED**. An existing authorized teacher account and
appropriate separate accounts for negative-role tests are required. No test
accounts or production records were created. Authenticated student login
likewise remains **NOT VERIFIED and a release blocker**; see the student
implementation report.

## Changed files

- `src/portal/lib/home.ts`, `src/portal/lib/learning.ts`,
  `src/portal/lib/attendance.ts`
- `src/portal/pages/home/TeacherHome.tsx`, `src/portal/pages/Learning.tsx`,
  `src/portal/pages/Attendance.tsx`,
  `src/portal/pages/learning/CoursesView.tsx`
- `mobile/lib/ui/screens.dart`, `mobile/lib/ui/live_courses.dart`,
  `mobile/lib/ui/teacher_portal.dart`
- `tests/teacher-portal.test.mjs`, `mobile/test/teacher_portal_test.dart`
- `docs/reports/TEACHER_PORTAL_IMPLEMENTATION.md`

## Remaining work and launch

Obtain authorized teacher and student accounts and verify the full journeys,
cross-class and cross-role denial, live grading and attendance permissions;
reconcile deployed policies through the approved database change process if
necessary. Add a verified server-side learning assessment/completion flow;
do not treat legacy completion records as verified. Finish pagination,
localization, teacher course-only assignments, and mobile grading as supported
by verified server contracts.

For web, configure the approved public `VITE_PUBLIC_SUPABASE_URL` and
`VITE_PUBLIC_SUPABASE_ANON_KEY`, then run `npm run dev` from the repository
root. Sign in with an existing authorized teacher account. For Flutter,
configure `mobile/config/live.json` from its example with live mode and the
approved public key, then run `flutter run --dart-define-from-file=config/live.json`
in `mobile`. Never use a service-role key. Preview data is not evidence of
live operation.
