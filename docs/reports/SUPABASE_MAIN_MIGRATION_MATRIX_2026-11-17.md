# Main versus 40 local migrations — 2026-11-17

Target: `aeryusbrulqdxjdynwfh`. History and live catalogs were inspected separately. “Present” identifies inspected effects, including later equivalent/replacement implementations; it does not assert byte-identical historical execution or runtime certification. No migration is approved for deployment by this table.

| Local SQL file | In Main history | Live result / deployment disposition |
| --- | --- | --- |
| `001_initial_schema.sql` | Yes | Nine foundation tables, enum, keys and relations present. Do not replay CREATE TYPE/TABLE. |
| `002_security_policies.sql` | Yes | RLS and baseline predicates present; public helpers now delegate to private implementations. Replaying its initial-schema guard would fail against the expanded Main schema. |
| `003_staff_management_policies.sql` | Yes | Active-membership/class columns, staff policies, validation and audit triggers present. Membership writes still need the later lockdown. |
| `004_admissions.sql` | Yes | Table, staff/session directory, preparation/audit functions and policies present. |
| `005_admissions_session_directory.sql` | Yes | Directory and preparation bodies match after removing comments/whitespace. |
| `006_attendance.sql` | Yes | Tables/RLS/RPCs present; helper logic has moved to private, and callers use that layer. No need to recreate obsolete public helper copies. |
| `007_finance.sql` | No | Private `sai_finance` schema/tables/owner absent. Public-finance replacement exists. Exclude obsolete alternative; it would conflict with current public RPC contracts. |
| `008_learning_portal.sql` | Yes | Five learning tables/policies and equivalent consolidated helpers present. Session directory uses the earlier equivalent authorization body rather than this file's additional explicit auth-null guard. Do not replay the module. |
| `009_lesson_content.sql` | Yes | Content columns/check and returned-homework resubmission policy present; anon has no learning-table access. |
| `010_lesson_media_and_homework.sql` | Yes | Private `lesson-media` bucket, content-path columns and four storage policies present, using private helpers. |
| `011_homework_management.sql` | Yes | Homework release/edit timestamp columns present. Do not repeat its data backfill. |
| `012_learning_inbox_and_teacher_provision.sql` | Yes | Per-user inbox marker table and ownership policies present. |
| `013_teacher_account_management.sql` | Yes | All three teacher/active-membership indexes present; provisioning function is deployed but older than source. |
| `014_public_read_and_status_permissions.sql` | Yes | CMS anonymous published-read path and legacy public admission RPC grants present. Later secure tracking cutover must replace the legacy public contract deliberately. |
| `015_cleanup_and_schema_history.sql` | No | The nine history rows it would backfill already exist; diagnostic probe absent. Exclude: history repair is forbidden. |
| `016_vocabulary_and_notifications.sql` | No | Three tables, policies and 30 vocabulary rows exist. Later private-helper policies installed. Exclude object creation/seed replay. |
| `017_demo_attendance_week.sql` | No | Data seeder, no backend prerequisite. Main has 25 attendance sessions/73 records; never add demonstration records as reconciliation. |
| `018_library_and_communications.sql` | No | Four tables, policies, indexes and both circulation RPC bodies present. Do not replay. |
| `019_public_finance.sql` | No | Six finance tables, sequences, finance RPCs, announcement deliveries present. Core RPC bodies match; helpers replaced by the consolidated layer. Main already has one fee assignment. |
| `020_cms_schema_and_private_helpers.sql` | No | Three CMS tables, policies, grants and all 11 private helper bodies present. Preserve existing CMS rows/predicates. |
| `021_restore_write_grants.sql` | No | Broad authenticated table INSERT/UPDATE is absent. Existing column grants already permit intended workflows. Exclude broad replay: it would defeat immutable-column protections and allow branch-ID updates. |
| `022_consolidate_security_helpers.sql` | No | Eleven wrapper bodies match and affected policies use private helpers. Present; EXECUTE hardening is separately missing. |
| `023_revoke_wrapper_execute.sql` | No | Eleven public wrappers still authenticated-executable. Missing effect; comprehensive `029` supersedes this narrower revoke. |
| `024_retire_sai_set_role.sql` | No | Legacy authenticated-callable role writer still exists; no inspected dependents/references. Use a new drop-only replacement. Omit this file's audit DELETE, even though current matching audit count is zero. |
| `025_normalize_private_helpers.sql` | No | Fourteen private security/learning/attendance helper bodies match and are pinned definers. Already present. |
| `026_consolidate_finance_helpers.sql` | No | Private finance helper and public delegator bodies match; policies already bind to private helpers. Already present; later finance scope correction is missing. |
| `027_security_invariant_guard.sql` | No | `private.sai_assert_security_invariants(boolean)` exists with matching body. Do not reinstall; opt-in execute invariant would fail because wrapper EXECUTE remains open. |
| `028_revoke_finance_oracle_execute.sql` | No | Finance read helper remains authenticated-executable. Missing effect; use comprehensive `029`, not another overlapping migration. |
| `029_revoke_public_helper_execute.sql` | No | All 14 wrappers remain authenticated-executable. Still necessary; no RLS policy depends on these public wrappers. Finance wrappers also need its explicit service-role EXECUTE. |
| `030_restore_admission_column_grants.sql` | No | Equivalent column INSERT/UPDATE grants and denial on immutable admission fields already present. No replay needed. |
| `031_admissions_status_and_enrollment.sql` | No | Student `admission_enquiry_id`/unique index, status/enroll RPCs absent. Missing enrollment feature; outside minimum atomic-role deployment. |
| `20261115001316_secure_admission_tracking_and_verified_links.sql` | No | Both tracking tables, new public tracking RPCs, verified link/unlink/parent RPCs and link-guard triggers absent. Required onboarding slice needs coordinated Edge replacement; full file also changes public admissions compatibility. |
| `20261115014149_protected_admission_status_events.sql` | No | Private event table/writer role/trigger and token-protected history absent. Depends on new tracking contract. It snapshots existing current statuses; do not fabricate historical transitions from old audit rows. |
| `20261115051532_finance_scoped_directories.sql` | No | Three directory RPCs absent; current private finance read predicate is older. Missing scoped-finance feature; separate from role cutover. |
| `20261116000437_learning_lesson_completion_basis.sql` | No | `completion_basis` column/check absent; vocabulary/notification grants already sufficient. Only missing learning column/check would be needed, not redundant ACL replay. |
| `20261116013950_learning_scored_exercises.sql` | No | Question/attempt tables, grading/admin RPCs, helper/guard functions and triggers absent. Requires completion-basis change first. Separate learning rollout. |
| `20261116013951_phase2b_service_permissions.sql` | No | Every specified SELECT/DML column permission is already available to service_role through existing broader grants. Not necessary to apply. This does not endorse broadening browser grants. |
| `20261116013952_phase2b_system_settings.sql` | No | Public settings table exists with a different contract and public audit table; new typed/immutable validation, private audit table/writer absent. Unchanged file would fail at CREATE TABLE. Needs additive compatibility upgrade; preserve seven settings/eight audit rows and resolve one existing HTTPS incompatibility. |
| `20261116142308_atomic_role_management.sql` | No | Atomic RPC and other-usable-Super-Admin helper both absent. Base tables, constraints and service DML/private-schema usage prerequisites exist. Needs isolated behavior/concurrency tests before application. |
| `20261116151509_branch_membership_write_lockdown.sql` | No | Browser still has column INSERT and `is_active` UPDATE and old self/admin policy. Necessary server-only lockdown; Main already denies browser membership-ID UPDATE, unlike Preview. |

**Count check:** 40 local files = 13 recorded local versions + 27 unrecorded local versions. Main has those 13 plus the three unique versions below = 16 recorded migrations. No arithmetic subtraction of 40−16 identifies the real pending set.

| Main-only recorded migration | Verified objects/effects to preserve |
| --- | --- |
| `20261110172940_sai_system_settings_shared_20261110` | Public settings/audit tables, allowed-key/boolean/size checks, stamp/log triggers and Super Admin/Admin policies. |
| `20261110173339_sai_unified_modules_web_mobile_secure` | Eight `sai_*` module tables: alumni, certificates, CMS pages, download resources, housing rooms, inventory items, student portfolios and transport routes; RLS/guards/audit infrastructure present. |
| `20261110173506_sai_unified_module_realtime` | Those eight module tables appear in `supabase_realtime`. |

Evidence comes from `history.json`, `catalog.json`, `grants.json`, `dependencies.json`, `state.json`, `extended.json`, `configuration.json` and deployed function downloads under `.tmp-main-reconciliation/`. SQL sources and the offline function-body comparison are retained there. Normalized function-body matches are supplemental evidence, not semantic or execution tests.
