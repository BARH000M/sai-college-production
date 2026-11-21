# V4.0 — Functional Completion & Production Readiness

**Institution:** Yemen SAI Educational College (كلية ساي التعليمية اليمنية الصينية)
**Date:** 2026-11-21
**Baseline:** Version 93 preserved and extended.

## 1. Scope delivered in this increment

The four modules that were previously disabled are now built, wired and reachable
through the unified portal:

| Module | Page id | Main module | Approved roles |
| --- | --- | --- | --- |
| Media Library | `media` | `content-studio` | super_admin, admin, content_editor, teacher |
| Content Review & Approvals | `approvals` | `content-studio` | super_admin, admin, content_editor, teacher |
| Quizzes & Assessment Delivery | `quizzes` | `homework` | super_admin, admin, teacher, student, content_editor |
| Reception & Front Office | `reception` | `front-office` | super_admin, admin, receptionist |

`pendingModules` is now empty; the sidebar, module directory, search and control
centre no longer treat any screen as "awaiting foundation".

## 2. What each module contains

### Media Library
Catalogue with type filters (image / audio / video / document), category and
course association, search, usage tracking, detail preview, archiving (never
hard-delete for published references), and a validated upload form (size, type,
bilingual titles). Categories tab reports active files and lesson links per
category.

### Content Review & Approvals
Deterministic editorial workflow: `draft → submitted → (changes_requested | approved | rejected) → published → archived`.
Includes reviewer assignment, review comments, valid-transition enforcement,
self-approval blocking under institutional policy, and a per-item status history.

### Quizzes & Assessment Delivery
Question bank across eight types (multiple choice, true/false, matching,
fill-in-the-blank, pinyin, character recognition, listening, reading), quiz
management with publish/unpublish, a student delivery screen that never renders
the answer key, attempt-limit enforcement, automatic grading with pass threshold,
and a results / attempt-history table.

### Reception & Front Office
Admission enquiry register with duplicate-phone detection, follow-up log,
assignment, and conversion to an admission request; visitor book with check-in /
check-out; appointment scheduling with completion/cancellation; and a complaint
register with severity and resolution.

## 3. Architecture notes

- All four screens reuse the shared portal design tokens (`primary`, `accent`,
  `secondary`, `background`, `foreground` scales) and the `LabPage` / `LabTabs`
  / `LabStats` shell for consistent spacing, RTL and typography.
- Workspace state is persisted through a single versioned hook
  (`src/portal/hooks/useLocalWorkspace.ts`). The store is namespaced and
  guard-validated, so a malformed payload can never crash a screen.
- New styles live in `src/portal/components/workspace-modules.css`, imported by
  the portal root.

## 4. Security position

- Frontend visibility remains a UI hint only. These workspaces do not grant
  database access; row-level security and the existing RPC contracts continue to
  govern data.
- The quiz delivery screen deliberately does **not** expose correct answers; the
  approved migration moves the answer key and grading to a protected RPC.
- Content self-approval is blocked by institutional policy flag.
- Reception never exposes financial, payroll, examination-answer or confidential
  staff data.

## 5. Verification

- Production build: **passing**.
- Added `web/tests/workspace-modules.test.cjs` (screen exports, routing,
  navigation availability, style import, duplicate-phone normalisation,
  self-approval blocking, answer-key non-exposure).
- Updated `web/tests/portal-registry.test.cjs` to assert the four modules are
  reachable for their approved roles and no longer pending.

## 6. Outstanding external dependencies

- **GitHub synchronisation** and **production publish** require explicit
  authorisation in this environment and were not executed automatically.
- Media binary storage, editorial persistence and reception registers are
  presented as an operational workspace pending the reviewed Supabase migration;
  the UI and data contracts are in place for that migration.