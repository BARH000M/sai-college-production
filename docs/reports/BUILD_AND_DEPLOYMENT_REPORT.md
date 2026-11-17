# Build and deployment status — Phase 7-R

Read-only status reconciliation, 17 November 2026. This is not a release
approval or a claim that the earlier phase validations were rerun.

| Target | Current result | Evidence / limitation |
|---|---|---|
| GitHub `main` | SYNCHRONIZED, WORKTREE DIRTY | Local branch and HEAD match `origin/main` at `0737f84b1e06be009cf6a5bc46c01ff2364fdac8`. Preserve all existing Phase 4B and unrelated edits. |
| GitHub automation | CI ONLY | Inspected `.github/workflows/web-ci.yml` and `mobile-ci.yml`: push, PR and manual triggers; no database migration or production deployment action found. |
| Supabase Main | READ-ONLY, ACTIVE_HEALTHY | Project `aeryusbrulqdxjdynwfh`, PostgreSQL 17.11. No SQL writes, migrations or function deployments were made in this task. |
| Main migration/contract inventory | 16 recorded migrations; 47 public tables with RLS enabled | Main migration list and public table catalog were read-only. Proposed Phase 3B RPCs, Phase 3C contact guard and Phase 4A examination tables remain absent according to current catalog/reconciliation evidence. |
| Hosted Edge Functions | LEGACY VERSIONS ACTIVE | `manage-roles` v9 (`verify_jwt=false`), `school-admin` v7 (`false`), `provision-learning-account` v8 (`true`), `link-student-account` v4 (`true`). Do not deploy until the exact local source/config, database contract and global write hold are approved. |
| Local Phase 3B | VALIDATED PACKAGE; NOT DEPLOYED | Existing closeout reports type-check/lint, 88 web tests, 7 Deno tests and isolated PostgreSQL behavior passed. This is not production acceptance. |
| Local Phase 3C / 4A | IMPLEMENTED; NOT DEPLOYED | Earlier reports record passing tests. They were not rerun in this preflight. |
| Local Phase 4B | IN PROGRESS; VALIDATION INCOMPLETE | Focused tests passed earlier. Web type-check/ESLint after the last source fix and Flutter analysis/tests remain unverified. Keep all work uncommitted and unstaged. |
| Root React production build | NOT RUN IN THIS PREFLIGHT | Prior build evidence is not current build identity or live deployment evidence. |
| Android APK / AAB | NOT BUILT IN THIS PREFLIGHT | No release build or device test. A Java 21 / Gradle 8.4 incompatibility was previously reported; current resolution was not checked. |
| iOS IPA / TestFlight | NOT BUILT | Requires macOS, signing and store validation evidence. |
| `www.sai-academic.com` | NOT DEPLOYED | Prior preflight reported HTTPS response; deployed artifact identity, authenticated behavior, hosting write access and rollback were not verified here. |
| Production acceptance | NOT RUN | No controlled production accounts or records were used. No authenticated nine-role web/mobile test was made. |

**Disposition: NO-GO.** No production change was made. See
[`PRODUCTION_DEPLOYMENT_STATUS.md`](./PRODUCTION_DEPLOYMENT_STATUS.md) for the
recovery gate, package hashes, dependency order, stop conditions and rollback
limits.
