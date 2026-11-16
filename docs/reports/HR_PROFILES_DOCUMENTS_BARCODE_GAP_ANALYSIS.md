# HR, profiles, documents, modules and barcode gap analysis

Date: 2026-11-16. Baseline: `feature/v2-completion`. Scope is the five requested families, not another repository-wide audit. Preview identity and blocker evidence are in `PREVIEW_BLOCKERS_DIAGNOSIS.md`.

## Master-spec traceability

The authoritative checked-in mapping is `src/portal/lib/systemInventory.ts` plus `systemInventoryEntries.ts`: **32 categories / 147 entries**, confirmed by the current automated inventory tests. Do not add a second inventory or treat every navigation destination as complete. The following crosswalk preserves that baseline; requested refinements such as staff photos/contracts are subrequirements, not new entries invented to inflate the total.

| Master category | Relevant existing entries | Requested family |
| --- | --- | --- |
| 2 Student Information (15 entries) | Student Details, Student History, Parent Report, Student Login Credentials, Student CV; related enrollment/status entries | Extended profiles, account state, academic history |
| 6 Attendance (3) | Attendance, QR Attendance, attendance reporting | QR attendance integration; staff attendance remains separate |
| 12 Download Center (2) | Existing download-center entries | Documents; this does not establish a private document-management backend |
| 17 Human Resources (5) | Staff Directory, Staff Attendance, Payroll, Leave, Teacher Evaluation | HR; profiles/photos/contracts/qualifications/documents refine Staff Directory |
| 22 Certificates and Cards (3) | Generate Certificate, Transfer Certificate, ID Card | Documents, student/employee cards and barcode/QR verification |
| 29 Student Personal Services (2) | My Profile, My CV | Own profile/CV |
| 30 Parent Personal Services (3) | My Children, Child Fees, Child Homework | Verified parent relationships and permitted child data |
| 32 System Settings (31) | Role Permissions, Users, Plugins, Modules, Student Profile Update, ID Auto Generation, File Types, Header/Footer Printing, Thermal Printing; related preferences | Account state, module management, document policy, IDs/printing |

The catalog's existing statuses are source labels, not hosted proof. In particular, its `QR Attendance` entry says implemented/working, but `QrAttendance.tsx` imports `qrRoster`/`academicClassOptions` fixtures and changes local state. The current evaluation supersedes that claim for Preview: **broken as a real attendance workflow / partial demonstration**. Settings/Plugins metadata claims are also backend-blocked because the preference table is absent. No global catalog reclassification was made in this task.

Status definitions: **verified** = inspected implementation/schema artifact exists, not end-to-end security certification; **partial** = usable subset only; **broken** = an advertised flow cannot perform its stated operation; **read-only** = intentional display-only support; **backend-blocked** = client path exists but backend contract/ACL is absent; **missing** = no supported implementation/contract found. Multiple labels describe different layers.

## Shared backend evidence

Preview contains `profiles`, `user_roles`, `students`, `classes`, `branches`, `branch_memberships`, `parent_student_links`, `audit_logs`, learning, attendance, finance and library tables. Targeted application-schema relation inspection found no HR employee/contract/qualification/payroll/leave/evaluation tables, document/attachment registry, card/barcode/QR session registry, module/plugin registry or settings table. The only matching extended-profile relation was `public.profiles`.

`profiles` contains `id`, `full_name`, `email`, `phone`, `preferred_locale`, timestamps. No avatar/photo, employment, CV or academic-history columns exist. `students` contains account link, branch, admission number, name, date of birth, current class, status and admission-enquiry link; it does not contain an academic-history archive. `parent_student_links` has verification timestamp and verifier.

Only one Storage bucket exists: **private `lesson-media`**, 100 MiB limit, with MIME restrictions for video/audio, PNG/JPEG and PDF. SELECT/INSERT/UPDATE/DELETE policies tie the first object-path component to a real lesson and course authorization; learners require published accessible lessons. No avatar, admissions, HR or certificate bucket exists. These policies must not be widened to make unrelated uploads work.

## 1. Human resources

| Requirement | React evidence | Flutter evidence | Preview/backend and classification | Secure next contract / reuse |
| --- | --- | --- | --- | --- |
| Employee directory | `staff` navigation is pending/unavailable. `Roles`, `TeacherAccountPanel` and provision overview expose accounts/teaching assignments only. | `PageId.staff` has role gating but falls back to an unavailable-data screen for live use. | **Partial / backend-blocked**. Profiles/roles/memberships exist; no employee registry. Account services additionally fail on service ACLs. | Reuse identity, branches and teacher workloads. Add employee identity/employment rows with branch-scoped staff directory RPC returning an explicit field projection. |
| Teacher directory | Teacher-account class/workload display exists via `learningAccounts.ts`. | Assigned-class teacher portal exists, not an HR directory. | **Partial / broken in Preview** due to account-service ACLs. | Repair existing service; do not create a second teacher identity table. Join an employee record to existing Auth/profile ID. |
| Staff profiles and photos | Own name/contact editing in `Profile`; no staff-specific record/photo upload. | Account summary with placeholder avatar; no photo editor. | **Partial** for profile; **missing** photos. | Private avatar object metadata and authorized upload/read/update/remove contract; bounded image dimensions/size and safe thumbnail handling. |
| Contracts | No supported contract form/storage. | None. | **Missing**. | Employee contract dates/type/status, restricted salary terms, private document link, version/audit trail. |
| Qualifications | No supported qualifications workflow. | None. | **Missing**. | Employee qualifications with issuer/date/verification and private evidence document, scoped to authorized HR reviewers. |
| Staff attendance | Student/class attendance implementation exists and must stay separate. | Live attendance screens are student/class scoped. | **Missing** for employees. Student attendance tables are not reusable employee rows. | Staff attendance events/shifts, Asia/Aden dates, unique employee/day/shift rules, correction reason and audit. Reuse date/validation patterns only. |
| Leave | No leave application/approval flow. | None. | **Missing**. | Leave types/balances/requests/approval transitions; employee-own access, branch-authorized approval, no self-approval, atomic balance updates. |
| Payroll/salary records | Finance screens handle student fees, not wages. | Finance screens also handle student fees. | **Missing**. | Separate payroll periods, salary components, approval/payment ledger and employee payslip projection. Accountant permission must be explicitly scoped; no teacher/student fee table reuse. |
| Teacher evaluations | Workload counts exist, no assessment rubric/record. | Teacher academic portal, no evaluations. | **Missing**. | Versioned rubric, evaluator scope, submitted/finalized state, authorized employee visibility; protect confidential notes. |
| Staff documents | No HR upload form/registry. | None. | **Missing**. | Shared document contract below with employee ownership/type and HR authorization; not public URLs or lesson attachments. |

Preserve nine roles. There is no new `hr_admin` role proposal. Super Admin controls policy; any Admin HR authority must be branch-scoped and explicitly approved. An employee's own view must exclude confidential HR notes and other employees' data. Payroll authority must be decided separately from generic Admin UI access.

## 2. Add-ons and module management

| Requirement | React | Flutter | Backend/status | Secure reuse / missing work |
| --- | --- | --- | --- | --- |
| Module inventory | `SystemInventory` and shared 32/147 reference exist; Super Admin route restricted. | `module_registry.dart` and page/role map exist, but no equivalent full master-catalog screen. | **Verified read-only** source inventory, with stale claims noted above. No installed-module DB registry. | Reuse master category/entry IDs; add evidence-backed status, environment and last verification fields without conflating installed code with working contracts. |
| Functional versus pending | `availableModuleIds` and `pendingModules` enforce source-controlled availability. | Explicit unavailable screens plus generic module registry; some generic modules attempt proposed tables. | **Partial**; clients differ. | Shared capability response validated against code-supported IDs and required schemas. Do not grant access merely because a switch says enabled. |
| Existing integrations | Supabase Auth/DB/Storage/functions, email invitation code, QR generation and camera/image scanning libraries. | Supabase client, printing and role-scoped academic screens. | **Partial**: inspected code/dependencies; delivery/runtime not generally verified. | Report Auth, Storage, Resend and scanner prerequisites independently; dependency declaration is not an installed external plugin. |
| Configuration | Settings `extensions` section contains enabled module/plugin ID text fields. | Same preference section. | **Backend-blocked**: no `sai_system_settings`. No executable plugin installer. | Keep unsupported save operations unavailable. Configuration needs typed allowlists and real consumers. |
| Authorized enablement | Compiled availability lists, not dynamic runtime activation. | Compiled routes/registry. | **Missing** as an administrative operation. | Super-Admin-only capability mutation, dependencies checked server-side, audited transition, client code support and schema readiness required. |
| Dependencies | npm/Flutter lockfiles and code imports. | Package lockfile and static module map. | **Partial**, no module dependency graph/registry. | Versioned manifest with required RPCs/tables/buckets/providers and failure explanations; do not execute user-supplied plugin URLs/code. |
| Plugin installation | No working install/uninstall path. | None. | **Missing**, intentionally no fake installation. | Decide a vetted build-time extension process; no arbitrary SQL/package execution from settings. |

`unifiedModules.ts` and mobile `module_registry.dart` reference proposed `sai_*` tables such as `sai_certificates`, downloads and portfolio. Their presence in client code is **not** evidence that schema or policies exist. Web hides these pending routes; mobile has generic table-backed screens that may surface backend errors. Align capability gating before activating them.

## 3. Extended user profiles

| Requirement | React | Flutter | Preview/status | Reuse / secure missing contract |
| --- | --- | --- | --- | --- |
| Student profile | `Profile`, management student records and personal dashboards. | Account summary and personal learning/attendance/finance screens. | **Partial**: identity/contact and current student record exist. | Reuse `profiles` and `students`; distinguish editable own contacts from authoritative enrollment/class/status fields. |
| Teacher profile | Own profile plus teacher account/workload views. | Account summary and assigned classes. | **Partial / account-service broken**. | Extend own profile through scoped employment projection; preserve assigned-class restrictions. |
| Employee profile | Generic Auth profile only. | Generic summary only. | **Partial / missing employment**. | Add employee/employment metadata joined to existing profile; never duplicate login identity. |
| Parent profile | Own profile, `FamilyHome`, verified-child loaders and parent-link management. | Account summary and linked-child academic/financial views. | **Partial**; relation schema/RPCs exist, authenticated isolation unverified here. | Reuse `parent_student_links`, verification RPC and permission helpers; parent self-service cannot verify its own relationship. |
| Profile photos | No upload/editor. | Placeholder avatar. | **Missing**; no photo field/bucket. | Shared avatar contract with read/access/replace/delete policies. |
| Contact information | `profile.ts` edits full name, phone, locale; email is read. | Current summary shows name/email/roles; no equivalent contact editor. | **Partial**, React ahead. | Reuse existing profile API with self-only RLS; implement mobile form parity. Email change remains an Auth verification flow, not profile-only editing. |
| Student CV | Proposed portfolio client; web pending route. | Generic `sai_*` portfolio client. | **Backend-blocked / missing supported storage**. | Typed CV sections and private attachments, own-edit/authorized-review, audit; do not store arbitrary executable schemas. |
| Academic history | Current class/status, progress and grade-related learning records are separate sources. | Current learning/progress views. | **Partial** current activity; **missing** enrollment/qualification history archive. | Append-only enrollment/transfer/award history with restricted corrections. Reuse existing progress, do not invent grade history. |
| Employment details | No employee metadata form. | None. | **Missing**. | Effective-dated position/department/branch/status with confidential salary records separated. |
| Verified relationships | Existing verification controls and RPCs. | Existing verified-child read flows; no equivalent administrative link editor established. | **Verified contract / partial workflow**. | Reuse existing authorized linking rather than new parent foreign keys or client-only booleans. |
| Account state / roles | Directory displays roles and email-confirmation; all currently blocked by function ACL. Waiting-for-role retained. | Assigned-role summary; no full user directory/role administration. | **Broken** administration; **read-only** mobile summary. | Repair service ACL; refresh roles after authorized changes. Ban/confirmation state must come from Auth, roles from `user_roles`. |

## 4. Document management

| Requirement | React | Flutter | Preview/status | Secure missing contract / reuse |
| --- | --- | --- | --- | --- |
| Private uploads | `uploadLessonMedia` and lesson content editor upload course material. | Live lesson consumption; no general document uploader found. | **Verified lesson-only contract / partial**. | Reuse UI/file validation patterns, not bucket/path authorization for unrelated records. |
| Admission attachments | Admission data forms and printable receipts exist; no applicant attachment upload/registry. | Admission management exists; no attachment workflow. | **Missing**. | Private enquiry/student document metadata, staff scope and a separately authorized applicant upload mechanism. Tracking reference must not authorize unrestricted file reads. |
| Staff qualifications/contracts | No workflow. | None. | **Missing**. | HR document types with employee ownership, branch and reviewer permissions. |
| Certificates/academic documents | Generic proposed certificates client and print components; no real issuance/signature/revocation workflow. | Generic `sai_certificates` client, table absent. | **Backend-blocked / missing issuance**. | Document registry plus certificate issue/revoke/verify contracts, template version, authorized signer and immutable issue audit. |
| File validation | Lesson uploader checks extension, empty/max size and sends MIME; bucket has MIME/size constraints. | No general validation UI. | **Partial**, not a security scan. | Shared type/size policy; server inspection of file signatures, quarantine/scan workflow, safe names/random keys, reject executable/active content by policy. |
| Secure downloads | Lesson signed URLs via `lessonMediaUrl`, default six-hour TTL, backed by course policies. | Lesson-content retrieval is implemented; no broad document browser. | **Partial**; expiry/unauthorized access not exercised here. | Document-specific authenticated authorization before issuing short-lived URLs; redact logs/cache and avoid public bucket URLs. |
| Storage policies | Lesson SELECT/INSERT/UPDATE/DELETE policies exist. | Same backend. | **Verified metadata only**. No general document bucket/policy. | New private bucket with paths keyed to opaque document ID, server ownership lookup, verified-child and assigned-course/HR scope as appropriate. |
| Authorized deletion | Lesson save rollback can remove newly uploaded objects; not a general delete/version UI. | None for general documents. | **Partial lesson cleanup / missing lifecycle**. | Explicit authorized soft-delete/revoke, retention/legal-hold rules, idempotent object purge and orphan reconciliation. Never permit path-only delete supplied by clients. |
| Audit records | `audit_logs` and specialist audit tables exist, not document-specific lifecycle events. | No document audit UI. | **Missing document audit**. | Append-only upload/verify/download-link/replace/delete events with actor, target, outcome and timestamp; no document contents/secrets in audit payload. |

Proposed document metadata: UUID, owner kind and owner record ID, branch ID, document type, bucket/object key, original display filename, verified MIME/size/hash, scan state, created/verified/deleted actor/time, version and retention policy. Enforce real foreign-key relationships or typed association tables; a polymorphic ID without validated ownership is insufficient. Ordinary roles must not enumerate other users' metadata. Metadata + Storage updates need an explicit staged/finalized/failed lifecycle and reconciliation because they are not one database transaction.

## 5. Barcode, QR and ID management

| Requirement | React | Flutter | Backend/status | Secure missing contract / reuse |
| --- | --- | --- | --- | --- |
| Student ID card | No issuance/layout tied to a card registry. Admission receipts are not identity cards. | Generic printing, no card lifecycle. | **Missing**. | Card issue/reissue/revoke/expiry record linked to real student and opaque public verification token. |
| Employee ID card | No HR card flow. | None. | **Missing**. | Same shared card service with employee association and approved issuer scope. |
| QR/barcode generation | `qrcode.react` exists; QR attendance generates a random local six-character code. | Printing infrastructure, no verified identity barcode generator workflow. | **Partial** QR visuals; **missing** card/barcode contract. | Reuse QR renderer; choose supported barcode format only when scanner requirements are approved. Generate opaque, revocable identifiers server-side. |
| Printing | College letterhead, `PrintDoc`, admission and student report sheets. | `ui/printing.dart` provides reports/PDF/printing. | **Partial** reusable rendering; no verified card dimensions, duplex/alignment or issuance evidence. | Reuse brand/fonts/printing primitives; add approved card template and print audit, mark demo output clearly. |
| Scanning and verification | `Scanner.tsx` uses camera/image `jsQR`, parses admission references, loads/assigns authorized enquiries. | No equivalent camera ID-card scanner located. | **Partial** real admission-reference scanner; not ID authentication. | Reuse camera lifecycle/parser patterns. Add authenticated, rate-limited card verification returning minimal permitted status, no raw profile enumeration. |
| Attendance integration | `QrAttendance.tsx` imports fixtures, fixed date, local roster toggles and `SAI-ATT|class|date|code`; no backend verification. Real attendance module exists separately. | Live assigned-class/student attendance exists; no secure QR challenge redemption contract. | **Broken as real QR attendance / partial demo**. | Server-issued session challenge with cryptographic entropy, expiry/revocation, replay protection, caller/student/class checks and atomic idempotent attendance event. Preserve ordinary attendance management. |
| Safe identifiers | Admission scanner uses application references; QR simulation embeds class/date/code. | No deployed card-token model. | **Partial / missing secure identity tokens**. | Never encode email, phone, national ID, JWT, password, role claims or financial data. A QR is a lookup token, not authorization; constrain verification output and rate-limit it. |

## Delivery boundaries and acceptance

Keep the existing UI, nine-role architecture, module IDs and 32/147 catalog. Use existing identity/linking/learning/attendance/printing implementations. No new CRUD UI should claim a module works before its authorized backend contract exists. Do not assign all staff accounts to all branches by default in a future HR flow; branch access must be deliberate.

For every new backend contract require migration/RLS tests and authenticated Preview evidence for all relevant roles, multi-role combinations, direct REST/RPC calls, cross-branch/class/child denial, invalid file content, expired/replayed QR tokens, and audit correctness. Frontend/source tests alone do not verify these properties. Implementation order and current validation results are in `WEB_MOBILE_NEXT_BUILD_BACKLOG.md`.
