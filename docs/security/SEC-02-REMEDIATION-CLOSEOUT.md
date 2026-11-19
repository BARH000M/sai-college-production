# SEC-02 Remediation Closeout

## Release decision

**Production remains NO-GO.** This work prepared and validated local source changes only. No hosted database writes, migration-history changes, production deployment, credential rotation, or GitHub settings changes were made. The PR branch is reconciled locally with `origin/main` at `38b03e096c9d61a68cac8438a7100a2a473c18f`; a local backup preserves its pre-merge head. No force-push was used.

The checkout remains `copilot/fix-isolated-contracts-job`, not `main`. The demo migration remains archived at `supabase/archive/demo/017_demo_attendance_week.sql`; it is absent from the production migration directory. The accidental zero-byte root file `0` was removed.

## SEC-02 final GitHub integration — 20 November 2026

- **Conflict and migration integrity:** Resolved the `phase7m/integrity.json` conflict by preserving the merged source state and verifying it against the current files. `python supabase\tools\validate_migrations.py --base-ref origin/main` passes. The archived 017 file retains its original blob/checksum; it is not installed as a production migration.
- **CI build configuration:** The production SPA workflow now supplies the authorized production URL, target flag, an empty preview flag, and a synthetic publishable-key-shaped value. The placeholder is not a credential and is not used to contact Supabase. The local production build passes with that configuration.
- **Local verification:** Root tests 31/31, type-check and lint pass; web tests 112/112; Flutter strict analysis and tests pass; migration validation and tamper tests 8/8 pass; profile/contact, examinations, learning-assessment, native contracts, and Phase 3B reconciliation suites pass on task-owned loopback PostgreSQL clusters. No Docker was used.
- **Workflow integrity:** The root regression test confirms all GitHub Actions references are immutable commit SHAs.
- **Project/key boundary:** Read-only Supabase metadata confirms project `aeryusbrulqdxjdynwfh` (`sai-college-production`) is under organization `BARH000M`, is `ACTIVE_HEALTHY`, and has the expected API URL. The production guard checks the exact project URL, rejects secret keys, accepts only the publishable-key syntax or a legacy anon JWT for that ref, and checks bundle identity. An opaque publishable key's project ownership cannot be proven from its prefix; no key value was fetched or logged.
- **Remote blockers:** Existing GitHub checks are for the previous PR head. The production SPA check failed because CI lacked the required environment, now fixed locally. The separate Supabase Preview check links to a different project; that project was not accessed or modified. Do not push until the owner verifies/rebinds or disables that integration. Main deployment remains NO-GO and no hosted changes were made.

## SEC-01 finding status

“Prepared” means the local fix/package passed the stated checks; it does not mean the hosted service or published app was changed.

| Finding | Local work and verification | Production status |
|---|---|---|
| F01 — unauthorized published backend | Production build now requires the authorized Main URL and public key; the bundle gate verifies backend identity and rejects private credentials. Production build passed. | **Open.** The published site was previously observed using a different project. No website deployment was performed. |
| F02 — branch-membership reassignment | Existing Phase 3B package denies direct tenant-key writes and restricts membership updates; native PostgreSQL authorization/concurrency checks passed. | **Open.** Package not applied to Main. |
| F03 — client-forgeable audit events | Phase 3B package revokes table- and column-level generic audit inserts from untrusted roles and removes the self-insert policy. Admission regression now requires those inserts to fail; native checks passed. | **Open.** Package not applied to Main. |
| F04 — unverified student binding | Existing verified-onboarding package and role tests were retained; native onboarding and isolation checks passed. | **Open.** Package not applied to Main. |
| F05 — plaintext mobile session | Added OS-backed session and PKCE storage, one-time legacy session/verifier migration, logout cleanup, Android backup exclusions, and focused tests. Full Flutter suite passed. | **Source prepared;** no updated mobile release was built or distributed. |
| F06 — missing CSP/anti-framing | Production build emits CSP and anti-framing headers; bundle and header assertions passed. | **Open.** Hosting configuration and live response were not changed or rechecked. |
| F07 — missing HSTS | Production build emits HSTS. | **Open.** No production deployment or live header verification. |
| F08 — unprotected Main branch | No GitHub ruleset or protection setting was changed. | **Open; approval-gated.** |
| F09 — compromised-password protection disabled | No hosted Auth setting was changed. | **Open; approval-gated.** |
| F10 — broad signing-keystore ACL | Removed inherited access and verified a protected ACL with three explicit trusted rules and no broad Users/Authenticated Users access. Key contents and passwords were not read. | **Local ACL remediated.** Key custody/recovery is unverified; `mobile/android/key.properties` is absent, so signing is unavailable. |
| F11 — mutable GitHub Action tags | Checkout, setup-node, setup-python, and Flutter actions are pinned to full commit SHAs; a regression test enforces immutable references. | **Source prepared;** changes have not been pushed to Main. |
| F12 — library RPC search paths | Existing library invoker RPCs now have an explicit trusted search path; native package tests passed. | **Open.** Package not applied to Main. |

No hosted finding is claimed resolved. F08 and F09 require the separately approved external changes. F01–F07 and F12 still require the appropriate deployment and live verification.

## Validation results

| Check | Result |
|---|---:|
| Root Node tests (`npm test`) | 31/31 passed |
| Web compatibility tests (`npm --prefix web test`) | 112/112 passed |
| Flutter tests | Passed (latest run: 67 tests) |
| Migration-validation tamper tests | 8/8 passed |
| TypeScript type-check | Passed |
| Production website build | Passed; Vite reported the existing large JavaScript chunk warning |
| Flutter strict analysis (`--fatal-infos --fatal-warnings`) | Passed; no issues |
| Native PostgreSQL contracts | Passed: profile/contact, examinations, learning-assessment, native contract suites, plus Phase 3B/Phase 7M reconciliation and security regressions on task-owned loopback clusters |
| Standalone runtime validation | 5/5 assertions passed: type-check, root tests, web tests, production build, and HTTP 200 on the local home route |
| Targeted source secret scan | 0 private-key or `sb_secret_` markers in 230 production-source files |
| Android release-signing guard | Passed for APK and AAB: unsigned release builds were blocked because signing configuration is missing |

The standalone runner could not parse the Node test reporter's detailed counts and used its documented exit-code fallback for `tests-pass`; the direct root test run reported 31/31.

No Docker was used. Native PostgreSQL used synthetic data on an isolated loopback cluster and was stopped after each run.

## Database package readiness

- Read-only remote migration-history reconciliation found 33 authoritative versions: 001–016, 018–031, and three `20261110` versions. No migration was replayed or history repaired.
- The local migration lock remains intact; version 017 is checksum-validated at its archived demo path. No duplicate migration was created.
- The Phase 7R source manifest and integrity pins were refreshed and verified across 48 required files. `python supabase\tools\validate_migrations.py` and its eight tamper tests pass.
- The existing forward-only deployment package remains `release_ready: false`, decision `NO-GO`. Recovery, external write-hold, owner approval, hosted contract parity, clean-main checkout, and other release gates remain outstanding.
- Production data and migration history were not modified.

**Database deployment readiness: package validated, deployment blocked.**

## Website readiness

The production build passed its environment and output gates, produced `out/_headers`, and contains only the authorized backend identity. Source maps are disabled. The live website still requires a reviewed deployment and response-header/backend verification; no hosting deployment command is configured in this repository.

**Website deployment readiness: build-ready, not deployed; production identity remains an active blocker.**

## Mobile readiness

Secure session/PKCE storage, legacy migration, logout, and Android backup exclusions are implemented and covered by tests. The local signing keystore ACL is restricted. No `key.properties` is present, so neither a signed APK nor AAB could be produced. The release guard was verified to reject unsigned APK and AAB builds. No release artifact is approved for distribution.

When signing configuration and the protected keystore are available, run from `mobile`:

```powershell
flutter build apk --release --obfuscate --split-debug-info=build/release-symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/release-symbols
```

**APK readiness: blocked on signing configuration and a fresh signed/obfuscated build. AAB readiness: blocked on the same requirements; no AAB was built.**

## Phase 5A–6B development

Existing library, system-settings, communications, and other module surfaces were preserved rather than rebuilt. The roadmap and local schema search do not provide deployment contracts for HR documents/payroll, official certificates, front-CMS publishing, inventory/transport/dormitory, or scholarships/alumni/recruitment. Library renewal rules are also not specified by the current contract. No speculative client writes or duplicate schemas were introduced.

| Phase | Remaining work |
|---|---|
| 5A | HR directory, protected documents, leave, attendance, and payroll contracts/workflows |
| 5B | Service requests, official certificate numbering/verification, and complete print/export workflows |
| 5C | Verify settings-to-behavior wiring and deploy the reviewed settings contract |
| 5D | Provider-backed email/SMS/WhatsApp/push delivery, consent, retries, and delivery logs |
| 5E | Draft/preview/publish CMS and public-site parity |
| 6A | Library renewal policy; inventory, transport, and dormitory workflows/contracts |
| 6B | Scholarships, alumni, recruitment, and reconciled report/export workflows |

No DODO development was started.

## Commands

Local checks from the repository root:

```powershell
npm test
npm --prefix web test
npm run type-check
npm run build
python supabase\tools\validate_migrations.py
python supabase\tests\test_migration_validation.py
$env:SAI_PG_BIN = 'C:\Program Files\PostgreSQL\17\bin'
python supabase\tests\phase3b-main\run_local.py --reconciliation
python supabase\tests\run_native_contracts.py
Push-Location mobile
flutter analyze --fatal-infos --fatal-warnings
flutter test --reporter expanded
Pop-Location
```

The reviewed database executor is the only prepared production execution path. It must not be run until the manifest is release-ready, the checkout is clean on `main`, and the separately approved owner/recovery/external-hold attestations are supplied. Its gated command is:

```powershell
pwsh -NoProfile -File supabase\deployment\phase7r\Invoke-MainDeployment.ps1 -Execute -ApprovalFile "<external-owner-approval.json>" -RecoveryAttestationFile "<external-recovery-attestation.json>" -ExternalHoldAttestationFile "<external-hold-attestation.json>" -PsqlPath "C:\Program Files\PostgreSQL\17\bin\psql.exe"
```

With the current `NO-GO` manifest this command is not deployable. No website deployment command is recorded because the hosting target is not configured in the repository.
