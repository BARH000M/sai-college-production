# Security Evidence Matrix

Date: 2026-11-19, Asia/Aden. Sanitized contemporaneous observations; no private credential values or student records included. Controls: 60; PASS 32, FAIL 12, BLOCKED 3, UNVERIFIED 13. Confirmed findings: P0 0, P1 2, P2 8, P3 2. PASS applies only to explicitly stated scope.

## Follow-up — 20 November 2026

This follow-up supersedes E10/C17 only for the current checked-in workflow source; it does not change the historical audit snapshot or establish production deployment. Root, mobile, and database workflow action references are full immutable commit hashes, and the root test suite's immutable-action regression passes. The SEC-02 branch's migration integrity and deployment manifest validate locally; 017 remains archived and no production migration was applied.

The production build now uses a non-secret synthetic publishable-key-shaped CI fixture with the authorized URL and target flags. The code checks the endpoint's exact project URL, rejects secret keys, and constrains legacy anon JWT project claims. The opaque publishable key is not fetched, and its project ownership is not inferred from its prefix. Separate read-only Supabase metadata confirms that the authoritative project is `sai-college-production` in organization `BARH000M`. The previous PR's Supabase Preview status links to a different project; it was not accessed or changed. Push remains blocked pending owner confirmation that the integration cannot modify a retired/non-authoritative project. Production remains NO-GO.

## E01 — Repository identity and existing work

Read-only git branch, remote, status and cached raw diff. Branch main; origin https://github.com/BARH000M/sai-college-production.git. Before/after staged relocation remained R100, modes 100644, old/new blob prefix 312c944. Paths: supabase/migrations/017_demo_attendance_week.sql -> supabase/archive/demo/017_demo_attendance_week.sql. No index writes.

## E02 — Authorized quarantine

Original D:\SAI-College-Production\.env.preview.local. External directory C:\ProgramData\YemenSAI-Security-Quarantine\20261119-225218. Backup env.preview.local.backup created before moving original to env.preview.local.quarantined. SHA-256 original and both final copies: 0929DBDCA6C4D562E50FECFCED0D81AC5836980ACF21CF7899DACCE004CD1C69. Final original path absent. Directory inheritance disabled; both files independently verified to allow only current Windows user and SYSTEM FullControl. Physically outside this repository's work tree/Git staging scope.

## E03 — Local Production identity

Locations: .env:2; .env.local:1; web/.env:1; web/.env.local:1; mobile/config/live.json:4; mobile/lib/data/repository.dart:5-6; src/portal/lib/supabase.ts:8; supabase/.temp/project-ref:1; .mcp.json:5; .vscode/mcp.json:5; .codex/config.toml; supabase/target.local.json:3; .vscode/launch.json:9. Selected URLs/references agree on aeryusbrulqdxjdynwfh. MCP configurations use read_only. Root build is vite build; web build delegates to root. scripts/CONFIGURE_BACKEND.ps1:10 rejects another ref. No script was executed to rewrite configuration.

Targeted reference searches covered env, src, web/src, scripts, workflows, Android, VS Code and mobile. Historical/reference/prototype/backup directories are not live production launch sources. Negative test references in web/tests/startup.test.cjs are not active clients.

## E04 — Offline preview / negative fixtures

mobile/lib/main.dart:22 demo branch runs before Supabase initialization and uses DemoWorkspace; mobile/config/preview.json contains only local preview flag. scripts/VERIFY_LOCAL.ps1:19 retains local Flutter test flag. web/tests/startup.test.cjs:32,59,65 uses the retired host as negative input and rejects it before createClient. No mock/test/offline functionality changed.

## E05 — Deployed website identity and public bundles

GET sai-academic.com redirects to https://www.sai-academic.com/ (200). Main document references /assets/index-DnIEro_9.js, which references ./supabase-DWFLzbPp.js. Raw main bundle SHA-256 9e9175a34faf8ebd45a22dc60126e78605e5eb83c823a8ccd9dbd22c11d400f5. Supabase chunk SHA-256 281b284605a83d1f727e24b859330d87400026dcfb159920bffe8f2a38895c89.

At chunk line 22: URL constant identifies reprjetryjveowspusxd.supabase.co; that constant is passed to the Supabase factory with persistSession=true and storageKey=sai-academic-auth-v8. Key type is intentionally public publishable; value omitted. This establishes an actual published initializer conflict. No request to that project's backend.

Main map request returned HTTPError; no sourceMappingURL found. Initial automated relative-chunk traversal incorrectly joined assets/ paths and received HTTP errors. Corrected canonical-path requests for the Supabase chunk and a bounded selection of referenced chunks succeeded. This was not an exhaustive bundle/map inventory; no broad secret-free deployed-app claim.

## E06 — Public versus private keys

Selected .env/.env.local/web/.env.local/mobile live JSON contain publishable keys. web/.env has a legacy JWT with role=anon and ref=authorized Production. JWT decoding classified payloads only, not signatures. Opaque publishable-key ownership is not proven by prefix. Browser initializer src/portal/lib/supabase.ts:22-30 rejects secret prefixes and legacy non-anon/wrong-ref claims; mobile/lib/main.dart:61 onward has equivalent checks. Server Deno.env.get(SUPABASE_SERVICE_ROLE_KEY) references are variable reads, not embedded secrets.

## E07 — Workspace and reachable Git credential signatures

In-memory scan included hidden paths and ordinary/vendor/local text, excluding .git from the file walk and examining Git objects separately. Text signatures covered private PEM markers, Supabase secret prefixes, GitHub/AWS keys, JWT claim classification and quoted credential assignments.

- Workspace text processed: 32,436 files.
- Workspace skipped: 65 unreadable entries, 51,966 binary files, 94 files over 5 MB.
- Reachable Git blobs enumerated/processed: 3,283; binary/large blobs excluded from text signatures: 476.
- Locally reachable commits: 230; repository not shallow. No fetch, reflog or unreachable-object scan.
- Workspace hits: 85 quoted credential-name literal matches, 2 anon JWT matches. Git: 29 quoted-literal matches, 2 anon JWT matches. Literal matches included dependency fixtures, UI labels and mocked .test/.invalid accounts/service keys; active-source candidates were reviewed without reproducing values. No confirmed production private credential literal identified.
- Arbitrary/encoded/unquoted secrets, binary browser session stores, large/unreadable files and AOT strings remain outside exhaustive clearance.

Initial filesystem walk encountered an existing unusual filename; retry handled filesystem errors. The later complete scan counts above supersede the interrupted preliminary scan.

## E08 — Tracked files and ignore rules

git ls-files sensitive-path inventory found environment/signing examples, not actual current tracked env, keystore, Firebase service files or private certificates. .gitignore:11 onward excludes .env*, keys/certificates/keystores, Firebase files and generated outputs; later rules exclude browser sessions and local clusters. git check-ignore confirmed Preview exclusion before quarantine. A local ignored release JKS exists (E13). Historical deleted browser/cache paths occur in reachable Git objects; current tracked browser-profile path count was zero. Binary historical session residue unverified.

## E09 — GitHub read-only API evidence

Repository is public, default branch main. Secret scanning and push protection enabled. Non-provider patterns and validity checks disabled; Dependabot security updates disabled. Current alert API returned count 0. Main protection endpoint returned HTTP 404 “Branch not protected”; repository rulesets returned []. Actions enabled; allowed_actions=all. No settings changed. These are point-in-time accessible metadata, not proof of absent historical exposure.

## E10 — Workflow security

.github/workflows/database-ci.yml:10; web-ci.yml:27; mobile-ci.yml:22 set contents: read. Inspected workflows perform checks, not production deployment. External actions use mutable tags at database-ci.yml:15,18; web-ci.yml:33-34; mobile-ci.yml:37,40. CI execution success/settings beyond obtained API metadata were not established.

## E11 — Dependency advisory lookups

npm.cmd audit --json --ignore-scripts, root: 323 dependency entries, zero known vulnerabilities. web: 81, zero. Restricted-network failures were retried with authorized network access, not treated as valid negative results. OSV querybatch sent names/locked versions only for 102 hosted Pub dependencies; no matches. No installs/upgrades or lockfile changes. Advisory-only checks do not prove code integrity or absence of unpublished vulnerabilities.

## E12 — APK evidence

Existing SDK tools build-tools/36.0.0 aapt.exe and apksigner.bat; ZIP-entry byte-pattern checks. Six paths/five unique hashes detailed in audit report. Signature verifies for ap00p-release-signed.apk, which is not debuggable. Two unsigned intermediates fail signature verification; Debug artifacts have Android Debug certificate, debuggable flag and kernel_blob.bin. APK version 1.2.1+4, package com.saicollege.mobile, minSdk24/targetSdk36.

Signed manifest: MainActivity exported for launcher/custom auth scheme; PrintFileProvider, startup provider and WebViewActivity exported=false. ProfileInstallReceiver exported=true under android.permission.DUMP. Network permissions plus internal signature permission; no unnecessary dangerous permission observed.

Detected backend host in inspected APKs: authorized Production. Secret-prefix/PEM signatures found no confirmed private credential. Debug kernel contains six BEGIN-private-key delimiter markers, but zero strict base64-valid private PEM blocks; delimiter proximity alone is not secret exposure. Signed AOT strings may be split/encoded; no full decompilation. Signing certificate ownership/store/distribution identity not verified.

## E13 — Signing configuration and ACL

mobile/android/app/build.gradle:49 requires release keystore properties for signing and does not silently use Debug signing. Local mobile/android/app/yemen-sai-release.jks has inherited ACL including BUILTIN Users ReadAndExecute and Authenticated Users Modify, plus other inherited principals. No key.properties password was printed, no keystore opened/cracked/exported. Password strength, key custody, backups and restore unverified. File ACL is a confirmed local-material access weakness, not proof of private-key compromise.

## E14 — Flutter auth/platform source

mobile/lib/main.dart:35-40 explicitly persists session via SharedPreferencesLocalStorage. Backup XML mobile/android/app/src/main/res/xml/sai_session_backup.xml:2 and sai_session_transfer.xml:3,6 exclude FlutterSharedPreferences.xml. Main manifest:9-20 includes backup resources and custom saicollege://auth/callback scheme; iOS Info.plist includes the scheme. No dynamic callback/PKCE/state validation or iOS runtime/Keychain assessment.

SDK authentication, user_roles loading, refresh retry and account/no-role gates reviewed. Active mobile search found no badCertificateCallback/HttpOverrides certificate-validation bypass. Target SDK/no override does not substitute for runtime TLS testing. No production login, device tests or token extraction.

## E15 — Web/session/cache/unsafe HTML review

src/portal/lib/supabase.ts:36-42 persists SDK browser sessions. auth.ts:90 reads roles from database; user_metadata at :129 initializes profile name/locale, not roles. Active src/web source search returned no direct dangerouslySetInnerHTML/innerHTML/eval/document.write sink. This is not proof of absence of all XSS. Third-party published scripts are present; no malicious-script assertion.

scannerRecent.ts:3,29 uses a shared recent-reference localStorage key. Mobile finance_repository.dart:39 scopes pending requests by user ID and stores payloads in preferences at :205,250; browser Finance uses sessionStorage. No actual student/cache data read and no logout residue test. vite.config.ts:72 enables local sourcemaps. No complete exported-document, local DB or browser/device forensic clearance.

## E16 — Published response headers / document

HTTPS GET final URL https://www.sai-academic.com/ returned 200. Observed headers absent: Content-Security-Policy, Strict-Transport-Security, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy. HTML CSP-meta check false. No framing attack, TLS downgrade or exploitation. HTTP headers have no repository line number; this is a dated endpoint observation.

## E17 — Storage and file handling

SELECT storage.buckets returned one bucket lesson-media: public=false, file_size_limit=104857600; MIME allowlist video/audio/image/PDF. Four storage.objects policies scope names to lessons and course authorization; UPDATE has USING and WITH CHECK. No public object downloads or uploads performed. Client code expects homework-files, absent from returned bucket list; functional parity unverified.

Client size/extension checks in mobile/lib/data/homework_files.dart:5,18,49,57 and src/portal/lib/learning.ts:294,306,325,391 were inspected; client MIME declarations are not server content validation or malware scanning.

## E18 — RLS / schema catalogs

SELECT-only pg_class/pg_namespace counts: 47 public ordinary tables, all RLS=true. No public views returned. has_schema_privilege anon/authenticated CREATE=false in public/private; private anon USAGE=false. pg_policies inspected, including true public CMS content SELECT; intentional public content is not automatically a vulnerability. Table privilege alone does not prove readable rows.

## E19 — Branch authorization proof

Hosted branch_memberships policy old-row USING: super_admin OR own user_id + admin + active branch membership. New-row WITH CHECK: super_admin OR own user_id + admin, with no new-branch constraint. Effective authenticated UPDATE grants on branch_id, user_id, is_active. Noninternal trigger inventory: AFTER management audit only; no blocking trigger. private.sai_security_branch_member trusts the updated active membership. Local historical policy at 003_staff_management_policies.sql:118-124 matches this structure. Static proof subject to existing branch/FK/uniqueness prerequisites; no production mutation.

## E20 — Audit privilege proof

Hosted audit_logs_insert_self: WITH CHECK actor_user_id=auth.uid(). No guard trigger. Table INSERT privilege=false but effective INSERT columns action, actor_user_id, entity_id, entity_type, metadata are granted. This distinction was explicitly checked to avoid a false clearance. Dashboard reads generic audit records; some export histories are labeled unverified. No fabricated event inserted.

## E21 — Student identity mapping proof

Hosted authenticated students.user_id INSERT and UPDATE grants; scoped admin INSERT/UPDATE policies. Existing triggers: management audit and class/branch validation; no account-binding guard. Original schema user_id is unique FK, so this finding does not claim duplicate/nonexistent identities are allowed. Missing checks concern confirmed/usable account and authorized replacement. Local verified-onboarding proposal is not proof of deployment. No student/account data queried.

## E22 — Role / parent / student predicates

No authenticated table/column direct writes observed for user_roles or parent_student_links. Parent reads require own identity and verified_at. Student helper permits super_admin, branch admin, assigned teacher, own student, verified parent. No real-role matrix was run; F02 weakens any branch-trusting predicates. No client user_metadata-role authorization found in inspected active auth source.

## E23 — Finance metadata

fee_assignments/fee_payments SELECT policies delegate student/branch predicates; fee_refunds read is accountant-scoped. Selected pay/void/waive routines contain staff checks, auth.uid reference and row locks. These substring/definition checks do not prove all finance invariants. Refund path needs full semantic and controlled-role/idempotency verification. No financial records read or money-mutating calls executed.

## E24 — Hosted deployment gap

SELECT pg_tables returned no public exam/result tables. Latest hosted migration names/versions include 20261110173506 (sai_unified_module_realtime), 20261110173339, 20261110172940, 031 and 030. Later local migrations are not established deployed.

Targeted pg_proc checks found no public role-assignment routine in role-name surface; public.sai_assert_mutations_enabled() lookup null. private.protected_admission_status_events lookup null: identifier-specific only, not an exhaustive alternative-store search. Local exam migration 20261117202825...:67-68 enables exam/result RLS in proposed source, not hosted state. No SQL applied.

## E25 — Definers / invokers / advisor

85 SECURITY DEFINER functions in public/private; all have configured search_path. No public definer with effective anon EXECUTE found; private anon USAGE denied. Some definers remain authenticated-executable and require authorization/body review; advisor alerts on intended definer APIs are not automatically exploits. public/private untrusted CREATE denied.

sai_library_issue and sai_library_return: proconfig=null, prosecdef=false (invoker); advisor warns mutable search path. Local declarations 018_library_and_communications.sql:95,108. No library RPC invocation.

## E26 — Auth / privileged-account checks

Read-only Supabase advisor reports auth_leaked_password_protection disabled. Source role-management-handler.ts:218,246,375 validates usable confirmed caller, super_admin and explicit guarded RPC inputs. Hosted source parity, MFA enrollment/aal2, recovery, last-usable-admin protection and actual account/session state were not established. No password/token/account details requested.

## E27 — Backup / recovery

supabase backups list with explicit authorized project ref: 8 COMPLETED physical backups November12-19; newest 2026-11-19T16:01:34.009Z; pitr_enabled=false; region ap-northeast-1. No restore or snapshot download; backup availability is not recovery proof. No agreed/tested RPO/RTO.

## E28 — Executed verification

node --test tests/main-integration.test.mjs: 4 pass, 0 fail. npm.cmd --prefix web test: 112 total, 111 pass, 1 fail, exit1. Failure “Main migration proposals remain separate from the Phase 2C baseline” at web/tests/phase2c-migration-review.test.cjs:28, migration files versus lock inventory; preserved demo relocation is visible in inventory. No assertions removed or failures suppressed. No SQL replay, Flutter suite, new build, authenticated browser/device or restore test.

## Method restrictions and output handling

All database SQL submitted was SELECT-only, targeted through the verified Production CLI link. No application records, passwords, real-user details, uploads, mutating RPCs, grants or migrations were requested. CLI displayed normal provider-managed login-role setup; provider access logs/connection infrastructure are outside client control. No Preview/third-backend connections.

One intentionally public publishable-key value escaped an attempted minified-code redactor in tool output. No private credential was disclosed; the value is not repeated in documentation. This limitation is recorded instead of claiming every tool output omitted all public configuration values. Corrected final initializer evidence redacted keys before any context output.

Final E02 supplement: the initial LocalAppData directory was under an unrelated user-profile Git work tree. Both private copies were relocated to the final ProgramData path shown in E02; destination Git checks before/after showed no Git work tree, hashes/ACLs reverified, initial files absent. No files were staged in either repository; old empty directories were retained.
