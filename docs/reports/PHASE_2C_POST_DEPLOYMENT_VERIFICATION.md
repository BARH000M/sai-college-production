# Phase 2C-3 — Post-deployment verification of Preview backend repairs

Date: 2026-11-16. Live observations between approximately **23:48 and 23:55 UTC**.
Workspace: `D:\SAI-College-Production-v2-completion`. Branch confirmed: `feature/v2-completion`; HEAD `201f08f`.
Preview project: `mgibjusuglafbnlrkbep`. Production `aeryusbrulqdxjdynwfh` was **not accessed**.

Classifications used: **VERIFIED WORKING**, **VERIFIED DATABASE ONLY**, **BLOCKED**, **SECURITY CONCERN**, **REQUIRES AUTHENTICATED TESTING**, **REQUIRES EXPLICIT APPROVAL**.

## Safety and scope statement

All hosted operations were read-only against the explicitly named Preview project. The first hosted call was `get_project_url`. No `db push`, no migration reapply/repair/reset, no Edge Function deployment or invocation, no hosted write, no role change, no settings save, no backup restore, and no Git commit/push/reset/clean/merge/rebase occurred. Prior workspace work was preserved untouched; the only new file is this report. The prior reports `PHASE_2C_PREVIEW_DEPLOYMENT_PREFLIGHT.md`, `PHASE_2C_FINAL_MIGRATION_REVIEW.md` and `PREVIEW_BLOCKERS_DIAGNOSIS.md` were read first and their findings are built upon, not repeated.

## 1. Migration and Preview identity checks

| Check | Result | Classification |
| --- | --- | --- |
| Preview project URL | Exactly `https://mgibjusuglafbnlrkbep.supabase.co` | VERIFIED WORKING |
| `20261116013951_phase2b_service_permissions` recorded | Present, position 37 of 38 | VERIFIED DATABASE ONLY |
| `20261116013952_phase2b_system_settings` recorded | Present, position 38 of 38 (latest) | VERIFIED DATABASE ONLY |
| Full migration list | 38 versions, all expected names in order, none pending | VERIFIED DATABASE ONLY |
| `public.sai_system_settings` exists, RLS enabled | Confirmed | VERIFIED DATABASE ONLY |
| `private.sai_system_settings_audit` exists, RLS enabled | Confirmed | VERIFIED DATABASE ONLY |
| Settings RLS policies | `settings_authorized_read` (super_admin, or admin + non-sensitive), `settings_super_insert`, `settings_super_update` (both super_admin-only with WITH CHECK); audit `settings_audit_super_read` and `settings_audit_trigger_insert` (`actor_user_id = auth.uid()`) — match the reviewed proposal exactly | VERIFIED DATABASE ONLY |
| Service-role column grants | `pg_attribute.attacl` matches the reviewed matrix: SELECT-only columns on the 11 read dependencies; INSERT/UPDATE on `profiles (id, full_name, email)`; INSERT `(user_id, role, assigned_by)` + table DELETE on `user_roles`; INSERT/UPDATE + DELETE on `branch_memberships`; UPDATE `teacher_id` on `classes`/`learning_courses`; INSERT-only on 5 `audit_logs` columns; `classes.program` SELECT present | VERIFIED DATABASE ONLY |
| No unexpected broad grants | No service_role grants beyond the reviewed set; `sai_system_settings` relacl = `postgres` full + `authenticated=r` with column-level `aw` on the three payload columns only; audit relacl = `postgres` full + `authenticated=r` + `sai_settings_audit_writer=a`; anon SELECT on settings = false; authenticated DELETE on settings = false; authenticated INSERT on audit = false; new private functions have no anon/authenticated/service EXECUTE except `sai_setting_definition` → authenticated (as reviewed) | VERIFIED DATABASE ONLY |
| Settings table contract vs React client | Columns `category, setting_key, value_text, value_type, scope, updated_at, updated_by`; PK `(category, setting_key)` matches client `onConflict`; known-key CHECK via `private.sai_setting_definition`, global-scope CHECK, ≤2000-char value CHECK, `updated_by` FK to `auth.users`; stored-statement parity with local files already proven in preflight, so the deployed allowlist equals the reviewed 16 categories / 43 keys | VERIFIED DATABASE ONLY |
| Audit writer role | `sai_settings_audit_writer`: NOLOGIN, no superuser, no CREATEROLE/CREATEDB, no INHERIT, no BYPASSRLS; owns `private.audit_system_setting` (SECURITY DEFINER, `search_path=pg_catalog`); all three new private functions have pinned `search_path=pg_catalog` | VERIFIED DATABASE ONLY |

**Deviation found:** one surviving role membership — `postgres` remains a member of `sai_settings_audit_writer` with `admin_option=true`, `set_option=false`, `inherit_option=false`, grantor **`supabase_admin`**. The final review expected no surviving memberships after ownership transfer. Security impact is minimal (`set`/`inherit` false, and `postgres` is already the privileged owner role), but it deviates from the reviewed end-state. **SECURITY CONCERN (minor) — REQUIRES EXPLICIT APPROVAL** for a one-statement corrective revocation; no action taken.

**Deployment source investigation:** the grantor `supabase_admin` on that membership shows the migration statements were executed through a channel running as `supabase_admin` (Supabase-managed migration infrastructure), not a direct local `postgres` connection. Postgres logs retain no DDL statements for the window, and migration history carries no operator identity. **Who/what exactly initiated the deployment (Codex, GitHub, dashboard) is BLOCKED — not traceable with available read-only telemetry.** No source is assumed.

## 2. Role-management verification

| Item | Result | Classification |
| --- | --- | --- |
| Root-cause repair (service_role ACLs) | Full reviewed grant matrix present in catalogs | VERIFIED DATABASE ONLY |
| Post-repair invocations of `manage-roles` / `provision-learning-account` / `link-student-account` | **Zero** function invocations in `function_edge_logs` from 2026-11-16 01:39 UTC to 23:55 UTC | REQUIRES AUTHENTICATED TESTING |
| Post-repair `permission denied` errors | **Zero** in `postgres_logs` for the same window (also zero invocations to produce them) | VERIFIED DATABASE ONLY (absence of errors; no traffic) |
| Most recent invocations | Pre-repair HTTP 500s at 2026-11-15 20:59:41–42 UTC (`manage-roles` deployment suffix `_7`, `provision-learning-account` suffix `_6`), authenticated user, `EDGE_FUNCTION_ERROR` — identical to the diagnosed failure | Historical evidence only |
| React clients vs deployed contracts | Unchanged since the blockers-diagnosis fixes; deployed DB contract now matches what the clients expect | VERIFIED DATABASE ONLY (source/static) |
| Role dashboard / user directory / waiting-for-role / teacher list / student learning-account list loads | Not exercised — no authenticated Super Admin session is available to this read-only verification, and creating one is a hosted write | REQUIRES AUTHENTICATED TESTING |
| Waiting-for-role test account (`e2e-v2-student@example.test`) | Count-only re-check: 1 auth account, **0 role rows, 0 student links** — waiting-for-role state unchanged and correct | VERIFIED DATABASE ONLY |

Whether the previous HTTP 500 permission errors are resolved cannot be certified without an authenticated invocation; the database-level cause (missing ACLs) is confirmed repaired.

## 3. System-settings verification

| Item | Result | Classification |
| --- | --- | --- |
| Table/RLS/grant contract | Complete and exactly as reviewed (section 1) | VERIFIED DATABASE ONLY |
| Table contents | `sai_system_settings` = **0 rows**; audit = **0 rows** — every category is genuinely unconfigured; no seeded/fake values; no writes have occurred | VERIFIED DATABASE ONLY |
| Super Admin loads authorized categories | Not exercised (no session) | REQUIRES AUTHENTICATED TESTING |
| Admin sees only non-sensitive settings | Policy expression verified in catalog; behavior not exercised | VERIFIED DATABASE ONLY + REQUIRES AUTHENTICATED TESTING |
| Other roles denied / sensitive settings protected | Policy and grant structure verified (authenticated SELECT gated by role predicate; sensitive categories Super-Admin-only; no anon access) | VERIFIED DATABASE ONLY + REQUIRES AUTHENTICATED TESTING |
| No fake success / no accidental blank saves | Client gating from the blockers-diagnosis fixes is in place; no save was attempted (none permitted) | VERIFIED DATABASE ONLY (static) |

## 4. Remaining HTTP / function errors

None observed after the migration window. The only function errors on record are the pre-repair 500s of 2026-11-15 20:59 UTC. Because there has been **no post-repair traffic**, "no errors" must not be read as "fixed" — the precise confirmation step is a single authenticated Super Admin read (e.g., `manage-roles` directory load), which requires an existing authorized session.

## 5. Security advisories (Preview, observed 2026-11-16 12:54 UTC)

| Finding | Level | Assessment |
| --- | --- | --- |
| `rls_enabled_no_policy`: `private.admission_tracking_rate_limits`, `private.admission_tracking_tokens` | INFO ×2 | Informational. Private schema, not API-exposed; pre-existing. |
| `function_search_path_mutable`: `public.sai_library_issue`, `public.sai_library_return` | WARN ×2 | Pre-existing functions missing pinned `search_path`. **SECURITY CONCERN (pre-existing, low-moderate)** — candidate for a separately reviewed hardening migration; not introduced by these repairs; nothing changed blindly. |
| `authenticated_security_definer_function_executable`: 31 RPCs (admissions, attendance, finance, learning) | WARN ×31 | The intentionally protected SECURITY DEFINER RPC set documented in earlier phases; each verifies caller roles internally. No new entries from the two migrations — the new settings functions correctly do **not** appear. No revocation performed. |
| `auth_leaked_password_protection` disabled | WARN ×1 | Pre-existing Auth configuration gap. Informational; enabling it is a config change requiring approval. |
| Surviving `postgres ∈ sai_settings_audit_writer` membership (admin option only) | From section 1 | **SECURITY CONCERN (minor deviation)** — corrective revoke requires explicit approval. |

**No genuine new authorization vulnerability and no security blocker was discovered in the repaired surface.**

## 6. Backup / deployment-history observations

| Item | Result | Classification |
| --- | --- | --- |
| Completed physical backups | **Four**, confirmed via explicit Preview-scoped CLI list (exit 0): `2275813299` (2026-11-15 17:57:02 UTC), `2265817177` (11-14 17:57), `2255808906` (11-13 17:56), `2248168760` (11-13 01:18); region `ap-northeast-1`, `walg_enabled=true`, `pitr_enabled=false` | VERIFIED DATABASE ONLY (metadata) |
| Restore point predating the migrations | The 11-15 17:57 UTC backup predates the migration versions (01:39 UTC 11-16), so a candidate pre-change restore point exists **if** the actual apply time was after 17:57 UTC — apply time is unproven | VERIFIED DATABASE ONLY (availability), timing unproven |
| Recovery verification | Reported-available only. No restore drill, downtime estimate, or accepted data-loss window has ever been demonstrated; PITR disabled | REQUIRES EXPLICIT APPROVAL (restore drill) |
| Expected next daily backup (~11-16 17:57 UTC) | Not yet visible in the listing at observation time | Observation only |
| Migration deployment source | Not traceable; only indirect evidence (grantor `supabase_admin`, see section 1) | BLOCKED |

No restore was attempted; no database object was modified.

## 7. Local test results

| Check | Result | Classification |
| --- | --- | --- |
| `npm --prefix web test` | **72 passed, 0 failed, 0 skipped**, exit 0 — includes the settings/role error-handling and Phase 2C migration-review regressions | VERIFIED WORKING (static/unit) |
| Root app `npm run type-check` | Exit 0, no errors | VERIFIED WORKING (static) |
| Root app `npm run build` (the real portal) | Exit 0 — 261 modules, built in ~8 s (chunk-size warning only, pre-existing) | VERIFIED WORKING (build) |
| `npm --prefix web run build` (legacy `web` scaffold) | **FAIL** — `src/main.tsx` imports `./components/ErrorBoundary` and `./AppRoot`, files that have **never existed in git history** (`git log --all` finds no trace). Pre-existing breakage of the unused Readdy-era scaffold, unrelated to Phase 2C; not fixed here | Pre-existing, out of scope |
| Flutter | Source unchanged in this task — prior recorded status stands: analysis PASS, 48 tests PASS (Phase 1). Not rerun | Recorded, not re-verified |

These are static/unit results. They are **not** evidence of authenticated RLS enforcement, which only the live checks below can establish.

## 8. Remaining actions requiring approval

1. **REQUIRES AUTHENTICATED TESTING** — using an existing authorized Super Admin session (no new accounts): read-only loads of the role dashboard, user directory, waiting-for-role list, teacher account list, student learning-account list, and every settings category; record sanitized HTTP codes. Then Admin and one ordinary role for settings denial checks.
2. **REQUIRES EXPLICIT APPROVAL** — corrective `REVOKE sai_settings_audit_writer FROM postgres`-class statement to remove the surviving membership (one statement, reviewed first).
3. **REQUIRES EXPLICIT APPROVAL** — any settings-save, role grant/revoke, or provisioning mutation tests (each with stated recovery).
4. **REQUIRES EXPLICIT APPROVAL** — a Preview backup restore drill to convert reported availability into verified recovery.
5. **REQUIRES EXPLICIT APPROVAL** — separately reviewed hardening for `sai_library_issue`/`sai_library_return` search_path and the leaked-password-protection Auth setting.
6. Deployment-record reconciliation (who applied `...951`/`...952`, when, under what approval) remains open and **BLOCKED** on evidence outside read-only database telemetry.

## 9. Readiness for Phase 3 nine-role testing

- **Database layer: READY.** Both repairs are present, exact, and free of unexpected grants; settings/audit contracts and RLS match the reviewed design; the known test account is in the expected waiting-for-role state.
- **Functional layer: NOT YET CERTIFIED.** Zero post-repair traffic means role management and settings behavior under real sessions is unproven. Phase 3 nine-role testing should begin with the section 8.1 read-only authenticated checks as its entry gate.
- **Test tooling: READY.** Web suites and the real portal build/type-check pass; Flutter baseline recorded.

## Verdict

**PARTIAL PASS** — Every database-level repair is verified present and correct in Preview, with no new security vulnerability and no post-repair errors on record. Functional confirmation of role management and system settings is blocked solely by the absence of an authenticated session, which this read-only mission may not create. One minor post-apply deviation (surviving audit-writer membership) and two pre-existing advisories are queued for separately approved follow-up.
