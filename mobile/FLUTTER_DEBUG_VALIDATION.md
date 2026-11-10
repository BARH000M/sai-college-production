# Flutter debug validation — 2026-11-09

## Results

- `dart format`: completed for all changed Dart files.
- `flutter analyze --no-pub`: passed, no issues found.
- `flutter test --no-pub`: passed, 3 widget regression tests.
- `flutter build apk --debug --no-pub --dart-define-from-file=build/debug-defines.local.json`: passed.
- APK verified at `D:\SAI-College-Production\mobile\build\app\outputs\flutter-apk\app-debug.apk`.
- APK size: 163,438,454 bytes.
- SHA256: `42727c7947bc0735cbf3c0b1160239131babcf2ed85d231b046c5cd1ab689b89`.
- Verified bundled Cairo 400/600/700 fonts and the existing SAI logo.

## Fixes

- Initialized branch, session, teacher ID and teacher name in `initState`, retaining existing edit values.
- Used `Future.wait<Object>` for the heterogeneous lookup results; retained queries, selection defaults and error handling.
- Added a transparent Material ancestor for the form's SwitchListTile, fixing an assertion exposed by widget tests.
- Applied analyzer cleanup: color API replacements, const/brace/interpolation fixes, an unnecessary cast, and two unused navigation constants. Active navigation mappings and permissions were unchanged.
- Updated the deprecated Supabase initialization parameter to `publishableKey`; retained the existing environment variable and public key value.
- Added mocked tests for create defaults/query parameters, edit values and teacher lookup, and lookup failure/save disabling. Added `http` as a development dependency using the already resolved 1.6.0 version.
- Preserved the tracked two-byte regular file occupying `build` as `build.preexisting-file-20261109162529.bak`, allowing Flutter to create its required build directory. Git consequently shows the old `build` file as deleted; its contents remain in the backup.
- Updated Kotlin 2.1.0 to the installed Flutter SDK's minimum 2.2.20. Gradle 8.14.3 and AGP 8.11.1 were retained.
- Disabled Jetifier after its transformation of Flutter engine JARs exhausted the existing 1 GB heap. A successful resolved debug dependency report showed zero `com.android.support` dependencies. Existing heap and worker limits were retained.

## Files changed by this task

- `lib/features/academics/class_form_sheet.dart`
- `lib/features/academics/class_roster_sheet.dart`
- `lib/features/academics/classes_seats_page.dart`
- `lib/core/app_nav.dart`
- `lib/features/attendance/class_register_page.dart`
- `lib/features/modules/module_page.dart`
- `lib/features/modules/modules_page.dart`
- `lib/features/notifications/notifications_page.dart`
- `lib/features/roles/roles_permissions_page.dart`
- `lib/features/students/parent_link_page.dart`
- `lib/features/students/student_import_page.dart`
- `lib/main.dart`
- `lib/widgets/sai_drawer.dart`
- `lib/widgets/section_header.dart`
- `lib/widgets/state_views.dart`
- `android/settings.gradle`
- `android/gradle.properties` (only Jetifier changed by this task; earlier user changes preserved)
- `pubspec.yaml`
- `pubspec.lock` (pre-existing untracked lockfile, updated by dependency resolution)
- `test/class_form_sheet_test.dart` (new)
- `build` file relocated to `build.preexisting-file-20261109162529.bak`
- `FLUTTER_DEBUG_VALIDATION.md` (this report)

Pre-existing edits in `analysis_options.yaml` and `GeneratedPluginRegistrant.java` were preserved. No database schemas, migrations, RLS policies or credentials were changed. No commits or pushes were made.

## Remaining limits

No remaining analyzer, test or APK build failures. Flutter emits future-support warnings for Gradle, AGP and Kotlin. The APK has not been installed or exercised on an Android device, and authenticated backend/role behavior was not tested. The three tests use mocked responses and do not establish live RLS or backend correctness.

The build consumed only existing local public Supabase settings. The temporary defines file was removed after the build, and the generated heap dump from the failed build was removed. The dependency inspection report remains under ignored `build/debug-dependencies.txt`.
