# Phase 1 — Additive foundation

## Baseline and scope
- Compared against GitHub default-branch `mobile/pubspec.yaml` and `mobile/lib/main.dart`.
- Readdy's `docs/MOBILE-ARCHITECTURE-BASELINE.md` was not found on that branch; current Windows workspace has **not** been inspected.
- All files in this package are **new paths only**. No existing files are included or modified.
- Empty directories are represented by `.gitkeep` markers.

## Added
- Role enum matching migration 001 `public.app_role`.
- UI-only multi-role module union and navigation metadata (not yet wired to existing router).
- Read-only `user_roles` Supabase repository; **RLS remains the authority**.
- Reusable responsive layout, section card, loading/error/empty states, design tokens.
- Basic role and widget tests.

## Not implemented in Phase 1
- No changes to `main.dart`, auth gate, existing routes, existing theme, Android or iOS.
- No admissions, finance, course, library, content or other new business workflows.
- No schema migrations or database writes.
- No test/build claims: Flutter executable is unavailable here.

## Schema evidence
- `public.user_roles(user_id, role)` and enum `public.app_role`: `supabase/migrations/001_initial_schema.sql`.
- Authentication is already initialized in repository `mobile/lib/main.dart` using dart defines.
- Attendance migration 006 is in repository but its live deployment is not verified.

## Integration gate
1. Compare the current local project with this package; stop if any destination file already exists.
2. Copy only new files into the existing `mobile/` root, preserving its `lib/main.dart`, `pubspec.yaml`, Android/iOS directories.
3. Run `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build apk --debug` locally.
4. Review results before any router integration or Phase 2.
