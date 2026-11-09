# Version 1087 verification

## Completed automated checks

`node --test tests/review-regressions.cjs`: 26 checks passed. The render test covers 563 permitted account/role/page/tab combinations in a mocked DOM. These are logic/render checks, not 563 browser visits.

Coverage includes nine exact roles, 32 modules, assigned-role restrictions, student/parent/teacher scope, branch/session scope, content review/publication, quiz/review behavior, capacities, library issue eligibility, CSV escaping, CSV parsing and import validation/commit, navigation permissions and inline script syntax.

## Completed browser checks

- All nine role home layouts inspected at phone size and at a 1003px content viewport in the web gallery.
- All 32 main section screens checked for equal body client/scroll width on mobile (377px or 392px, depending on scrollbar presence).
- The accountant layout initially overflowed; a grid sizing fix was applied and checked at 305px content width.
- Guardian linking form checked at 305px and 753px content widths without body overflow.
- Class search filtered to YCT and cleared correctly.
- Guardian selection changed the preview; confirmation produced the expected local success message.
- The sample CSV import preview showed the valid student and successfully committed one record locally.
- Reference shortcuts, role selection and mobile/web gallery modes were exercised. A gallery script syntax error was fixed; inline-script parsing is now part of regression tests.
- Supplied logo loaded visibly in phone and desktop branding.

## Remaining browser verification

Automatic browser approval review hit a usage limit before the final Add Class/assigned-role-switch test batch could run. Public website interactions, the new feedback download and Add Class submission have not received a completed end-to-end browser check in this revision. The website scripts pass syntax checks. Assigned-role logic is covered by automated tests; earlier version browser checks are not counted as new-version verification.

No native Android/iOS build, real backend, authentication, database authorization, payment provider, microphone assessment, QR scanning or production deployment was tested. This package is an interactive design-review prototype, not a production-ready application.
