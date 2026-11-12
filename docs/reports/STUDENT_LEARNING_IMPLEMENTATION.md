# Student learning implementation

## Status and scope

Implemented in the existing root React application and `mobile/`, on
`feature/v2-completion`. This is **not a certification of a complete live
student journey**: no authorized student credentials were available for an
end-to-end production test. Existing sign-in, session restoration, role loading,
lesson media, and homework implementations were reused rather than replaced.
No database, project, migration, production data, or deployment was changed.

## Implemented

- The web student dashboard uses the existing learning workspace to show
  accessible courses and links directly to the chosen course. Student queries
  restrict the linked student, class courses, published lessons and homework,
  and that student's progress/submissions. A missing linked student and failed
  or offline requests have explicit states. Server RLS remains authoritative.
- Web lessons are ordered by `position`; their existing content renderer handles
  reading and available media. The course links to its published vocabulary.
  Published vocabulary is limited to accessible courses, and review labels
  explicitly identify self-assessment. Grade averages normalize actual scores
  by each assignment's maximum; missing scores are not displayed as zero.
- Mobile live student course lists are filtered to the linked student's class;
  the dashboard includes those courses. Published lessons are ordered, and
  lesson text/media and course vocabulary use existing live data. The live
  lesson destination no longer opens the bundled demo catalog. Loading, empty,
  retry and connection-error states remain available.
- Both clients no longer offer a button or client write to mark a lesson
  complete. Old `completed` records are explicitly described as unverified;
  they cannot be treated as evidence of achievement. Mobile vocabulary
  classification is labelled self-assessment and writing is not scored.
- The web demonstration listening, speaking, tones, handwriting, reading and
  review routes now show unavailable rather than simulated playback, scores or
  mastery. The operations dashboard is restricted to administrative roles.
  The existing role union and server-side authorization remain in force.

## Existing Supabase data used

The app's approved project is `aeryusbrulqdxjdynwfh`. Client configuration
uses only public application credentials. Learning screens use existing
`students`, `classes`, `branches`, `learning_courses`, `learning_lessons`,
`learning_lesson_progress`, `learning_vocabulary`, `learning_vocab_progress`,
`learning_homework`, and `learning_homework_submissions`. Authentication and
role loading also use Supabase Auth, `profiles`, and `user_roles`. Lesson
attachments use the existing `lesson-media` storage bucket when configured.
These are application contracts, not confirmation of current live policy or
data accessibility.

The previous learning-engine report documented published lessons but no Lesson
101 match or authentic lesson media. Those counts were not reverified during
this implementation and no lesson data was invented.

## Verification

- Rechecked on 2026-11-12 against the current worktree. The reviewed changes
  contain only the implementation, tests, and documentation listed below.
  A targeted private-key, Supabase secret-key, and GitHub-token pattern scan
  found no matches; no dumps, environment files, or generated build output
  are included. This pattern scan is not a comprehensive secret audit.
- `node --test tests\student-learning.test.mjs`: 3 passed. Tests cover
  publication filtering, empty results, role gating, and the absence of the
  removed completion write paths.
- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub`: 21 passed, including student access and read-only
  progress notice tests. Existing preview tests are not live backend tests.
- `git diff --check`: passed; Git reported Windows line-ending conversion
  warnings.
- `npm run type-check`: passed.
- `npm run lint`: passed.
- `npm run build`: passed; Vite warned that a JavaScript chunk exceeds 500 kB.
- Local web browser smoke test: the development server returned HTTP 200, and
  unauthenticated requests to `/portal/modules/courses` and
  `/portal/operations` redirected to sign-in with the original destination.
  The Arabic sign-in screen and college branding rendered. This does not test
  authorization for a signed-in student.
- NOT VERIFIED: authenticated login, session restore, student-only navigation,
  live course/lesson ordering and content, vocabulary, progress, real empty
  and error states, logout, authenticated unauthorized access, live cross-role
  RLS denials, device visual/accessibility checks, or storage media access.
  An existing authorized student account and a way to sign in securely are
  required; no authorized test credentials or authenticated session were
  available in this environment. No test user was created.

## Remaining work and database follow-up

- Completion requires an approved assessment with server-validated answers or
  teacher verification, durable attempts, clear pass criteria, and a
  server-controlled transition to completed. Review existing RLS/write grants
  so clients cannot directly manufacture completion; the repository's historical
  migration permits student-owned progress writes, and the live policy must be
  independently verified. Existing completion rows need provenance/review
  before being called verified achievements. Do not apply migrations without a
  separate approved migration/reconciliation process.
- Real audio, pronunciation assessment, reliable handwriting assessment,
  scheduling, offline content/sync, cross-platform resume and full localization
  remain incomplete. This change does not add a real offline cache. English and
  Chinese localization of these student screens is not complete.
- Assess current live lesson/vocabulary RLS with positive and negative test
  accounts. Client filters are UX and data minimization, not security controls.
  Previous reports note migration-history drift and unverified role tests.
- Some workspace loading still depends on other authorized directories and
  homework tables; permission or network failures are surfaced rather than
  converted to empty successes. Test with actual student and parent accounts.

## Launch and inspect

1. In the repository root, configure `VITE_PUBLIC_SUPABASE_URL` and
   `VITE_PUBLIC_SUPABASE_ANON_KEY` with the approved project URL and public
   key, then run `npm run dev`. Sign in with an existing authorized student
   account, open the dashboard, choose a course, open a published lesson, and
   follow the vocabulary link. Never use a service-role key.
2. In `mobile/`, configure `config/live.json` from
   `config/live.example.json` with `SAI_PREVIEW` set to `"false"` and the
   approved public `SUPABASE_PUBLIC_KEY`. Run
   `flutter run --dart-define-from-file=config/live.json`. Sign in with the
   same existing student and use the dashboard course list. The separate
   preview build is not evidence of live data.
3. If no linked student/class or published content is visible, check authorized
   account linkage and RLS with the responsible administrator. Do not seed
   production or reset the database for testing.

## Exact files changed

- `src/portal/AppRoot.tsx`
- `src/portal/lib/learning.ts`
- `src/portal/lib/studentLearning.ts`
- `src/portal/lib/vocabulary.ts`
- `src/portal/pages/LearnerHome.tsx`
- `src/portal/pages/Learning.tsx`
- `src/portal/pages/ModuleEntry.tsx`
- `src/portal/pages/PortalHome.tsx`
- `src/portal/pages/learning/CoursesView.tsx`
- `src/portal/pages/learning/HomeworkView.tsx`
- `src/portal/pages/learning/ProgressView.tsx`
- `src/portal/pages/vocabulary/Flashcards.tsx`
- `src/portal/pages/vocabulary/VocabularyPage.tsx`
- `mobile/lib/ui/live_courses.dart`
- `mobile/lib/ui/screens.dart`
- `mobile/lib/ui/vocabulary_practice.dart`
- `mobile/test/student_learning_test.dart`
- `mobile/README.md`
- `tests/student-learning.test.mjs`
- `docs/reports/STUDENT_LEARNING_IMPLEMENTATION.md`
