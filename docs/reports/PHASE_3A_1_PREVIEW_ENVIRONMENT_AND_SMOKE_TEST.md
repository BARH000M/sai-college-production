# Phase 3A-1 — Preview environment and authenticated smoke test

Date: 2026-11-16. Branch: `feature/v2-completion`.
Preview project: `mgibjusuglafbnlrkbep`. Production was not contacted.

## Verdict: BLOCKED — no authorized Preview Super Admin session available

The Preview configuration is now verified and the root React application was launched in Preview mode. The Preview banner appeared and browser resource inspection observed the Preview Supabase host, with no Production host observed. The browser was signed out at the login page; neither Preview nor Production auth storage existed, and no authorized Super Admin session was available. Authenticated screens therefore remain untested. Browser console output included HTTP 401 and 429 errors, but no endpoint path or safe error code was captured; they cannot be attributed to a specific application operation or treated as evidence about the historical permission failures.

## 1. Workspace preservation

- Branch: `feature/v2-completion`.
- Preserved the existing root `.env`, all prior untracked reports, Preview MCP config, React/Flutter source, and Git work.
- Created `.env.preview.local` and this report. The env file is excluded by `.gitignore` rule `.env.*`.
- No reset, clean, pull, merge, commit, push, source edit, or Flutter edit.

## 2. Separate Preview environment validation

| Check | Result | Status |
| --- | --- | --- |
| Supabase MCP URL | `https://mgibjusuglafbnlrkbep.supabase.co` | PASS |
| `.env.preview.local` target | `preview` | PASS |
| `.env.preview.local` URL | Exact Preview URL | PASS |
| Preview public key present/valid | Nonempty legacy anon JWT verified by metadata only: role is `anon`, project ref matches Preview. Key value was not displayed. | PASS |
| Production key fallback | No. Vite `loadEnv('preview', ...)` resolves the Preview-mode values and does not fall through to the root Production key. | PASS (isolation) |
| Secret/service-role key | No secret/service-role key in the Preview env or browser source. | PASS |
| Process-level `VITE_*` overrides | None present | PASS |
| Git ignore | `.env.preview.local` is ignored by `.gitignore:11:.env.*` | PASS |
| Production connection guard | Effective target and URL are Preview. The shared client validates the selected target URL before `createClient`. Browser resource inspection observed only the Preview Supabase host; no Production host was observed. | PASS (configuration and observed browser resources) |
| Production auth-session reuse | Both `sai-preview-auth` and `sai-production-auth` were absent from local storage; the Preview app did not reuse a Production session. | PASS |
| Application source | Root React project selected; the secondary `web/` scaffold was not used | PASS |

The ignored `.env.preview.local` was validated in memory with Vite's `preview` mode. Its Preview key was checked without printing it; no key value is included in this report. The original root `.env` was preserved and not used to launch the app.

## 3. App launch and network check

| Check | Result |
| --- | --- |
| `npm run dev -- --mode preview` | PASS — root app started at `http://127.0.0.1:3000` |
| Preview banner | PASS — visible in the application |
| Browser Supabase host | PASS — observed host was `mgibjusuglafbnlrkbep.supabase.co` |
| Production network calls | None observed; Production was not contacted |
| Login/session behavior | Login page loaded. No Preview or Production auth storage was present; no credentials were entered. |

Vite's Preview mode resolved the exact target and URL, accepted the locally configured public key format, and had no inherited process `VITE_*` overrides or Production-key fallback. Browser resource inspection showed no Production host. The server was started with:

```powershell
npm run dev -- --mode preview
```

The development server was stopped after the browser checks. No `.env` contents or key value were emitted.

## 4. Authenticated smoke-test results

The app rendered its login page and redirected to `/auth?next=%2Fportal%2Fdashboard`. No sign-in was attempted and no authorized Super Admin session was available. The read-only checks below are all **NOT TESTED**:

| Read-only screen | Expected client request | Result / HTTP status |
| --- | --- | --- |
| Login page rendering | None (unauthenticated) | PASS / no authenticated API status captured |
| Super Admin dashboard | `manage-roles` (`summary`) | NOT TESTED / no request |
| Role Management | `manage-roles` (`list`) | NOT TESTED / no request |
| User directory | `manage-roles` (`list`) | NOT TESTED / no request |
| Waiting-for-role accounts | `manage-roles` (`list`) | NOT TESTED / no request |
| Teacher account directory | `provision-learning-account` (`teacher-overview`) | NOT TESTED / no request |
| Student learning-account directory | `provision-learning-account` (`overview`) | NOT TESTED / no request |
| System Settings categories/loading | REST SELECT from `sai_system_settings` | NOT TESTED / no request |
| Admin/ordinary-role settings read permissions | REST SELECT under existing sessions | NOT TESTED / no request |

Browser console output during page reloads included HTTP 401 and 429 statuses. Instrumentation did not capture a corresponding endpoint path or safe application error code; there is no evidence to associate them with `manage-roles`, `provision-learning-account`, or `sai_system_settings`. These unauthenticated console errors do not establish whether the historical HTTP 500s or missing-table error have disappeared. Authenticated requests are still required.

## 5. Corrected Preview test-account check

Repeated as a Preview-only SELECT using the literal SQL value `e2e-v2-student@example.test`; returned counts only:

| Check | Count |
| --- | ---: |
| Auth account | 1 |
| Profile | 1 |
| Role assignments | 0 |
| Student linkage | 0 |

No rows were modified.

## 6. Local validation

| Check | Result |
| --- | --- |
| Root `npm run type-check` | PASS, exit 0 |
| Root `npm run lint` | PASS, exit 0; no warnings/errors |
| Root `npm run build` | PASS, exit 0; 261 modules; chunk-size warning; `out/` written |
| `npm --prefix web test` | PASS, 72 passed, 0 failed, 0 skipped |
| Flutter | Unchanged; prior recorded status is analysis PASS / 48 tests PASS; not rerun |

Automated checks do not verify authenticated backend authorization or replace the blocked browser smoke tests.

## 7. Remaining issue and readiness

**Exact blocker:** an existing authorized Preview Super Admin session is unavailable in the browser. The Preview environment and app launch are verified, but the prior HTTP 401/429 console statuses have no captured endpoint or safe error code and need request-level diagnosis. Use an existing authorized Preview account in the local browser; do not share credentials in chat. Perform only the read-only screens above and record each request's sanitized endpoint, HTTP status, and safe error code. Do not grant/revoke roles, create/provision accounts, link/unlink students, or save settings.

**Nine-role testing: NOT READY.** No authenticated role checks were performed. The correct test-account counts and local checks passed, but application authorization, role-specific visibility, and the previous HTTP errors remain unverified.

No hosted data was modified, no migrations or functions were deployed, no Production endpoint was contacted, and no commit or push was made.
