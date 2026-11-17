# Production deployment status and candidate manifest — Phase 7-R

**Disposition: NO-GO.** This report records a read-only preflight on
17 November 2026. It is not approval to run SQL, deploy Edge Functions, activate
a maintenance hold, deploy the website, or release a mobile build. No hosted
writes or deployments were performed.

## 1. Main and Git identity

| Item | Observed value |
|---|---|
| Supabase project | `aeryusbrulqdxjdynwfh` (`sai-college-production`) |
| Project status / region | `ACTIVE_HEALTHY`, `ap-northeast-1` |
| Database | PostgreSQL 17.11 |
| Git branch / HEAD | `main` / `0737f84b1e06be009cf6a5bc46c01ff2364fdac8` |
| `origin/main` | `0737f84b1e06be009cf6a5bc46c01ff2364fdac8` |
| Worktree | Dirty; preserve Phase 4B, other code and local documentation changes |
| GitHub Actions | `web-ci.yml` and `mobile-ci.yml` are CI only. No migration or production deploy action found. |
| Main public catalog | 47 listed tables; RLS enabled on all listed tables. Proposed examination tables are absent. Existing legacy homework tables are present. |
| Main migration history | 16 records: `001`–`006`, `008`–`014`, `20261110172940`, `20261110173339`, `20261110173506`. Do not replay old migrations or repair history by inference. |

These are metadata/catalog observations, not proof of application behavior,
production authorization, or successful restore.

## 2. Recovery gate and limits

### Existing evidence

- The archive `D:\SAI-Production-Backups\MAIN-20261117-164017\MAIN_DATABASE.dump`
  has recorded SHA-256
  `a3217b751c88da283f1a521068276bb79db9cad0a7c456630e85874e227638ac`; its
  recorded checksum matched and full decompression passed.
- Its isolated PostgreSQL restore is explicitly **PARTIAL**: 94 tables
  restored; 93/96 archive data-section counts matched; 113/115 policy entries
  restored; restore exited 1. The native target lacked five required extensions,
  Windows blocked `pg_stat_statements`, and restore of the `ensure_rls` event
  trigger failed on ownership. Auth role configuration and original grantors
  were not restored; passwords are absent. This is not a complete Supabase
  restore or a production recovery certificate.
- The workspace archive reports 40,336 of 40,336 enumerated files verified,
  zero errors and two directory links represented as metadata. It is protected
  by a restricted Windows ACL but is **not encrypted** and is not a production
  database recovery point.
- One inventoried Storage object and Edge source/configuration were separately
  recorded. Database backup alone does not preserve Storage file bytes.
- The 17 November Main reconciliation report recorded eight completed managed
  backups from 9–16 November, latest reported at 16 November 2026
  16:01:38.482 UTC (ID `2285443784`), with WAL-G enabled and PITR disabled.
  That is the latest known prior observation, not a backup-list refresh in this
  pass. No managed-backup listing tool/current scoped evidence was available.

### Required before any production write

1. Operator supplies read-only dashboard evidence for the latest completed
   backup ID/time/status, retention, restore availability, PITR state/window,
   and whether a fresh snapshot is needed for the planned maintenance window.
2. Produce an approved fresh protected recovery point if the previous snapshot
   is stale; capture schema, data, Auth/user linkage, migration history,
   required ACL/grants and sequences using protected TLS configuration.
3. Restore to an isolated Supabase-compatible environment and verify schema,
   application/Auth data, roles, extensions, policies, triggers, migration
   records, counts, sequences and required platform behavior. Preserve and
   verify Storage object bytes, Edge source and Edge configuration separately.
4. Record discrepancies, recovery time/point limits and owner-approved
   recovery procedure. Do not treat the partial native PostgreSQL restore as a
   production rollback path.

## 3. Hosted Edge state and local source fingerprints

Hosted metadata and downloaded source were inspected read-only. The hosted
`ezbr_sha256` values below are platform-reported fingerprints; they are not
assumed equivalent to a local file SHA-256.

| Function | Hosted state/version | `verify_jwt` | Hosted source fingerprint |
|---|---:|---:|---|
| `manage-roles` | ACTIVE v9 | false | `17bbfaab3103d98e6c3303154188aa0a00091e141636ba0e6d4595558f72076f` |
| `school-admin` | ACTIVE v7 | false | `de829b86793f9f515b329ad3c58d34b5ec500e2dd6b88b7c7971e6a4bd738289` |
| `provision-learning-account` | ACTIVE v8 | true | `387c1be9769a97ffc9c0b4e19d322adfe4503ce4b18546d62a2c2040479b9cc5` |
| `link-student-account` | ACTIVE v4 | true | `e685c77004a122e884762644a46ede56bfb360ebd3f8b4152ba49b3d2ba7c27a` |

| Local candidate source | SHA-256 |
|---|---|
| `supabase/functions/manage-roles/index.ts` | `28db90d00ad7dab2bdabfa888546f358fec39fe300db87bd0a2739c679fd8217` |
| `supabase/functions/school-admin/index.ts` | `bd17a5130cb166b9b7246aaafc1a11ccb7c29b72652cd2de7ca42e271494312a` |
| `supabase/functions/provision-learning-account/index.ts` | `e9b53695ea2280d2d570d533b984faef498912bed33505810b85731a860e7fef` |
| `supabase/functions/link-student-account/index.ts` | `ab096838ef66e63be050c585d80de97559969eb0ad48b7f5e2755984a7db7076` |
| `supabase/functions/_shared/role-management-handler.ts` | `2e5fc63c5686e0926c26210cd350bdf492066be772d702644227b3c911c63389` |

The deployed legacy functions remain active. Their inspected code does not
enforce `PHASE3B_MUTATIONS_DISABLED`; `manage-roles` and `school-admin` also
report `verify_jwt=false` and perform application-level authentication inside
their handlers. A UI flag or setting that variable on the newer local source is
not an enforceable hold for already deployed versions.

## 4. Hash-pinned SQL candidate manifest

All files below are reviewed **proposals**, not migrations approved for
execution. Each listed file contains its own transaction boundary; the set is
not one atomic transaction and is not atomic with Edge deployments.

| Order | File | SHA-256 | Dependency / purpose | Rollback boundary |
|---:|---|---|---|---|
| 1 | `supabase/deployment/phase3b-main/01_role_contract.sql` | `8b2a2db0c4db8b33c0190a3e538414ba1a5781a8d5697e5785683236ce817417` | Main 3B prerequisite. Last-usable-Super-Admin guard, atomic role RPC, `sai_set_role` retirement-by-denial, membership/table ACL hardening and helper execute restrictions. | Transaction rolls back if it fails before commit. No inverse after commit; the resulting lockdown must be paired with compatible Edge routes under a verified global hold. |
| 2 | `supabase/deployment/phase3b-main/02_teacher_assignment.sql` | `1f3e35c4897814258a99053ba8b16543aae339d8ebbff0ef77c6879b9814fe4e` | Requires order 1; adds serialized teacher assignment RPCs. | Per-file transaction only; no reviewed inverse. |
| 3 | `supabase/deployment/phase3b-main/03_verified_onboarding.sql` | `edf88c5e0012762fc781079e996386455b5fd3e97d1fc0d6fb8f1872151fd05c` | Requires order 1 and Main baseline; guarded student/parent link and verification contracts. Legacy direct writers must be held before guards are installed. | Per-file transaction only; no reviewed inverse. |
| 4 | `supabase/deployment/phase3c-main/001_own_contact_validation.sql` | `17f33774dda9200ed371ccf59eae3ebba8584074bf9eb4600746897ff8d84afe` | After 3B; validates own-profile contact fields and server-managed timestamps. | Per-file transaction only; no reviewed inverse. |
| 5 | `supabase/deployment/phase4a-examinations/001_examinations.sql` | `36f90b4ba4e01481731912787144e098ef0efc8a026695ad511a9e7fa6b135f2` | After role/identity prerequisites; adds exams/results, state validation, grade triggers, RLS and class/roster RPCs. | Per-file transaction only; no reviewed inverse. |
| Containment only | `supabase/deployment/phase3b-main/rollback_hold.sql` | `f7cafebe02a105ef4361c3bf73eeceeeb5800dc105f3d8e86fda205cd344d553` | Explicit operator-approved revocation of execution on the new RPCs after their installation. Not a restore or a universal write hold. | Does not undo DDL/data and does not disable already deployed legacy direct writers. |

### Candidate execution order if all gates later pass

1. Obtain the recovery proof and written approval for the exact hashes above.
   Establish and rehearse a **separate, independently enforceable global write
   hold** first, covering old Edge instances, direct PostgREST/RPC writes,
   background jobs and privileged writers. The present `rollback_hold.sql`
   does not meet this requirement.
2. Under that verified hold, apply SQL orders 1, 2 and 3 sequentially. After
   each commit, verify expected RPC definitions, function grants, role/
   membership ACLs, triggers and RLS from read-only catalog checks and isolated
   positive/negative authorization tests. Stop on any discrepancy.
3. Still under hold, deploy reviewed local replacements for
   `manage-roles`, `school-admin`, `provision-learning-account` and
   `link-student-account`. Preserve unrelated school-admin operations and
   ensure all role, teacher and link writes use the corresponding guarded
   contracts. Record the platform-returned versions, fingerprints and
   `verify_jwt` settings. Test real authenticated denial/allow paths without
   production student mutations.
4. Apply SQL order 4, then 5, each separately, after schema preconditions and
   isolated tests pass. Verify profile validation, exam schedule/marks/state/
   grade policies and student/verified-parent visibility.
5. Only after backend acceptance, build and deploy the reviewed React/mobile
   clients, verify Main configuration and all nine roles, and release the
   external hold only after approved safe-exit checks pass.

This sequence is conditional. The exact deployed function interleaving must be
reviewed with the tested package, and the independent hold is currently
unproven; therefore **do not execute**.

## 5. Stop and rollback procedure

- Stop immediately on an unexpected catalog, migration, grant, policy, trigger,
  RPC, function-version or authorization result. Do not run later files.
- If an individual SQL file errors before `COMMIT`, allow that file's
  transaction to roll back; verify no partial effects before retrying.
- If a file committed or an Edge deployment completed, keep the external hold
  in place. Do not assume a SQL rollback script exists. Preserve logs and
  fingerprints; use only a reviewed forward correction or an owner-approved,
  tested recovery procedure based on the verified recovery point.
- Prefer out-of-place restore and validation before any in-place restoration.
  Restoring an older snapshot can discard legitimate writes and is not an
  automatic response to a function deployment failure.
- `rollback_hold.sql` only revokes new RPC execution. It does not roll back
  schema/data changes, restore old function versions, or block legacy service
  role writes.
- Do not use `supabase db push`, replay the historical migration directory,
  repair migration history, reset Main, force-push Git, or deploy from a CI
  workflow.

## 6. Approval and evidence record

| Record | Status |
|---|---|
| Approval | NOT REQUESTED / NOT GRANTED |
| Deployment timestamp | NONE |
| Production SQL writes | NONE |
| Edge deployments | NONE |
| Website deployment | NONE |
| APK/AAB | NONE |
| Authenticated live acceptance | NOT RUN |
| Deployment record / resulting versions | Not applicable until a separately approved deployment is executed |

Before any later approval, attach operator-supplied current backup/PITR
evidence, isolated full-recovery results, the global hold rehearsal, exact
manifest review, application acceptance identities and explicit project-owner
approval. No secrets or credentials should be sent in chat or committed.
