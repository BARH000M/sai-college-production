# SEC-01 Production Security Audit

Date: 2026-11-19 (Asia/Aden). Workspace: D:\SAI-College-Production. Repository: BARH000M/sai-college-production, main. Authorized Supabase: aeryusbrulqdxjdynwfh. Website: sai-academic.com.

## Executive summary

**Production release is NOT APPROVED.** Retired remote Preview configuration was safely quarantined. Local web, Flutter, CLI and MCP configuration identifies the authorized project. However, the published website loads a Supabase client configured for a third project, reprjetryjveowspusxd. No connection to that backend was made.

Production catalog inspection confirms a branch-membership reassignment flaw, client-forgeable generic audit entries and direct student-account binding without the reviewed verification guard. Local security proposals do not establish deployed protection. All 47 public ordinary tables have RLS, but RLS alone does not establish correct authorization.

This final report supersedes earlier blocked versions. All requested workstreams received independent static, artifact, public GET, catalog or advisory checks. Unavailable dynamic checks remain explicitly unresolved.

**60 defined control checks: PASS 32, FAIL 12, BLOCKED 3, UNVERIFIED 13. Confirmed findings: P0 0, P1 2, P2 8, P3 2.** These totals refer to the audit units in SECURITY-CHECKLIST.md, not an OWASP certification score. Findings are confirmed control weaknesses; no destructive exploit was executed.

## Confirmed findings

### SEC-01-F01 — Published website uses an unauthorized backend

- Component: Production website Supabase client. Severity: P1. Result: FAIL. Status: OPEN.
- Location: https://www.sai-academic.com/assets/supabase-DWFLzbPp.js:22, referenced by the main published bundle; E05.
- Redacted evidence: Client configuration contains https://reprjetryjveowspusxd.supabase.co rather than the authoritative project. Chunk SHA-256: 281b284605a83d1f727e24b859330d87400026dcfb159920bffe8f2a38895c89. Keys omitted.
- Impact: Published authentication/data paths can use a backend outside the authorized identity. Ownership, policies and data of that backend were not assessed. This is an active deployed configuration conflict, not historical Preview documentation.
- Remediation: Establish domain/deployment provenance and prepare a reviewed artifact targeting the authoritative project. Obtain implementation/deployment approval; do not modify or repoint the third project.
- Verification: Same-origin public GET, referenced chunk and initializer-context inspection. No requests to the third backend.

### SEC-01-F02 — Branch admins can reassign their membership to another branch

- Component: Production tenant authorization. Severity: P1. Result: FAIL. Status: OPEN.
- Location: supabase/migrations/003_staff_management_policies.sql:118-124; hosted branch_memberships_update_self_or_super_admin policy and effective column grants; E19.
- Redacted evidence: USING checks old-row active membership and own user_id/admin role. WITH CHECK requires own user_id/admin role but does not restrict the new branch_id. authenticated can UPDATE branch_id, user_id and is_active. Only an AFTER audit trigger was observed, with no tenant guard or mutation-hold trigger.
- Impact: A legitimate active branch admin can move their own membership to another existing branch, defeating policies that trust branch membership. Requires a target branch and nonconflicting row constraints. No live update attempted.
- Remediation: Review the existing local branch-protection proposal, remove direct mutable tenant-key grants, and require tightly authorized membership operations. Validate isolated two-branch admin/super-admin cases before approved deployment.
- Verification: SELECT-only policies, grants, trigger inventory and helper definitions; semantic authorization analysis.

### SEC-01-F03 — Generic audit events are client-forgeable

- Component: Production generic audit history. Severity: P2. Result: FAIL. Status: OPEN.
- Location: supabase/migrations/002_security_policies.sql:350-352; src/portal/lib/dashboard.ts:41; hosted audit_logs grants/policy; E20.
- Redacted evidence: Column INSERT grants cover action, actor_user_id, entity_id, entity_type and metadata. Policy checks only actor_user_id=auth.uid(); no guard trigger. Table-level INSERT=false does not cancel column INSERT grants.
- Impact: Any authenticated caller can fabricate event contents attributed to themselves. Forgery of another actor identity is not established. Some exports label history unverified, but that does not create trusted audit records.
- Remediation: Restrict event production to trusted server/trigger paths, and keep historical client-authored events explicitly unverified. Do not backfill unsupported trust.
- Verification: SELECT-only effective column privileges, policies and trigger inventory; no INSERT.

### SEC-01-F04 — Direct student binding bypasses verified onboarding

- Component: Production student/Auth identity mapping. Severity: P2. Result: FAIL. Status: OPEN.
- Location: supabase/migrations/003_staff_management_policies.sql:103; 001_initial_schema.sql:66; proposed 20261117202754_production_verified_onboarding.sql:3; hosted grants/triggers; E21.
- Redacted evidence: authenticated can INSERT/UPDATE students.user_id under scoped-admin policies. Observed validation checks class/branch, not identity binding. Existing FK/unique constraints require a valid, unique Auth ID but do not require confirmed/usable-account verification or approved replacement.
- Impact: Authorized branch staff can attach or replace a mapping with an otherwise unlinked existing Auth identity outside the reviewed verification workflow. This does not establish cross-branch direct student updates.
- Remediation: Make the identity column immutable to direct clients and require verified binding/replacement operations, account checks and trusted audit.
- Verification: Read-only grants/policies and complete noninternal trigger inventory for students; no account queries or binding tests.

### SEC-01-F05 — Flutter persists auth sessions in unencrypted preferences

- Component: Mobile session storage. Severity: P2. Result: FAIL. Status: OPEN.
- Location: mobile/lib/main.dart:39-40; E14.
- Redacted evidence: Explicit SharedPreferencesLocalStorage with sai-production-auth session key; no secure session adapter.
- Impact: Access/refresh session material lacks application-layer encryption at rest. Extraction requires app-storage access, a compromised device or an applicable debugging/backup path. Backup exclusion does not encrypt live storage.
- Remediation: Introduce an OS-backed secure-session adapter with tested session migration, logout, refresh and Android/iOS recovery.
- Verification: Static initializer/storage-choice review; no device extraction or token values read.

### SEC-01-F06 — No observed CSP or anti-framing policy

- Component: Published web document. Severity: P2. Result: FAIL. Status: OPEN.
- Location: HTTPS response for https://www.sai-academic.com/ (no repository line); E16.
- Redacted evidence: No Content-Security-Policy or X-Frame-Options header. HTML document had no CSP meta.
- Impact: No observed policy-based script-injection mitigation or framing restriction. Successful XSS/clickjacking was not tested. Third-party scripts and JS-readable sessions increase consequences of a future script compromise.
- Remediation: Design and compatibility-test an explicit CSP with frame-ancestors, then enforce through approved hosting configuration.
- Verification: Non-invasive HTTPS GET headers and HTML inspection.

### SEC-01-F07 — HSTS absent from observed production response

- Component: Published HTTPS policy. Severity: P2. Result: FAIL. Status: OPEN.
- Location: HTTPS document response, no repository line; E16.
- Redacted evidence: Strict-Transport-Security absent.
- Impact: This response does not instruct browsers to require future HTTPS access. Downgrade exposure depends on preload/browser/network conditions, which were not tested.
- Remediation: Verify domain/subdomain HTTPS behavior, then configure reviewed HSTS. Evaluate preload separately.
- Verification: HTTPS GET header inspection, not a downgrade attack.

### SEC-01-F08 — Main has no observed branch protection or rulesets

- Component: GitHub change control. Severity: P2. Result: FAIL. Status: OPEN.
- Location: GitHub /branches/main/protection and /rulesets API metadata, no source line; E09.
- Redacted evidence: Protection endpoint returns 404 “Branch not protected”; rulesets list is empty.
- Impact: Write-authorized users can bypass review/status gates through direct branch updates. No push was attempted.
- Remediation: Require reviewed pull requests/checks; review bypass actors and recovery. Settings changes require approval.
- Verification: Read-only GitHub APIs.

### SEC-01-F09 — Compromised-password protection disabled

- Component: Production Supabase Auth. Severity: P2. Result: FAIL. Status: OPEN.
- Location: Hosted security advisor auth_leaked_password_protection; no source line; E26.
- Redacted evidence: “Leaked Password Protection Disabled.”
- Impact: This feature does not reject known compromised passwords. No weak existing password or absence of every other defense was demonstrated.
- Remediation: Enable after approved Auth-impact review; verify controlled-account flows and complementary MFA/rate limits.
- Verification: Read-only security advisor; no signups or password changes.

### SEC-01-F10 — Release keystore has broad inherited Windows access

- Component: Signing material custody. Severity: P2. Result: FAIL. Status: OPEN.
- Location: mobile/android/app/yemen-sai-release.jks, binary (no line); E13.
- Redacted evidence: BUILTIN Users ReadAndExecute; Authenticated Users Modify; additional inherited principals.
- Impact: Other local principals may copy or alter the keystore. Recovering the signing private key still depends on unknown password protection; actual key compromise is not established.
- Remediation: Restrict effective access and establish private managed/offline custody, separate credentials and recovery proof.
- Verification: Get-Acl only; no cracking, key export, password reading or guessing.

### SEC-01-F11 — Actions use mutable version tags

- Component: CI supply chain. Severity: P3. Result: FAIL. Status: OPEN.
- Location: .github/workflows/database-ci.yml:15,18; web-ci.yml:33-34; mobile-ci.yml:37,40; E10.
- Redacted evidence: checkout@v4, setup-node@v4, setup-python@v5 and flutter-action@v2 rather than reviewed full commit hashes.
- Impact: Upstream action changes can alter CI execution without repository-source changes. Read-only workflow tokens limit but do not eliminate risk.
- Remediation: Pin reviewed action commits and automate reviewed updates.
- Verification: Static workflow inspection.

### SEC-01-F12 — Library invoker RPCs lack fixed search paths

- Component: Library database RPCs. Severity: P3. Result: FAIL. Status: OPEN.
- Location: supabase/migrations/018_library_and_communications.sql:95,108; hosted pg_proc; E25.
- Redacted evidence: sai_library_issue and sai_library_return have proconfig=null and SECURITY INVOKER.
- Impact: Session search-path variation can change unqualified-name resolution/reliability. Privilege escalation is not demonstrated: these are invoker functions and untrusted public-schema CREATE is denied.
- Remediation: Set explicit trusted/empty search paths and qualify references with isolated compatibility tests.
- Verification: Read-only catalog plus security advisor.

## APK assessment

Binary artifacts have no source lines; ZIP entry / manifest locations are used. Six paths, five unique hashes were found. Existing Android SDK 36.0.0 aapt and apksigner were used.

| APK under mobile/ | SHA-256 | Result |
|---|---|---|
| APK-OUTPUT/ap00p-release-signed.apk | becb25ace0564b00d8458336dc3ce2e378f0490d0d3e55dd992477736ea468a2 | Signature verifies; not debuggable |
| APK-OUTPUT/app-re000lease.apk | a316afb844393f3133ae8cc4e7711deb481caab8bd765d0ce5ec0673a45f654f | Signature verification exit 1; intermediate |
| APK-OUTPUT/app-releas000e-aligned.apk | a316afb844393f3133ae8cc4e7711deb481caab8bd765d0ce5ec0673a45f654f | Same intermediate bytes |
| APK-OUTPUT/app000-release-debug.apk | 6e56e46206802ed2af86e2714fea2170dfa6c52470e7b04b8ea7f94aaf043c20 | Debug-signed, debuggable, kernel_blob.bin |
| build/app/outputs/flutter-apk/app-debug.apk | 594b79f298dafac78c122b826cefa846a707ab8e6376b0d779d575391ffa712d | Debug-signed; duplicate path in outputs/apk/debug |

Package com.saicollege.mobile, 1.2.1+4, minSdk 24/targetSdk 36. Signed candidate certificate SHA-256: 07bdabb618c143be9a26fababadcdd0c2eed8825741a6e618a1cd3f66ab1349a. Debug certificate: 4d0054685e9f9c1c576a9b6e7060ee7ea0af913f8d16c48bc92f8ea087d8a69d. Public certificate fingerprints are not credentials. Ownership, store approval and distributed/installed artifact identity are unverified.

Signed candidate requests network permissions plus an internal signature permission. Launcher/auth activity is intentionally exported; providers and WebViewActivity are not exported. AndroidX profiler receiver is DUMP-permission protected. No observed unnecessary dangerous permissions. Custom auth scheme needs callback assurance tests.

Detected APK backend hosts identify authorized Production. No confirmed private credential signature was found. Debug kernel PEM delimiter strings initially appeared suspicious; strict checks found zero base64-valid private PEM blocks. AOT strings are not exhaustively recovered; absence of encoded secrets is unverified. Debug/unsigned intermediates are not approved distribution artifacts, but their existence alone is not counted as a production vulnerability.

## Supabase, web and validation scope

Hosted: 47/47 public ordinary tables have RLS, untrusted schema CREATE is denied, no public views returned. All 85 inspected definers have configured search paths; no public definer was anonymously executable in queried catalogs. Authenticated definer advisor warnings require individual authorization review; they are not automatically vulnerabilities.

Student/parent predicates require appropriate ownership/verified links; finance predicates and selected RPC guards were reviewed. Real-role isolation and refund/idempotency correctness remain unverified. F02 weakens branch-based predicates.

One hosted private bucket, lesson-media, has a 100 MiB limit and MIME allowlist with lesson/course-scoped policies. Client homework-files bucket was not listed. No upload/download test was performed.

Production has no exam/result tables. Targeted catalogs also did not find the public mutation-gate or a matching role-assignment RPC; the identifier-specific protected-admission-store check returned null. Later local proposals are not proof of hosted implementation; no migrations were applied.

Executed: identity integration tests 4/4 pass; web tests 111/112 pass. One failure at web/tests/phase2c-migration-review.test.cjs:28 (“migration files and lock inventory differ”) remains. The existing staged demo relocation was not changed. No SQL replay, Flutter suite, build or device tests were executed.

npm audit: zero known vulnerabilities in root/web lockfiles. OSV: no matches for 102 hosted Pub packages. These checks do not cover malware or undisclosed flaws.

Eight completed physical backups were listed, newest 2026-11-19T16:01:34.009Z. PITR=false. Restore success and agreed RPO/RTO remain unproven.

## Limitations and release gates

Workspace text/history signature scans excluded unreadable, binary and >5 MB material; exact counts are in E07. No unreachable/reflog scan or remote-ref fetch. Historical browser-cache binary/session residue remains unverified. No IPA, runtime iOS, device extraction, TLS interception, authenticated production account testing, malicious uploads, restore or destructive tests. Public JS inspection was bounded; initial relative-path errors were corrected for selected canonical chunks.

Only the authorized Preview quarantine and seven documentation files were changed. No vulnerability fixes, functionality changes, SQL/migrations, credential rotations, installs, Docker, commits or pushes. Submitted production SQL was SELECT-only; normal provider logs/connection setup are outside client control.

Release gates: correct deployed identity, close tenant escape, address P2 privacy/session/signing/browser/repository/Auth weaknesses or explicitly accept documented residual risks, prove hosted contract parity, identify approved signed distribution artifact, clear inventory validation and complete controlled role/recovery verification.

Recommended next phase: **SEC-02 approved identity correction and authorization containment**, followed by the ordered plan in SECURITY-REMEDIATION-PLAN.md. STOP: no implementation is authorized by this report.

## References

Review principles: [OWASP MASVS](https://mas.owasp.org/MASVS/), [OWASP ASVS](https://asvs.owasp.org/), [OWASP API Security 2023](https://api-security.owasp.org/editions/2023/en/0x11-t10/). No certification claimed. Supabase and Supabase Postgres local skills were consulted; [Supabase changelog](https://supabase.com/changelog.md) checked. Evidence methods use [npm audit](https://docs.npmjs.com/cli/commands/npm-audit) and [OSV](https://google.github.io/osv.dev/api/).
