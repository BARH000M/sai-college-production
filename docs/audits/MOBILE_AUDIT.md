# Flutter / Android / iOS audit
- `mobile/` production source exists and has a profile/auth/repository/screen structure, preview mode, shared data modules, settings screen, role registry and unit/widget tests. Android/iOS project files exist in GitHub.
- Official brand constants present: `Yemen SAI`, Arabic `كلية ساي التعليمية اليمنية الصينية`, Chinese `也门赛艾教育学院`; Cairo and NotoSC bundled.
- Flutter `backendUrl` is hard-coded to approved Supabase project and public key is provided through `--dart-define-from-file=config/live.json`; user previously verified a matching public key in the dashboard. Do not include secrets in a signed app.
- User's supplied local log: `flutter analyze` PASS; `flutter test` FAIL on `image 4.11.0` calling missing `archive 4.0.9` method `decodeLazy`; BUILD_LIVE stops at tests. Remote `pubspec.yaml` now pins image 4.8.0 via override, but local version may differ.
- This package checks/sets compatible override `image: 4.8.0`, makes brand title match, declares `zh-CN` as a supported locale and adds a backend/brand test. It does **not** implement runtime language selection or translate existing screens.
- Preview workspace contains demo data by design; verify production build never enables `SAI_PREVIEW`. Do not label preview values as backend progress.
- iOS signing/IPA/TestFlight unavailable in this environment; Android APK not built here. End-to-end device and store safety checks remain MISSING.

**Next gate:** `flutter pub get`, `flutter analyze`, `flutter test --dart-define-from-file=config/preview.json`, `flutter build apk --debug --dart-define-from-file=config/live.json`, physical device login, role-specific API and offline checks. Do not run live build if tests fail.
