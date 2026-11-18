# Build and deployment status — Phase 7-R

Read-only status reconciliation, 17 November 2026. This is not a release
approval or a claim that the earlier phase validations were rerun.

## Local Phase 4B verification refresh — 18 November 2026

The root React/Vite production build succeeded to `out/`; it contains the
existing Cairo fonts, SAI logo and Chinese font assets. `npm run type-check`,
`npm run lint`, and `npm --prefix web test` passed; the web suite reported
105/105 with no skipped tests. From `mobile/`, `flutter pub get`,
`flutter analyze` and `flutter test` passed, with 61/61 mobile tests.

The configured Android debug APK build succeeded at
`mobile/build/app/outputs/flutter-apk/app-debug.apk` (194,102,078 bytes,
SHA-256
`ce925355b2a9c9b347ec4b9e799eabc4d3d7b65b7d583b08b3618325bcbd5d46`,
built 18 November 2026 19:13 +03:00, version 1.2.1,
`com.saicollege.mobile`, source commit `7de6eef`). The local JSON uses the
target Supabase URL and `SUPABASE_PUBLIC_KEY` variable; the public key's
project ownership was not independently confirmed. The release keystore exists
but is ignored, and `key.properties` is absent, so release signing and device
acceptance remain unverified. No artifact was deployed or published.

The verified partial Phase 4B implementation is committed on local `main` as
`2a13081f771e01f5b73e5fa5aa0648ac938b2054`; no push was made. The report
and roadmap updates are being committed separately from implementation.

| Target | Current result | Evidence / limitation |
|---|---|---|
| GitHub `main` | LOCAL COMMITS AHEAD; NOT PUSHED | Local `main` includes Phase 7-M and verified Phase 4B progress, ahead of the `origin/main` tracking ref. No push or live remote synchronization claim is made. |
| GitHub automation | CI ONLY | Inspected `.github/workflows/web-ci.yml` and `mobile-ci.yml`: push, PR and manual triggers; no database migration or production deployment action found. |
| Supabase Main | READ-ONLY, ACTIVE_HEALTHY | Project `aeryusbrulqdxjdynwfh`, PostgreSQL 17.11. No SQL writes, migrations or function deployments were made in this task. |
| Main migration/contract inventory | 16 recorded migrations; 47 public tables with RLS enabled | Main migration list and public table catalog were read-only. Proposed Phase 3B RPCs, Phase 3C contact guard and Phase 4A examination tables remain absent according to current catalog/reconciliation evidence. |
| Hosted Edge Functions | LEGACY VERSIONS ACTIVE | `manage-roles` v9 (`verify_jwt=false`), `school-admin` v7 (`false`), `provision-learning-account` v8 (`true`), `link-student-account` v4 (`true`). Do not deploy until the exact local source/config, database contract and global write hold are approved. |
| Local Phase 3B | VALIDATED PACKAGE; NOT DEPLOYED | Existing closeout reports type-check/lint, 88 web tests, 7 Deno tests and isolated PostgreSQL behavior passed. This is not production acceptance. |
| Local Phase 3C / 4A | IMPLEMENTED; NOT DEPLOYED | Earlier reports record passing tests. They were not rerun in this preflight. |
| Local Phase 4B | PARTIAL; LOCAL TESTS PASS | Assessment, practice-isolation and migration assertions were tested. Full feature/role/Storage requirements remain incomplete; see `PHASE_4B_COMPLETION_REPORT.md`. |
| Root React production build | PASS, local only | `npm run build` generated the `out/` artifact; deployed identity and live behavior remain unverified. |
| Android APK / AAB | Debug APK PASS; AAB/signing NOT VERIFIED | Configured debug build succeeded. No device test or release keystore configuration (`key.properties`) was used. |
| iOS IPA / TestFlight | NOT BUILT | Requires macOS, signing and store validation evidence. |
| `www.sai-academic.com` | NOT DEPLOYED | Prior preflight reported HTTPS response; deployed artifact identity, authenticated behavior, hosting write access and rollback were not verified here. |
| Production acceptance | NOT RUN | No controlled production accounts or records were used. No authenticated nine-role web/mobile test was made. |

**Disposition: NO-GO.** No production change was made. See
[`PRODUCTION_DEPLOYMENT_STATUS.md`](./PRODUCTION_DEPLOYMENT_STATUS.md) for the
recovery gate, package hashes, dependency order, stop conditions and rollback
limits.
