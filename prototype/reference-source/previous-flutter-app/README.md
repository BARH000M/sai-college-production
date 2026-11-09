# YSMS mobile repair

This delivery repairs the existing Flutter client in `mobile/`; it is not a replacement application. Android and iOS share the same Dart application, Supabase session, tenant-scoped API calls, and role routing.

## Toolchain

- Flutter 3.24.5 / Dart 3.5.4
- Android SDK 34, Java 17, Gradle 8.4, AGP 8.3.2, Kotlin 1.9.22
- iOS deployment target 12.0; bundle ID `com.sai.ysms`
- Android namespace/application ID `com.sai.ysms`

## Configure and run

Use the public anonymous Supabase client key only. Never put `service_role`, database passwords, or other privileged credentials in Dart code, `.env`, CI artifacts, or the application package.

```sh
cd mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

Missing configuration produces an explicit Arabic setup error, not a simulated login or empty dashboard. Authentication sessions are restored by Supabase. The callback for both platforms is `ysms://auth/callback`; this URL must also be allow-listed in the existing Supabase Auth configuration by the project owner.

## Interface

The shared Android/iOS interface uses bundled Cairo fonts (SIL OFL 1.1; license in `mobile/assets/fonts/OFL.txt`) and a jade, cinnabar, and warm-paper heritage theme. The login opens only the role returned by the authenticated Supabase profile; it contains no demo-account or role-switching bypass.

## Implemented role workflows

- Platform owner: institution-scoped overview, messages, and account.
- School administrator: dashboard, existing idempotent fee posting, lessons, messages, and account.
- Teacher: assigned classes, roster, attendance writes, assignments, lessons, messages, and account.
- Parent/student: linked students only, attendance, class assignments, published-only results, lessons, messages, and account.
- Accountant: finance dashboard, messages, and account; no fee-posting action.
- Employee: own employee record, attendance and leave history, messages, and account. Leave creation is deliberately absent because the inspected policy grants leave inserts to administrators.

Navigation is a usability boundary, not an authorization boundary. Existing Supabase RLS and RPC checks remain the security boundary. Failed requests remain visible errors with retry; they are not rendered as successful zero counts.

## Build Android

```sh
flutter analyze
flutter test
flutter build apk --debug
# Optional smaller device-specific packages:
flutter build apk --debug --split-per-abi
flutter build appbundle --release
```

The release AAB command validates release compilation. Without `android/key.properties`, its output is unsigned and must not be uploaded as a signed production release. For a signed build, the owner copies `android/key.properties.example` to the ignored `android/key.properties` and supplies their own keystore. No debug-key fallback is used.

GitHub Actions includes debug APK and unsigned release-AAB verification, checksums, logs, and a separate manually dispatched owner-signed AAB workflow. The signed workflow fails if any owner credential is absent.

## iOS

`mobile/ios` contains YSMS icons and launch resources, Arabic/English localization, RTL-compatible shared UI, the `ysms` callback scheme, and no added device/privacy permissions. `.github/workflows/mobile-ios.yml` runs on macOS and compiles an unsigned simulator app. It does not create or claim a signed IPA. Device/App Store output requires the owner's Apple signing assets and a macOS/Xcode build.

## Multi-school behavior

School name, color, logo, academic year, and tenant data are loaded through the authenticated Supabase profile and existing RLS. The current profile model has one active school context. There is no fabricated client-side school switcher: adding one requires an existing authorized server membership/tenant-selection contract and authenticated tests.

## Security hold and test limitations

Migration `0080_least_privilege_classified_anon_revoke.sql` remains pending. Do not run a blanket migration replay against it. Before using the repository's denial-matrix workflow, exclude that exact file from every replay path, including independent migration-order verification. See `repository-patches/HOLD-0080.md`.

No production schema, permission, financial record, or demo data was changed by this mobile repair. Local unit/widget tests do not prove authenticated tenant isolation. Run the repository's isolated denial, finance, period-lock, maker-checker, HR, and release-gate suites with migration 0080 held back, plus authenticated mobile tests against a disposable project, before authorizing production release.
