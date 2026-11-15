# Phase 2B backend repair approval package

Date: 2026-11-16. Workspace: `D:\SAI-College-Production-v2-completion`. Branch: `feature/v2-completion`.

## Status and scope

| Classification | Result |
| --- | --- |
| **FIXED LOCALLY** | Explicit Arabic HTTP 422 guidance; stricter settings validation and credential-pattern rejection; exact save acknowledgement; failed/null reads cannot become editable defaults; settings errors no longer echo arbitrary server messages. Phase 1/2A changes preserved. |
| **PREPARED FOR REVIEW** | Two forward-only SQL migration proposals, deterministic local artifact generator, SELECT-only metadata verification file, focused unit/source-contract tests, this package. |
| **BACKEND CHANGE REQUIRED** | Missing service-client column/table privileges; missing settings preference store and trusted audit. No hosted repair has been applied. |
| **VERIFIED** | Exact Preview identity; 36 applied migrations; absent settings relation; missing service grants; existing schema/RPC authorization permissions; local service clients keep caller JWTs separate; local automated results below. |
| **NOT YET TESTED** | SQL execution/replay, actual PostgREST upsert with column grants, authenticated nine-role settings enforcement, live provisioning success, deployed/local function source parity, email delivery, authenticated dashboard isolation. |

This phase performed **no database writes**, including no local database migration replay. No Docker, mutating endpoint invocation, hosted users/fixtures, role assignments, function deployment, Git commit/push/merge, or Production access occurred. Existing `.mcp.json`, `.codex/config.toml`, `auto-imports.d.ts`, Flutter dependency/plugin changes and prior repairs were retained.

Read the actual four existing reports and inspected their corresponding local changes before preparation. This package supersedes the broad table-level grant sketch and incomplete General-only settings sketch in the Phase 2A diagnosis; the older reports remain historical evidence.

## 1. Confirmed root causes and competing explanations

The first hosted call was `supabase-preview.get_project_url`; it returned exactly `https://mgibjusuglafbnlrkbep.supabase.co`. All hosted work used that read-only MCP. No API key/JWT/password/secret values were requested or printed.

| Candidate cause | Evidence and decision |
| --- | --- |
| Missing service table/column privileges | **Confirmed.** `has_table_privilege` and `has_column_privilege` return false for required operations. All columns of the 15 dependency tables lack service SELECT/INSERT/UPDATE. DELETE on role/membership tables is also absent. |
| Missing `public` schema USAGE | **Excluded for observed failure:** service USAGE is true. No redundant schema grant proposed for the service role. |
| Wrong client or forwarded caller JWT | **Not present in inspected local code.** Three functions construct `admin = createClient(url, serviceKey, { auth: { persistSession: false } })` without caller headers. `authClient.auth.getUser(token)` verifies the user separately. Linking alone uses a separate `callerClient` to invoke authorized RPCs. |
| Missing RPC EXECUTE | **Not the linking defect.** Authenticated has EXECUTE on the four existing admission link/verification RPCs. Service lacks EXECUTE intentionally; it must not replace caller authorization. No RPC EXECUTE grants proposed. |
| Incompatible or missing historical migration | **No history mismatch found:** the 36 local baseline names match Preview through `20261116013950_learning_scored_exercises`. Old migrations establish browser grants, private helpers and security invariants but omit the required service grants. Do not rewrite them. |
| Different deployed/local function versions | **Unresolved.** Phase 2A logs show manage-roles deployment suffix `_7`, provisioning `_6`. This MCP cannot retrieve deployed source or list function secrets. No equivalence is claimed. Compare before Phase 2C apply. |
| Missing service environment configuration | Not demonstrated by the observed failure: requests reached the `user_roles` SELECT. Presence/values of secrets were not inspected. Optional email configuration remains unverified. |
| Settings schema cache/exposure | **Absent relation, not a cache-only issue.** `to_regclass('public.sai_system_settings')` is null, no compatible settings relation exists, and no historical migration creates it. Cache refresh cannot replace a missing table. |

Current historical log-window aggregate: 14 manage-roles HTTP 500s, 16 provision-learning-account HTTP 500s, 83 Postgres messages `permission denied for table user_roles`. These are historical observations, not new endpoint invocations. Source-derived safe error body is `{ok:false,message:"permission denied for table user_roles"}`; logs did not capture response JSON.

## 2. Files and creation workflow

New executable migration **proposals**, not applied:

1. [`20261116013951_phase2b_service_permissions.sql`](../../supabase/migrations/20261116013951_phase2b_service_permissions.sql) — complete transaction containing only the scoped grants itemized below.
2. [`20261116013952_phase2b_system_settings.sql`](../../supabase/migrations/20261116013952_phase2b_system_settings.sql) — complete settings DDL, allowlist, validation, RLS and trusted audit transaction.

Their full reviewable contents are in those files; no hidden SQL application step is part of generation. `scripts/prepare-phase2b.cjs` reproduces both from the inspected client allowlist, with no network/database access. The installed CLI is v3.0.0; `migration new --help` establishes the supported command is local only.

SHA-256 approval fingerprints: service proposal `44776D2E057C4BC870819F28F3997A71658885D0D6485C05F14300A1F75C5EF9`; settings proposal `C4D76C9BE73720949352335DF694CB0CB2ED43355AA1AD31087CE41C6EAECB1D`. Recheck after any edit; approval should refer to the reviewed contents, not only filenames.

Commands actually executed: `supabase migration new phase2b_service_permissions` and `supabase migration new phase2b_system_settings`, using the installed binary. The CLI clock produced versions `20261115215352` and `20261115215356`, older than the checked-in baseline. The generator advanced these local files to the next two versions after `20261116013950`; no historical file was edited, and no migration-history repair or include-all operation was used. There are now 38 local files and still 36 applied Preview migrations.

Other new artifact: `supabase/tests/phase2b_read_only_verification.sql`, containing only SELECTs. It can inspect the proposed result without creating identities or rows. It does not prove RLS behavior.

## 3. Exact service-role privilege proposal

All recipients below are PostgreSQL **`service_role`**, not application users. Existing state for every listed column operation: **false**, established by read-only catalog checks. DELETE is false where listed. The existing service role has BYPASSRLS; this does not supply SQL object permissions. Browser-role policies and grants are unchanged.

| Exact table | Exact SELECT columns | Dependent function / need |
| --- | --- | --- |
| `public.user_roles` | `user_id,role` | All three services validate caller roles; directory, counts, teacher list and revocation checks. |
| `public.profiles` | `id,full_name,email` | Directory names, account linking, provisioning and teacher notification details. |
| `public.branches` | `id,name,is_active` | Staff role memberships and teacher branch display/notification. |
| `public.branch_memberships` | `user_id,branch_id,is_active` | Linking Admin branch scope; membership reconciliation. |
| `public.students` | `id,full_name,admission_no,class_id,user_id,status,branch_id` | Provision overview, verified existing-account linking, teacher workload and summary counts. |
| `public.parent_student_links` | `parent_user_id,student_id,verified_at` | Existing parent account overview and duplicate relationship detection. |
| `public.classes` | `id,name,branch_id,teacher_id,is_active` | Teacher overview/assignment and summary. |
| `public.academic_sessions` | `id` | Summary count only. |
| `public.learning_courses` | `id,class_id,teacher_id,title,is_active,branch_id` | Teacher workload/ownership and summary. |
| `public.learning_lessons` | `id,is_published,content_path,content_body,content_url,content_kind` | Summary completeness/published-content counts. |
| `public.learning_lesson_progress` | `lesson_id,status` | Summary progress counts. |
| `public.learning_homework` | `id,course_id` | Teacher workload assignment counts. |
| `public.learning_homework_submissions` | `id,homework_id,status` | Workload and grading summary counts. |
| `public.admissions_enquiries` | `id,status` | Pending admission summary count. |

SELECT risk: a compromised server service credential could read these projected columns without RLS. This is restricted to inspected server needs; no phone, birth date, full student directory projection, fee data or unrelated table reads are added. **Rollback for each SELECT row:** forward migration `REVOKE SELECT (<the exact listed columns>) ON <the exact table> FROM service_role`, after comparing current ACLs to the captured pre-apply state. No CASCADE.

| Exact table | Exact mutation grant | Why needed / risk / rollback |
| --- | --- | --- |
| `public.profiles` | INSERT and UPDATE `(id,full_name,email)` | Existing profile merge-upserts include the PK. Risk: privileged server can change those fields; no phone/locale or DELETE grant. Roll back both exact column grants. |
| `public.user_roles` | INSERT `(user_id,role,assigned_by)`; DELETE | Existing role grants/provisioning use `ignoreDuplicates:true` (DO NOTHING); revoke deletes rows. **No UPDATE is needed or proposed.** Risk: service credential can assign/revoke roles; caller checks must remain. Roll back INSERT columns and DELETE. |
| `public.branch_memberships` | INSERT and UPDATE `(user_id,branch_id,is_active)`; DELETE | Merge-upsert/reactivation/deactivation and staff revoke cleanup. PK columns are included in merge payloads. Risk: staff scope changes. Roll back those exact grants. |
| `public.classes` | UPDATE `(teacher_id)` | Teacher create/reassign/remove; no class identity/capacity/branch changes. Risk: course access changes. Roll back this column UPDATE. |
| `public.learning_courses` | UPDATE `(teacher_id)` | Course ownership follows class reassignment/removal. Risk: teacher content scope. Roll back this column UPDATE. |
| `public.audit_logs` | INSERT `(actor_user_id,action,entity_type,entity_id,metadata)` | Existing service audit messages. No SELECT/UPDATE/DELETE. Roll back INSERT columns. These existing events remain informational; they are not the new trusted settings audit. |

No blanket grants, PUBLIC/anon elevation, RLS changes, function EXECUTE grants, user-role row assignments, or new definer authorization shortcuts occur in this migration. It supports existing guarded server actions without changing their caller checks. It also deliberately grants **no student-link or parent-verification writes**; those still use caller-authorized RPCs.

Remaining service-design risks are not hidden: role grants currently add staff to all active branches; some multi-step teacher/course/audit calls ignore individual errors or are not atomic. This package does not redeploy or refactor those flows. Phase 2C must not claim complete mutation safety from ACL repair alone; role/provision mutations need separately scoped verification and follow-up fixes if those risks are unacceptable.

## 4. Complete settings preference contract

No existing compatible store exists. The proposal covers the existing **16 categories / 43 keys**, generated from `settingsSections`; the embedded definition JSON in the migration is the exact category/key/type/options/sensitivity allowlist. Unknown keys, categories and credential-field names cannot be inserted.

- Identity: `(category,setting_key)` PK, immutable on update. This matches both clients' existing upsert conflict target.
- Scope: explicit `scope='global'` CHECK. The existing UI has no branch selector and all these values are global preferences. No branch override or implicit inheritance is introduced. Future branch settings require a new reviewed contract; branch role memberships never imply settings writes.
- Values: bounded `value_text` plus server-derived `value_type` (`text`, `boolean`, `number`, `email`, `select`). Exact enum options and sensitivity are embedded in the private definition function. Trigger trims values and rejects invalid booleans/enums, non-integer/empty/out-of-range numbers (0–3650), malformed nonempty emails, non-HTTPS/credential-bearing website URLs and recognizable credential patterns.
- Ownership/stamping: `updated_at` and `updated_by` are NOT NULL and assigned by the trigger from clock/current authenticated user. Column grants prevent client spoofing. No credential values are requested by the schema/UI; no password, payment secret or API/service-key field exists. Pattern rejection is defense in depth, not a universal secret detector for arbitrary prose.
- Defaults: no settings rows are seeded. Unconfigured values remain absent, never an automatic permission, payment configuration, provider activation or plugin installation. Client boolean placeholders are UI choices, not evidence of persisted server defaults. A successful empty load permits explicit configuration; absent/unreadable backend does not.
- All writes require explicit database-assigned Super Admin, including non-sensitive global preferences. Admin may read only non-sensitive categories; `backups`, `extensions`, `verification`, `updates` are Super-Admin-only reads. All seven ordinary roles are denied. Multi-role accounts need explicit `super_admin` to write or read sensitive settings.
- There is no settings DELETE/TRUNCATE grant or delete policy. Clear optional text explicitly if appropriate; policy/history survives. Settings remain non-executable preferences: no dynamic SQL, downloaded plugins, role changes, deployments, payments, SMS or backup operations are triggered.
- Both clients retain table/column compatibility. Flutter is unchanged. React keeps its existing load-success gate and Super Admin save check. Until the backend read succeeds, save controls remain unavailable. A null protocol result is now an error rather than an empty/default configuration.

### Settings grants, policies and audit review

| Recipient/object/operation | Existing state | Need / risk / rollback |
| --- | --- | --- |
| authenticated EXECUTE `private.sai_setting_definition(text,text)` | New object | Immutable metadata lookup only, no data access/elevation. Required by CHECK/trigger/read policy. Revoke after disabling settings writes. |
| authenticated SELECT `public.sai_system_settings` | New object | RLS exposes only assigned Admin permitted categories or Super Admin; ordinary/anon denied. Revoke to disable reads. |
| authenticated INSERT/UPDATE `(category,setting_key,value_text)` on settings | New object | Required by existing PostgREST merge-upsert payload; RLS Super Admin only and immutable identity trigger. Revoke to disable writes while retaining data/history. |
| authenticated SELECT `private.sai_system_settings_audit` | New object | RLS Super Admin only; private schema stays unexposed to REST. Supports authorized DBA/audit inspection; no new audit UI or RPC. Revoke to suspend audit reads. |
| new `sai_settings_audit_writer` USAGE on private/auth, EXECUTE `auth.uid()`, INSERT trusted audit | New NOLOGIN, NOSUPERUSER, NOINHERIT, NOBYPASSRLS role | Dedicated trigger owner can append only; cannot read/mutate settings, roles or other application tables. INSERT policy requires actor=auth.uid(). Revoke only after disabling settings writes, otherwise audit failure intentionally aborts saves. |
| temporary SET membership for migration executor; temporary CREATE on private for audit writer | New, removed before commit | Needed for ownership transfer following the repository's trusted admission-event pattern. Membership and CREATE are revoked in the same transaction. No persistent login or application role added. |

Two new invoker functions handle immutable definition lookup and validation. The sole new SECURITY DEFINER function is a **private, fixed-search-path, trigger-only audit writer**, not an authorization bypass. It validates exact table/schema/timing/row context, has no dynamic SQL, cannot be called as an ordinary function, and has EXECUTE revoked from PUBLIC/anon/authenticated/service. Its owner can only INSERT audit events; RLS remains enabled on audit. Audit failure aborts the settings transaction. The role cannot bypass RLS or create objects after ownership transfer.

Audit records have UUID, category/key, old/new non-secret preference value, responsible authenticated user and timestamp, indexed by category/key/time. No trusted backfill is fabricated. Inserts and actual value changes are recorded; no-op merges update stamps without adding a value-change event. There are no client audit INSERT/UPDATE/DELETE grants. Settings read/write restrictions use existing `private.sai_security_has_role(public.app_role)`; live metadata confirms authenticated EXECUTE and private schema USAGE already exist.

## 5. Local application corrections and tests

Phase 2B changed only `functionErrors.ts` (explicit Arabic 422), `systemSettings.ts` (validation/exact acknowledgement/safe errors/null rejection), the prior blocker tests, and new preparation/test/report artifacts. Existing authorized role operations remain in `roles.ts`, `learningAccounts.ts` and `studentAccounts.ts`; no client-side role writes or secret key usage was introduced. 401/403/404/422/500 and malformed/HTML response bodies are covered; arbitrary response contents are not printed.

No Flutter source changes: the existing missing-backend error branch already hides editing. Prior nine-role settings fix and 512 role-combination tests are preserved. Unassigned-user waiting behavior and dashboard/navigation gates were not changed.

New `web/tests/phase2b-backend-package.test.cjs` checks the exact proposed operation surface, client/SQL allowlist parity, policy/audit restrictions, safe client validation, exact acknowledgement, null loads, JWT separation and no service secrets in web/mobile source. These SQL-policy checks are **source assertions**, not Postgres execution. `supabase/tests/phase2b_read_only_verification.sql` is a prepared inspection artifact, not a mutation test.

### Actual validation results

| Command | Result |
| --- | --- |
| `npm --prefix web test` | PASS: 69 tests, 0 failures/skips; exit 0. |
| `npm run type-check` | PASS, `TYPE_CHECK_EXIT=0`, no diagnostics. |
| `npm run lint` | PASS, `LINT_EXIT=0`, no diagnostics. |
| `npm run build` | PASS, `BUILD_EXIT=0`, 261 modules, 8.97 seconds. Non-fatal bundle-size/plugin-timing warnings. |
| `node --experimental-strip-types --test tests/*.test.mjs` | PASS, `ROOT_TEST_EXIT=0`, 23 tests passed, 0 failed/skipped. Includes nine-role/route and 32/147 inventory checks. |
| `git diff --check` | PASS, `DIFF_CHECK_EXIT=0`; existing line-ending notices only. |
| Flutter analyze/test | Not rerun; no Flutter source changes. Previous results are historical, not new Phase 2B evidence. |
| Migration replay / authenticated RLS tests | NOT RUN: database writes are prohibited in this phase; no Docker or database fixtures used. |
| Hosted mutation / provisioning / role assignment | NOT RUN and not authorized. |

Final SHA-256 comparisons also confirmed all five protected files unchanged: `.mcp.json`, `.codex/config.toml`, `auto-imports.d.ts`, `mobile/pubspec.lock`, and the generated Android plugin registrant. The current branch remains `feature/v2-completion`.

## 6. Expected Preview behavior after an approved implementation

After source/version parity and SQL execution checks pass, applying the service migration should allow caller-role checks, directory/list/summary and learning/teacher overviews to get past the confirmed table-permission failure. Unauthorized callers still get 401/403. Other configuration/deployment/multi-step errors may still fail; this is not a promise of successful email delivery or account creation.

Applying settings should make the existing table reads possible for authorized Admin/Super Admin. Initially there are no configured rows. Super Admin can explicitly save valid values and reload persisted data; Admin sees only non-sensitive preferences and no edit actions. Ordinary/unassigned roles remain denied. Trusted audit records should appear atomically. Neither preference storage nor a saved “enabled” string activates an integration or changes permissions.

The local web source must separately be built/published to display the Phase 2A/2B diagnostic improvements on a hosted website. That publication is outside this package; no app or function deployment is required merely to apply SQL compatible with the existing clients.

## 7. Exact separate approvals before Phase 2C

1. **Authorize a disposable, non-Production PostgreSQL validation environment and database writes limited to replay/behavior tests.** Phase 2B has not established SQL execution correctness. Use the repository's existing non-Docker PostgreSQL approach only after this approval; never target another existing project or account. Validate 36 baseline migrations plus the two proposals, role/column ACLs, trigger ownership, RLS and PostgREST conflict semantics. No such command was run here.
2. **Authorize read-only deployed-source/configuration-presence inspection through an appropriately scoped Preview tool**, since the current MCP cannot retrieve deployed artifacts or secret presence. Do not print values. If unavailable, explicitly accept that uncertainty or defer apply; do not assume parity.
3. **Approve the two exact migration files for Preview only** after reviewing the execution results and fresh ACL/migration metadata. Installed CLI help confirms these future commands, shown only and **not executed**:

```powershell
$phase2Cli = 'C:/Users/STR/AppData/Local/npm-cache/_npx/aa8e5c70f9d8d161/node_modules/@supabase/cli-windows-x64/bin/supabase.exe'
& $phase2Cli db push --remote=mgibjusuglafbnlrkbep --dry-run --skip-vault
# Require the dry-run to list exactly the two proposal files, in order.
# Separate explicit approval is required before the following apply command:
& $phase2Cli db push --remote=mgibjusuglafbnlrkbep --skip-vault
```

Do not use implicit linked targets, `--include-all`, seed/role imports, password arguments, debug dumps or automatic confirmation. Credentials must remain in the approved secure authentication channel. Fresh endpoint verification must match the Preview URL immediately before any approved hosted operation.

4. **Authorize bounded authenticated verification actions** separately: settings save/reload/denial tests and any role/provisioning mutations must specify existing permitted identities, exact actions/data and recovery. Read-only list/overview tests do not authorize account creation or role assignment. Existing test-account linking remains a Super Admin application action requiring its own authorization; no SQL role assignment is proposed.
5. No function redeployment, new Super Admin/user creation, frontend publication, Git commit/push or Production action is included in these approvals. If a deployed source defect is found, prepare and approve that specific change separately.

## 8. Rollback and recovery

Each proposal is transactional: an installation error should roll back all its statements. Do not repair migration history manually or rerun a partially copied SQL subset. First inspect the actual transaction/history result.

Before apply, capture the exact existing ACLs and object ownership via SELECT-only inspection. Service rollback is a new reviewed forward migration revoking only the column/DELETE grants listed above that this package actually added. Preserve any intervening grants; do not issue blanket REVOKE ALL. Revoking these grants restores the previous service failure mode and does not undo account/data changes performed after apply. Reconcile any separately approved mutations using authorized app operations and audit evidence.

Settings rollback should first revoke authenticated INSERT/UPDATE column grants, keeping settings and trusted audit rows intact. Optionally suspend reads by revoking SELECT. Retain validation/audit triggers while writes are possible. Do not DROP tables, CASCADE, delete audit history or drop the audit-writer role while it owns the trigger function. A future removal migration must archive required data, revoke all execution/membership/ownership dependencies deliberately and receive separate approval. Invalid preferences can be corrected by an authorized Super Admin, preserving audit history; there is no unaudited deletion shortcut.

## 9. Remaining blockers and Phase 2C checklist

- [ ] Fresh get_project_url exactly matches Preview; branch and preserved work checked.
- [ ] Deployed/local function versions and credential presence compared without secret output.
- [ ] Disposable Postgres replay validates syntax, ownership transfer and all old security invariants; no Production or Docker.
- [ ] Test PostgREST SELECT/INSERT/merge-upsert with exact column grants, not only `has_table_privilege` (table-level checks can stay false after correct column grants).
- [ ] Super Admin list/summary/student overview/teacher overview succeed; no/invalid-session 401 and unauthorized nine-role callers denied.
- [ ] Existing link RPC remains caller-authenticated; service EXECUTE remains false; Admin cross-branch linking denied.
- [ ] All nine roles plus multi-role combinations tested for settings reads/writes. Admin reads permitted only; sensitive categories Super Admin only; unassigned users retain waiting screen.
- [ ] Unknown keys, forged identity/stamps/scope, malformed values, credential patterns and unsupported deletes rejected server-side.
- [ ] Audit event created atomically; direct audit insert/update/delete and direct trigger execution denied; audit-role membership/CREATE privileges absent after apply.
- [ ] Failed/absent backend keeps controls unavailable; save success appears only after exact acknowledgement; successful read/reload tested on both clients.
- [ ] Check no unexpected grants on student links, financial tables, ordinary roles or PUBLIC/anon; RLS stays enabled.
- [ ] Document multi-step role/teacher mutation and branch-membership risks before authorizing those operations; test each separately if approved.
- [ ] Email invitations/account creation and target student linking remain untested until specifically approved.
- [ ] Record identities/roles, timestamp, expected/actual results, HTTP status, environment and audit evidence without JWTs/passwords/secrets.

The current blockers remain in Preview. This package is ready for review, not a claim that migrations or authenticated security verification succeeded. Sandbox shell initialization failed; approved local escalated commands were used for filesystem work and tests. CLI usage was limited to help and local file creation. No hosted change was made.

References consulted: [Supabase observability](https://supabase.com/docs/guides/observability), [CLI migration creation](https://supabase.com/docs/reference/cli/supabase-migration-new), repository Supabase/Postgres skills. Project-specific findings come from the SELECT-only Preview metadata and inspected local source.
