# Phase 3A — Authenticated application verification

Date: 2026-11-16. Workspace: `D:\SAI-College-Production-v2-completion`.
Branch: `feature/v2-completion`. Preview project: `mgibjusuglafbnlrkbep`.
Production project `aeryusbrulqdxjdynwfh` was not contacted.

## Verdict: PARTIAL — authenticated verification blocked

The Preview database URL and the requested test-account state were verified read-only. Local type-check, lint, build and web tests passed. **No authenticated application request was made**: no existing authenticated Preview browser session or Preview portal URL was available, and the root `.env` is configured to contact Production. To protect Production, the portal was not launched. Consequently no live UI, RLS or Edge Function outcome is claimed.

## 1. Preview application identity and configuration

| Check | Result | Status |
| --- | --- | --- |
| Supabase MCP Preview URL | `https://mgibjusuglafbnlrkbep.supabase.co` | VERIFIED WORKING |
| Root app `.env` URL | Exact Production URL, not Preview. Checked in memory; no value beyond the known project identity was printed. | FAILED |
| `VITE_SAI_TARGET` | Absent/empty. The client defaults to `production`. | FAILED |
| Root app Preview public key | A `VITE_PUBLIC_SUPABASE_ANON_KEY` value with `sb_publishable_` prefix is present, but its project ownership was not verified. Do not treat it as a Preview key. | NOT TESTED |
| Browser service-role/secret key | None found in VITE environment values or browser source. The `sb_secret_` text in `supabase.ts` and `systemSettings.ts` is validation logic, not a key value. | VERIFIED WORKING (source scan) |
| Preview banner | Source renders the banner only when `supabaseTarget === "preview"`. It was not rendered in a browser. With current `.env` the app resolves to Production, so it would not show the Preview banner. | FAILED (configuration); display NOT TESTED |
| App launch | Not run. Root `npm run dev` with the current environment would target Production. No `web/` scaffold was used. | BLOCKED |

No `.env` file was changed, and no server was started. Do not launch the current root environment. For a later Preview-only manual run, use an approved Preview public key and process-scoped values (do not put credentials in the report or share them):

```powershell
$env:VITE_SAI_TARGET = 'preview'
$env:VITE_PUBLIC_SUPABASE_URL = 'https://mgibjusuglafbnlrkbep.supabase.co'
$env:VITE_PUBLIC_SUPABASE_ANON_KEY = '<approved Preview publishable/anon key>'
npm run dev
```

Before opening the app, verify that the Preview banner is visible and the browser's Supabase requests use only the Preview host. Do not use the key currently in `.env` unless its Preview ownership is independently established.

## 2. Super Admin smoke test

No existing authorized Super Admin browser session was available to this run. No sign-in was attempted, no credentials or tokens were requested, and no function was invoked. All application checks below are **NOT TESTED**.

| Read-only check | Client request / endpoint | Result | HTTP status / safe error |
| --- | --- | --- | --- |
| Super Admin dashboard | `manage-roles` (`action: summary`) | NOT TESTED | No request; N/A |
| Role Management | `manage-roles` (`action: list`) | NOT TESTED | No request; N/A |
| User directory | `manage-roles` (`action: list`) | NOT TESTED | No request; N/A |
| Waiting-for-role accounts | Role directory list, including accounts with no assigned roles | NOT TESTED | No request; N/A |
| Teacher account list | `provision-learning-account` (`action: teacher-overview`) | NOT TESTED | No request; N/A |
| Student learning-account list | `provision-learning-account` (`action: overview`) | NOT TESTED | No request; N/A |
| Existing account list for linking | `link-student-account` (`action: list`) | NOT TESTED | No request; N/A |
| System Settings categories | REST `sai_system_settings` SELECT by category | NOT TESTED | No request; N/A |
| Settings read permissions (Admin/ordinary role) | Same REST SELECT under each existing session | NOT TESTED | No request; N/A |
| Loading, error and empty states | Portal UI and safe client error classification | NOT TESTED | No browser response |

There are no post-repair HTTP statuses to report. The prior 500s from 2026-11-15 are historical, pre-repair evidence only. The Phase 2C report verified the ACLs in database catalogs, but that is not proof that the previous Edge Function 500s are resolved under an authenticated request.

## 3. Correct test-account state (Preview, SELECT-only)

Queried using the literal address `e2e-v2-student@example.test`; only aggregate counts were returned:

| Check | Count | Result |
| --- | ---: | --- |
| Auth user | 1 | VERIFIED WORKING (account exists) |
| Profile | 1 | VERIFIED WORKING |
| Role assignments | 0 | VERIFIED WORKING (waiting-for-role state) |
| Student record linked to the account | 0 | VERIFIED WORKING (not linked) |

No account or role records were changed. The account is not an authorized student-role session and cannot be used to pass authenticated role-boundary tests.

## 4. Authenticated nine-role matrix

No role-specific authenticated sessions were available. Each role and its record-level boundaries remain **NOT TESTED**; no authorization pass is inferred from static tests or database catalog inspection.

| Role | Dashboard/navigation/routes/data visibility | Cross-student/parent and assigned-class boundaries |
| --- | --- | --- |
| `super_admin` | NOT TESTED | NOT TESTED |
| `admin` | NOT TESTED | NOT TESTED |
| `teacher` | NOT TESTED | NOT TESTED — assigned-class restriction |
| `accountant` | NOT TESTED | NOT TESTED |
| `receptionist` | NOT TESTED | NOT TESTED |
| `librarian` | NOT TESTED | NOT TESTED |
| `student` | NOT TESTED | NOT TESTED — cross-student restriction |
| `parent` | NOT TESTED | NOT TESTED — cross-parent/student restriction |
| `content_editor` | NOT TESTED | NOT TESTED |
| Multi-role combinations | NOT TESTED | NOT TESTED — role union must not bypass record-level restrictions |

Admin-versus-Super-Admin settings behavior is likewise NOT TESTED with sessions. Static policy/source checks are not authenticated enforcement evidence.

## 5. Exact HTTP errors and failing layer

- **Current run:** no HTTP requests were sent to the Preview app or its Edge Functions; status and safe error code are **N/A**.
- **Historical:** Phase 2C logs show HTTP 500 `EDGE_FUNCTION_ERROR` for `manage-roles` (deployment suffix `_7`) and `provision-learning-account` (suffix `_6`) before the ACL repair. No authenticated request after repair was available here, so persistence or resolution is **NOT TESTED**.
- **Layer diagnosis:** no current failing application layer can be identified without a real request. The local configuration is a separate, verified blocker: the root app is wired to Production by `.env` plus the default target and must not be launched as-is.

## 6. Local client changes

No local React integration bug was reproduced because there was no safe Preview application session to test. No source or environment file was changed. Existing client wrappers use the expected read-only actions (`summary`, `list`, `overview`, `teacher-overview`) and `sai_system_settings` SELECT; the source-level contract check does not establish deployed function parity or runtime behavior.

## 7. Local checks (automated, not authenticated tests)

| Check | Result |
| --- | --- |
| Root `npm run type-check` | PASS, exit 0 |
| Root `npm run lint` | PASS, exit 0; no warnings/errors |
| Root `npm run build` | PASS, exit 0; 261 modules; Vite large-chunk warning |
| `npm --prefix web test` | PASS, 72 passed, 0 failed, 0 skipped |
| Flutter | No Flutter source changed; prior recorded status is analysis PASS / 48 tests PASS. Not rerun. |

The root build wrote the configured `out/` directory; it was not cleaned. Git status after checks still showed only the two pre-existing untracked Phase 2C reports and this new report. No source changes were made.

## 8. Security concerns

1. **FAILED / security boundary:** current root `.env` targets Production and `VITE_SAI_TARGET` is unset. Do not start the app until a Preview-only environment is explicitly configured and verified.
2. The current public key's Preview project ownership is unverified. No key was printed or copied into this report. Use only a verified Preview publishable/anon key.
3. Prior Phase 2C findings remain outstanding and were not altered here: mutable `search_path` on `public.sai_library_issue` and `public.sai_library_return`; leaked-password protection disabled; and a residual `postgres` membership in `sai_settings_audit_writer` (set/inherit false). These require separate review/approval; no change was made.
4. No new browser credential exposure was found in the VITE environment/source scan. There is no actual service-role key in the browser source.

## 9. Manual authenticated checklist

Use the approved **Preview portal URL** (or first run the root app only after setting and validating the Preview-only process environment above). Use an already-authenticated, authorized Preview account in the browser; do not send its password, token, or session data to anyone. Confirm the Preview banner and Preview API host before navigation.

1. Open `/portal/dashboard`; record PASS/FAIL, the visible role-appropriate dashboard, and sanitized request statuses.
2. Open `/portal/modules/roles`; read the Super Admin summary and user directory. Observe waiting-for-role rows. Network filter: `/functions/v1/manage-roles`; only `summary` and `list` read requests. Record status and safe error code only.
3. Open the teacher account view and the student learning-account view. Network filter: `/functions/v1/provision-learning-account`; only `teacher-overview` and `overview`. If reviewing eligible accounts, `/functions/v1/link-student-account` may use `list` only.
4. Open `/portal/modules/settings`. Load each category without editing or saving: `general`, `sessions`, `notifications`, `sms`, `whatsapp`, `email`, `payments`, `printing`, `cms`, `backups`, `languages`, `currencies`, `extensions`, `custom_fields`, `verification`, `updates`. Record empty/unconfigured states. Do not copy values or response bodies into the report.
5. Repeat only read requests with an existing Admin session, confirming nonsensitive settings only, then an existing ordinary-role session to confirm privileged categories are denied. Record each HTTP status and allowlisted error code without user data.
6. For each of the nine existing role sessions, check its dashboard, visible navigation, direct access to one disallowed route, and role-specific visible data. With approved test records, verify student/parent isolation, teacher assigned classes, Admin vs Super Admin, and multi-role union without crossing row-level limits. If no approved session or safe test record exists, mark NOT TESTED.
7. In DevTools Network, record endpoint path, status, safe error code, and request time only. Do **not** export HAR files, copy request/response bodies, disclose user records, or capture authorization headers. Do not click grant/revoke/create/delete/link/unlink/provision/Save controls.

## 10. Phase 3B readiness

**NOT READY for authenticated Phase 3B testing yet.** The app must first be run from a confirmed Preview-only environment, and an existing authorized Preview Super Admin session/portal URL must be available. The read-only smoke tests above are the entry gate. The account-state check and local automated checks are complete; the nine-role and RLS behavior matrix remains entirely untested.

No hosted writes, deployments, role changes, source edits, commits, pushes, or Production requests occurred.
