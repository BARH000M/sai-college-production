# Web and mobile next-build backlog

Date: 2026-11-16. Development baseline: `feature/v2-completion`. Preserve approved UI and all nine roles. This is an implementation specification and review backlog, not authorization to apply migrations, deploy functions, create users or change roles.

## Current repair outcome

The Preview project was verified through the read-only MCP. Deployed account functions return HTTP 500 because the service database role lacks required table grants; settings points to an absent table. Local diagnostics and save gating are repaired, but hosted operations remain backend-blocked. The confirmed test account correctly waits for a role and student link. See `PREVIEW_BLOCKERS_DIAGNOSIS.md` for exact evidence, endpoints, SQL proposals and recovery action.

The five feature families have source/Preview crosswalks against the existing 32-category / 147-entry specification in `HR_PROFILES_DOCUMENTS_BARCODE_GAP_ANALYSIS.md`. This task did not build substitute HR, document, module-installation or card systems.

## Priority 0 — restore Preview administration safely

| Task | Dependencies / implementation | Acceptance evidence |
| --- | --- | --- |
| P0.1 Review and implement explicit service ACL migration | Review deployed `manage-roles`, `provision-learning-account`, `link-student-account` source; compare every table operation. Start from the exact scoped grant proposal in the diagnosis. Use migration tooling in a separately authorized phase; no blanket grants or browser-role widening. | Disposable DB ACL tests; Super Admin list/summary/overview success; missing/expired session 401, unauthorized role 403; authenticated Preview evidence after approved apply. |
| P0.2 Verify function environment and deployment parity | Check required environment variable presence without printing values; compare deployed source/version with repository. Check Auth invitation redirects/email configuration and optional Resend settings independently. | Safe response, status, timestamp, function version and audit evidence. No credentials in logs/UI. Successful email delivery must be observed rather than inferred from API acceptance. |
| P0.3 Make account mutation/audit outcomes atomic or recoverable | Existing role/provision handlers use multiple service calls; granting staff roles can add every active branch, and some audit writes are not checked. Review intended branch scope and partial-failure behavior before broader HR use. | Failure injection leaves no silent role/link/membership divergence; audit failures surface; explicitly authorized branches only. No automatic retry of account creation/role mutations. |
| P0.4 Recover specified existing student account | After P0.1/P0.2, Super Admin identifies legitimate student record and uses existing-account linking. No duplicate invitation or direct SQL role assignment. | Exactly one intended student link; `student` role; audit event; fresh role load; no unrelated records visible. Waiting screen remains for other unassigned accounts. |
| P0.5 Implement approved settings backend | Review the exact staged General-only table proposal. Complete audit/server validation/API exposure tests; restrict both client category lists to installed keys. Expand allowlists only with real consumers. | Super Admin permitted saves persist and reload; Admin permitted categories read-only; ordinary roles denied; unknown/sensitive keys denied; missing backend stays visibly unavailable on both clients. |

## Priority 1 — shared identity, capability and document foundations

| Task | React work | Flutter work | Secure backend / acceptance |
| --- | --- | --- | --- |
| P1.1 Capability parity and catalog truth | Reuse existing inventory, availability map and 147 reference entries. Correct QR/setting status evidence after review. | Add capability gating before generic proposed-table screens attempt unsupported operations; reuse existing page IDs. | A read-only capability contract reports supported version, tables/RPCs/buckets/provider readiness. Enabling a module must never grant role access. Missing capabilities show an incomplete state. |
| P1.2 Extended own-contact editor | Reuse `Profile`/`profile.ts`; preserve read-only Auth email until verified email-change workflow exists. | Implement parity for name/phone/locale using existing own-profile contract. | Own-row policies retained; privileged enrollment/role/employment fields cannot be written through contact updates. Test multi-role and unknown-role cases. |
| P1.3 Document registry/private storage | Build upload/list/download/remove UI within approved layouts; reuse lesson validation/printing patterns. | Add shared document picker, upload progress, retry state and authorized download UI. | Separate private bucket and typed owner associations; MIME/signature/size checks, quarantine, staged finalization, short-lived signed links, retention and deletion audit. Cross-owner/branch/child denial tests. No public upload bucket or lesson-policy widening. |
| P1.4 Profile photos | Add bounded avatar upload/replace/remove. | Replace placeholder with authorized thumbnail and upload UI. | Reuse P1.3 storage mechanics with avatar-specific access/transform rules; no public original image or executable content. |
| P1.5 Student/parent profiles and history | Reuse existing student record, verified-link management and dashboards. Add history/CV tabs only after schema. | Add authorized profile detail and read parity; preserve verified-child queries. | Separate current enrollment, append-only history and CV sections. Parent cannot self-verify. Audit changes; no accidental exposure of salary/private staff notes. |

## Priority 2 — HR, IDs and secure QR

| Task | Reuse and missing work | Acceptance |
| --- | --- | --- |
| P2.1 Employee registry and teacher directory | Join employee/employment records to existing Auth profiles and memberships. Reuse teacher workload/account panels; do not duplicate teacher identities. Add branch-scoped directory/detail to web and mobile. | Staff own view versus HR projection; Admin limited to explicitly authorized branches; accountant has no automatic confidential-HR access; directory pagination and disabled accounts behave correctly. |
| P2.2 Contracts, qualifications and staff documents | Use P1.3 private documents and effective-dated employment data. Add verification/replacement and expiration workflow. | Authorized reviewer only; confidential contract fields separated; read/download/delete audited; expired/replaced documents identifiable. |
| P2.3 Leave and employee attendance | New employee-scoped tables and state transitions; reuse date/validation components, never student attendance rows. | Asia/Aden date boundaries; no self-approval; concurrent balance/approval tests; authorized corrections and immutable audit evidence. |
| P2.4 Payroll | Separate payroll periods/components/payments/payslips from student fee ledger. Decide Super Admin/Admin/Accountant duties explicitly. | Exact decimal rounding; locked finalized periods; employee sees only own permitted payslip; audit/idempotency and confidential-salary denial tests. |
| P2.5 Teacher evaluations | Versioned rubric and evaluator assignments; use real teacher IDs. | Draft/submitted/finalized transitions, conflict handling, confidentiality, authorized employee view and audit. Workload counts must not masquerade as evaluations. |
| P2.6 Student/employee ID cards | Reuse QR renderer, branded letterhead/fonts and mobile printing primitives. Add card registry, opaque token, expiry/reissue/revoke and approved card layout. | No sensitive encoded data; minimal authenticated verification output; revoked/expired/unknown cards denied; documented print alignment and issuance audit. |
| P2.7 Secure QR attendance | Replace fixture-only attendance with server-issued challenges and authenticated redemption, using real attendance session/class permissions. Reuse scanner camera handling and existing attendance APIs. | Cryptographic challenge, short expiry, revocation, replay prevention, atomic idempotency, class/branch/caller validation. Test screenshot/replay attempts and unrelated class denial. Keep regular attendance management working. |

## Priority 3 — module configuration and integrations

1. Define a versioned module manifest with code-supported IDs, dependencies, minimum schema version and provider requirements. Do not treat npm/Flutter packages as user-installable plugins.
2. Add Super-Admin-only, audited enable/disable operations only after P1.1 readiness and manifest support. A module preference must not alter roles, RLS or execute downloaded code.
3. Show configured versus connected versus successfully tested provider states. Expose no secret editor or secret value in the application.
4. Complete admission attachments, certificate issuance/verification, certificate/transfer templates and general download-center lifecycle using the same document infrastructure. Do not create another file service.
5. Add barcode support only after the device format/printing requirements are agreed; QR rendering alone does not establish barcode scanning compatibility.

## Local implementation files changed this task

| File | Reason |
| --- | --- |
| `src/portal/lib/functionErrors.ts` | Safe HTTP-status diagnostics and allowlisted permission classification. |
| `src/portal/lib/roles.ts` | Preserve useful invocation failure context for directory, summary and role actions. |
| `src/portal/lib/learningAccounts.ts` | Same diagnostics for student/teacher provisioning actions. |
| `src/portal/lib/studentAccounts.ts` | Same diagnostics for link/unlink/list integration. |
| `src/portal/lib/systemSettings.ts` | Explicit absent-backend error instead of raw missing-table message. |
| `src/portal/pages/SystemSettings.tsx` | Disable unsupported editing after failure, prevent stale-category saves, provide reload and conditional availability copy. |
| `web/tests/learning-accounts.test.cjs` | Extend existing test module loader for the shared error helper. |
| `web/tests/preview-blockers.test.cjs` | Focused error redaction/status/no-retry and settings failure/gating regressions. |
| `docs/reports/PREVIEW_BLOCKERS_DIAGNOSIS.md` | Hosted evidence, exact endpoints, backend proposals and account recovery instructions. |
| `docs/reports/HR_PROFILES_DOCUMENTS_BARCODE_GAP_ANALYSIS.md` | Feature-by-feature web/mobile/backend evidence and secure missing contracts. |
| `docs/reports/WEB_MOBILE_NEXT_BUILD_BACKLOG.md` | This ordered implementation plan and validation record. |

No Flutter file, package manifest, lockfile, MCP configuration or migration was changed by this task. Previous uncommitted Flutter and Phase 1 files remain preserved.

## Validation record

| Check | Exact result |
| --- | --- |
| `npm --prefix web test` | PASS, exit 0; **64 passed, 0 failed, 0 skipped**, including four new blocker tests. |
| `npm run type-check` | PASS, `TYPE_CHECK_EXIT=0`, no diagnostics. |
| `npm run lint` | PASS, `LINT_EXIT=0`, no diagnostics. |
| `npm run build` | PASS, `BUILD_EXIT=0`, 261 modules transformed. Non-fatal >500 kB bundle warning and plugin timing notices. |
| `node --experimental-strip-types --test tests/*.test.mjs` | PASS, `ROOT_TEST_EXIT=0`; **23 passed, 0 failed, 0 skipped**. Includes inventory 32/147 and prior nine-role regressions. |
| `git diff --check` | PASS, exit 0. Git reported existing line-ending conversion notices only. |
| Flutter analyze/test | Not rerun: Flutter source was unchanged in this task. Prior Phase 1 evidence: analyze PASS, 48 tests PASS. This is historical evidence, not a current authenticated mobile test. |
| Hosted Preview | Read-only endpoint/schema/ACL/migration/log/account evidence only. No authenticated browser replay, function invocation, writes or security mutation tests. |

All local automated checks are static/unit/source-contract evidence. They do not show that any hosted account-management operation now succeeds. Required follow-up must record environment, identity/roles, timestamp, expected and actual result, HTTP status and audit evidence, with no JWT/secret/password exposure. Backend proposals require separate approval and disposable database validation before application.

## Remaining blockers

- Missing service table ACLs still block hosted role administration and learning/teacher account management.
- No settings storage contract exists in Preview or checked-in migrations.
- `link-student-account` deployed status/source and function secrets cannot be inspected with the available read-only MCP tools.
- Five requested feature families remain partial or missing as detailed in the feature matrix. No fake feature activation was introduced.
- Sandbox process initialization failed; approved escalated local commands were used. Hosted restrictions were preserved.

Stop point: local repairs, tests and documentation only. No commit, push, deployment or hosted data modification was performed.
