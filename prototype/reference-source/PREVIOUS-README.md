# Version 1086 visual update

Open **VISUAL-MOCKUP.html** to see the new six-screen mockup image, or **OPEN-VISUAL-MOCKUP.cmd** on Windows. The full PNG is in `visuals/`.

The browser preview now also includes Version 1086 screens for class capacity, sample parent linking, Excel import review, role audit, and separate linked-parent/personal-student views. Sign in with the supplied preview accounts and use the Version 1086 menu. All actions are illustrative; selected Excel files are neither uploaded nor parsed.

This update changes the **visual mockup and browser preview**. The React and Flutter sources from the previous delivery remain included; these new preview screens have not been ported into those separate applications, and no new APK has been compiled. The mockup image is a design reference, not a pixel-exact screenshot of the interactive HTML.

---

# SAI College — redesigned app package

The uploaded archive contained three independent applications. This package updates their existing sources without changing production data, database policies, application IDs or signing assets.

## Open the finished visual preview

Extract the full ZIP. On Windows run `OPEN-PREVIEW.cmd`; on any desktop open `browser-preview/index.html`. For a phone-sized preview open `PHONE-PREVIEW.html`. All fonts are bundled locally; no installation is needed. Use **عرض حسابات المعاينة** and the supplied local sample accounts. Forms remain illustrative; no real records are created.

## Visual changes

Unified burgundy `#8F2636`, gold `#C69B4D`, warm ivory `#F7F5EF`, local Cairo typography, Arabic RTL, rounded cards, larger touch targets, clearer table rows, responsive forms, mobile navigation, refreshed login and quieter backgrounds. A typographic SAI mark is used because no approved master logo was supplied in these sources. It is not represented as the official emblem.

## Windows / React application

`windows-app/` includes the edited source and a fresh successful production build in `dist/`.

Requirements: Node.js 22 LTS and npm; an independently configured backend is required for live data.

1. Open a terminal in `windows-app`.
2. Copy `.env.example` to `.env` and configure the existing application's MySQL and Kimi authentication environment locally. Use your own authorized configuration. Do not paste secrets into chat.
3. Run `npm ci`.
4. Run `npm run build` after setting frontend environment values, then `npm start`, or use `OPEN-APP-WINDOWS.cmd`.
5. Open `http://localhost:3000`.

The source supplied for this particular React app uses **MySQL + Kimi OAuth**, not the college's Supabase backend. No backend migration or new database was created. A build is not proof of a working authenticated production deployment. The packaged build has no embedded owner credentials; login clearly reports absent configuration.

The cross-platform `start.mjs` replaces the Unix-only `NODE_ENV=production ...` command. `package-lock.json` uses the public npm registry instead of the original failing private mirror.

## Android / iOS source

`flutter-app/mobile` retains the existing Supabase authentication, roles, RPCs, backend contracts and application ID `com.sai.ysms`. The theme, login, app bar, navigation and responsive metric layout were updated. Server-provided tenant branding still takes precedence.

Use the existing documented Flutter 3.24.5 toolchain. From `flutter-app/mobile` run:

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config.local.json
```

Create `config.local.json` locally with `SUPABASE_URL` and `SUPABASE_ANON_KEY` for the existing authorized project. Only the public client key belongs in the mobile configuration; never use a service-role key. Keep this local file private. The source shows a configuration error if settings are missing.

**No Flutter/Dart SDK was available here. Native analysis, widget tests, APK/IPA compilation, device playback and authenticated backend workflows remain unverified.** Use your existing signing setup for release. Apple builds require macOS/Xcode and Apple signing.

## Validation

- `node --check browser-preview/app.js`: passed.
- `node --test tests/preview-regressions.cjs`: 8 passed.
- In `windows-app`: `npm run check`, `npm test` (3 tests), `npm run build`: passed.
- With the Windows app's dependencies installed: `node tests/windows-smoke.mjs` from the package root tests local server startup, three HTML/deep routes and API 404 using dummy configuration. It does not connect to a database.
- Browser inspection at desktop width and a phone iframe: preview login, mobile home, menu opening, calendar month changes and overflow were checked. Phone home measured equal client/scroll widths (375 px).

## Package boundaries

The original uploaded archive is unchanged. Old APKs, duplicate source ZIPs, machine-local generated files, dependencies and the supplied real `.env` are not included in this new deliverable. No store-ready binary is claimed. See `BUG-FIX-REPORT.md`.
