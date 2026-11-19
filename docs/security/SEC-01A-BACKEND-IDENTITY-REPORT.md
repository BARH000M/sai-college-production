# SEC-01A Final Backend Identity Reconciliation

Date: 2026-11-19. Historical remote Preview retirement explicitly authorized by the owner. Earlier uncertain-purpose blocker is closed for the local file. **Local reconciliation PASS; published website identity FAIL (SEC-01-F01).**

## Secure quarantine record

- Original: D:\SAI-College-Production\.env.preview.local.
- Timestamped private directory: C:\ProgramData\YemenSAI-Security-Quarantine\20261119-225218.
- Backup filename: env.preview.local.backup.
- Quarantined original filename: env.preview.local.quarantined.
- Original and both final copies SHA-256: 0929DBDCA6C4D562E50FECFCED0D81AC5836980ACF21CF7899DACCE004CD1C69.
- Backup copy, hash match and ACL checks completed before moving the original. Final verification matched both copies; original-path existence returned false.
- Directory inheritance removed; both files independently verified to have only current Windows user and SYSTEM FullControl allow entries. No credential values reproduced.
- The directory is outside this repository's absolute work tree and Git staging scope. This physical separation, rather than an ignore exception, prevents its inclusion by this repository's Git add. No content was staged. External cloud-sync/encryption policies were not audited.

## Reference classification

| Class | Evidence / disposition |
|---|---|
| Active production configuration | Root/web env, Flutter constants/live JSON, CLI target/link, .mcp.json, .vscode/mcp.json, .codex/config.toml, launch/build guards identify aeryusbrulqdxjdynwfh; E03 |
| Local offline testing | mobile/config/preview.json, demo branch, mocks, VERIFY_LOCAL.ps1 and existing tests preserved. Retired URL in web/tests/startup.test.cjs:32,65 is negative-test input, rejected before client creation; E04 |
| Historical documentation | Prior Preview reports, including PHASE_3A_1_PREVIEW_ENVIRONMENT_AND_SMOKE_TEST.md, describe the retired manual command and are retained as history |
| Git history | Reachable historical examples/cache/reference blobs are evidence, not active configuration; E07/E08 |
| Obsolete configuration | .env.preview.local quarantined outside active workspace; no credential or URL replacement |
| Unauthorized active backend | Published Supabase client chunk initializes reprjetryjveowspusxd.supabase.co, rather than the authorized project; F01/E05 |

No active local configuration targeting mgibjusuglafbnlrkbep was found after quarantine. Neither retired Preview nor the third backend was contacted. Historical references and offline mocks did not block independent audit work.

The actual deployed website mismatch blocks release and dependent testing of that deployment's backend. Independent read-only catalogs explicitly scoped to aeryusbrulqdxjdynwfh and other independent audit workstreams were completed. No automatic repointing is authorized.

## Existing work and tests

The staged relocation remains R100, 100644, blob prefix 312c944 unchanged from supabase/migrations/017_demo_attendance_week.sql to supabase/archive/demo/017_demo_attendance_week.sql. No stage/unstage/revert/commit/push. Application source, local preview and tests untouched.

Identity integration tests: 4/4 pass. Full web tests: 111/112 pass; separate migration inventory failure retained. No fixes implemented.

Final SEC-01 assessment: 60 checks, PASS32 / FAIL12 / BLOCKED3 / UNVERIFIED13; P0 0 / P1 2 / P2 8 / P3 2. Production readiness: NOT APPROVED. See audit and evidence matrix for exact boundaries.

## Final Git-boundary verification

The initial private location under LocalAppData was outside the application repository, but a final Git check identified the user profile as another ancestor Git work tree. Both files were moved, without deletion or staging, to the final ProgramData path above. Before transfer and afterward, Git checks verified the destination is not inside a Git work tree. Both SHA-256 values and user/SYSTEM-only ACLs were reverified; both files are absent from the initial location. The empty old directory was left untouched. No other workspace or Git index was changed. This correction was completed before delivery.
