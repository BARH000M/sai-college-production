# Inspection and repair report

## Browser preview — repaired and regression checked

1. Mobile “all menus” button had no handler; it now opens the menu.
2. Feature cards looked up icons using their description instead of the icon key.
3. Navigation shortcuts could bypass the selected role's menu. A shared allow-list guard now rejects them. This is a preview usability control, not server authorization.
4. Global search matched an inaccessible module before checking role access; it now searches only permitted pages and rejects empty searches.
5. October incorrectly showed 28 days with no weekday alignment. The calendar now derives month length and first weekday, including leap years.
6. Calendar month arrows had no handlers. They now navigate months and show an explicit absence of demo records for other months.
7. Calendar summaries did not match supplied sample records; counts now derive from the actual month dataset.
8. CSV exports contained only page metadata. Table exports now contain the visible filtered records with proper quoting and spreadsheet-formula escaping.
9. CSV object URLs were revoked immediately; revocation now occurs after download initiation.
10. Homework data contained an extra cell, misaligning the table with its headers.
11. Status styling assumed the final data cell was always a status. It now checks the column title.
12. Filters had irrelevant fixed statuses and substring matching (e.g. “published” matching “unpublished”). Options now derive from data and match exact statuses.
13. Empty table searches had no message; they now show a clear empty state.
14. Table footers claimed eight times more records than actually existed; counts now reflect the loaded sample rows.
15. Learner roles displayed generic add actions and unrelated finance notifications. Primary actions and notifications now reflect the selected role.
16. Modal focus returns to the trigger, Tab is contained in the dialog, and Escape resets notification state.
17. Logging out now clears child selection, temporary preferences, calendar position and notification state.
18. “Compact view” now changes spacing rather than only displaying a toast.
19. The institution selector previously claimed data had changed while only showing a toast. It is now explicitly fixed to the demo institution.
20. Generic forms no longer claim that actual records were saved.

## React / Windows application — compiled and type checked

- Corrected college website links pointing to the unrelated YSMS host.
- Replaced Unix-only npm start syntax with a portable Node launcher.
- Corrected production deep-link file resolution after bundling.
- Updated the package lock to use the public registry; dependency installation succeeds.
- Replaced the English placeholder login with an Arabic page and a clear absent-configuration state, avoiding invalid URL crashes.
- Added admission input length checks and a programs-load failure/retry state.
- Added server validation that an admission's program exists; no migration needed.
- Admission references now use random 20-hex-character values and fit the existing 24-character column including SAI-.
- Expired/revoked documents no longer use the green valid-document appearance.
- Bundled Cairo fonts locally; refreshed colors, layout, cards, forms and mobile navigation.

## Flutter source — changes prepared, native checks unavailable

- Unified SAI visual theme, login identity, app bar, cards, form fields and bottom navigation.
- Preserved server-provided tenant colors and existing authentication/role/API contracts.
- Added a busy guard to prevent repeated keyboard submissions during login.
- Kept email/password direction LTR in the Arabic interface and added autofill hints.
- Replaced rigid dashboard card sizing with a width/text-scale-aware layout.
- Made dashboard refresh scrollable even on short lists and prevented older overlapping requests from replacing newer metric responses.
- Added a visible sign-out failure message rather than an uncaught asynchronous error.
- Updated display names while preserving package/bundle identifiers.
- Updated the existing theme test to match the new branding. It was not executed here.

## Remaining limits

Browser preview data is illustrative. Generic form dialogs do not implement CRUD. The React app still needs its own authorized MySQL/OAuth configuration; it is not converted to Supabase. Flutter requires a fresh build and native tests. No production login, RLS behavior, financial operation, Apple signing or Google Play release has been verified by this delivery.

## Final execution results

TypeScript check: passed. React production build: passed. Preview regression tests: 8/8. Backend admission tests: 3/3. Local server smoke checks: 4/4 (home, program deep link, profile deep link, unknown API route). No real backend credentials or database were used in the smoke checks.

## Version 1086 visual mockup update

Added the six-screen PNG in `visuals/`, `VISUAL-MOCKUP.html` and a Windows opener. Added interactive browser-preview screens for class capacity, sample parent linking, static Excel import review, role filtering, and scoped family sample records. New preview regression total: 13/13 passed. Browser checks verified capacity rendering, sample link confirmation, disabled import confirmation, conflict filtering and successful loading of the 1536×1024 mockup image. The image is a concept reference; interactive HTML is not a pixel-exact reproduction. These preview-only additions were not ported to the separate React/Flutter sources. No production operations or APK build were performed.
