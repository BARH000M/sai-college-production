# V5.0 — Persistence & Schema Audit

**Institution:** Yemen SAI Educational College — كلية ساي التعليمية اليمنية الصينية — 也门赛艾教育学院
**Baseline:** Version 94
**Date:** 2026-11-21
**Supabase project:** `reprjetryjveowspusxd` (SaaS Supabase, connected)
**Scope:** Master Execution Prompt V5.0 — Task Two (persistence audit) and Task Three (schema & security audit)

This document is **read-only evidence**. No production record, RLS policy, grant or migration was
modified to produce it. It is the mandatory prerequisite before any V5.0 migration is written.

---

## 1. Why this audit exists

Version 94 delivered working screens, but several of those screens persist institutional records in
the browser. A browser is not an authoritative system of record: it is per-device, per-profile,
deletable by the user, and not covered by any RLS policy or audit trail. V5.0 must convert those
records into Supabase-backed records **without** silently uploading unverified demonstration data.

An empty `pendingModules` list and a passing production build are therefore **not** evidence of
production readiness. This audit supplies the missing evidence.

---

## 2. Browser-storage inventory

Every occurrence of `localStorage`, `sessionStorage`, `indexedDB` and the shared
`useLocalWorkspace` hook in `src/portal` is classified below.

Classification key:

| # | Class | Meaning |
|---|-------|---------|
| 1 | Interface preference | Purely cosmetic user choice. Safe to keep in the browser. |
| 2 | Cache | A copy of server truth. Safe to keep if it is never authoritative. |
| 3 | Controlled offline state | Short-lived, non-institutional, self-healing. |
| 4 | Temporary development workspace | Prototype data that must be replaced before production. |
| 5 | Institutional record | Must be permanently persisted in Supabase. |
| 6 | Security-sensitive | Must additionally be enforced server-side. |

### 2.1 Findings

| # | Module / feature | File | Mechanism | Class | Supabase equivalent | Migration required |
|---|------------------|------|-----------|-------|---------------------|--------------------|
| 1 | Active portal (multi-role switcher) | `components/AppShell.tsx` | `localStorage` `sai-portal-active-role` | 1 | none — narrowing only, never widens access | No |
| 2 | Portal language (AR/EN/ZH + direction) | `lib/portalLangContext.tsx` | `localStorage` `sai-portal-lang` | 1 | none — interface preference | No |
| 3 | Read-notification receipts | `lib/notifications.ts` | `localStorage` `…seenKey(userId)` | 2 | `notification_reads`, `announcement_reads` | No — reconcile, do not migrate |
| 4 | Receipt scanner recent list | `lib/scannerRecent.ts` | `localStorage` | 2 | none — regenerable from `fee_payments` | No |
| 5 | Report archive header presets | `lib/archiveHeader.ts` | `localStorage` | 1 | none — print preference | No |
| 6 | Pending fee payment / refund verification | `pages/Finance.tsx` | `sessionStorage` | 3 | `fee_payments`, `fee_refunds` (already authoritative) | No — but verification must stay server-side |
| 7 | **Media Library catalogue** | `pages/MediaLibrary.tsx` → `hooks/useLocalWorkspace.ts` | `localStorage` `sai.workspace.media` | **4 → 5** | **none exists** — new `sai_media_assets` + storage bucket | **Yes (Group B)** |
| 8 | **Content Review & Approvals** | `pages/ContentApprovals.tsx` → `useLocalWorkspace` | `localStorage` `sai.workspace.approvals` | **4 → 5 → 6** | **none exists** — new approval workflow tables | **Yes (Group C)** |
| 9 | **Quizzes & Assessment Delivery** | `pages/Quizzes.tsx` → `useLocalWorkspace` | `localStorage` `sai.workspace.quizzes` | **4 → 5 → 6** | **partially exists** — `learning_assessments`, `learning_assessment_attempts`, `learning_assessment_answers`, `learning_assessment_assignments` | **Yes (Group D)** |
| 10 | **Reception & Front Office** | `pages/Reception.tsx` → `useLocalWorkspace` | `localStorage` `sai.workspace.reception` | **4 → 5 → 6** | **partially exists** — `admissions_enquiries`; visitor / appointment / complaint tables **do not exist** | **Yes (Group E)** |
| 11 | Module toggles | `lib/moduleToggles.ts` | Supabase `sai_module_toggles`, `sai_module_role_overrides` | — | already authoritative | No |
| 12 | Role permission matrix | `lib/permissions.ts` | Supabase `sai_system_settings` (`access/role_permissions_matrix`) + `sai_system_settings_audit` | — | already authoritative | No |
| 13 | Sidebar layout | `lib/sidebarLayout.ts` | Supabase `sai_system_settings` (`access/sidebar_layout`) + audit | — | already authoritative (presentation only) | No |

### 2.2 Consequences

1. Rows 7–10 are the only genuine **institutional-record** gaps. Everything else is a preference or
   a cache and must **not** be migrated.
2. `useLocalWorkspace` is versioned and guard-validated, so it will not corrupt existing data — but it
   is still not a system of record, and it is the exact thing V5.0 replaces.
3. `Quizzes.tsx` currently scores attempts in the browser. That is class 6: **an answer key and a
   final score must never be computed client-side.** This is the highest-severity gap in the audit.

---

## 3. Schema & security audit (read-only)

### 3.1 Verification method

```sql
select table_name, count(*) as column_count
from information_schema.columns
where table_schema = 'public'
  and (table_name like '%media%' or table_name like '%approval%'
    or table_name like '%visitor%' or table_name like '%reception%'
    or table_name like '%enquir%' or table_name like '%quiz%'
    or table_name like '%assessment%' or table_name like '%audit%'
    or table_name like 'sai_system_settings%')
group by table_name order by table_name;
```

### 3.2 Result

| Table | Columns | Reuse decision |
|-------|---------|----------------|
| `admissions_enquiries` | 18 | **Reuse.** Already holds enquiry identity, source, status, assignment, follow-up timestamps. |
| `learning_assessments` | 19 | **Reuse.** Quiz header. |
| `learning_assessment_attempts` | 12 | **Reuse.** Attempt, score, question order, timers. |
| `learning_assessment_answers` | 10 | **Reuse.** Per-question response, correctness, points, feedback, grader. |
| `learning_assessment_assignments` | 4 | **Reuse.** Student eligibility. |
| `sai_system_settings` | 7 | **Reuse.** Settings store for permissions + sidebar layout. |
| `sai_system_settings_audit` | 6 | **Reuse.** Settings audit trail. |
| `audit_logs` | 7 | **Reuse.** Global audit. |
| `finance_audit_log` | 7 | **Reuse (finance only).** |

**Confirmed absent** — no media, approval, visitor, appointment or complaint tables exist. Therefore
Groups B, C and E require **additive** migrations only; Groups D and F must extend the existing
assessment contract instead of duplicating it.

### 3.3 Reusable column contract (excerpt)

`admissions_enquiries`: `id`, `branch_id`, `academic_session_id`, `application_no`,
`applicant_full_name`, `guardian_name`, `phone`, `email`, `preferred_program`, `preferred_level`,
`source`, `notes`, `status`, `assigned_to`, `created_by`, `created_at`, `updated_at`, `closed_at`.

`learning_assessments`: `id`, `course_id`, `lesson_id`, `class_id`, `academic_session_id`, `title`, … (19 columns).

`learning_assessment_attempts`: `id`, `assessment_id`, `student_id`, `attempt_number`, `status`,
`score`, `max_score`, `question_order`, `started_at`, `expires_at`, `submitted_at`, `graded_at`.

`learning_assessment_answers`: `id`, `attempt_id`, `question_id`, `answer` (jsonb), `is_correct`,
`points_awarded`, `is_graded`, `feedback`, `graded_by`, `graded_at`.

> ⚠️ `learning_assessment_answers.points_awarded` and `attempts.score` are **writable by any role
> granted table write access**. Group D must move scoring behind a `SECURITY DEFINER` RPC and revoke
> direct `insert/update` on those columns from student roles.

---

## 4. Proposed migration groups (not yet applied)

Each group is additive, independently reversible and requires explicit authorisation.

| Group | Purpose | Reuses | Adds | Security impact |
|-------|---------|--------|------|-----------------|
| **A** | Shared authorization & persistence helpers | `sai_system_settings`, `audit_logs` | `sai_audit_emit()` helper | Central audit writer; no RLS relaxation |
| **B** | Media metadata + storage | — | `sai_media_assets`, `sai_media_links`, `media` bucket + policies | Private bucket, signed URLs, course/branch scoping |
| **C** | Content approval workflow | — | `sai_content_reviews`, `sai_content_review_events` | State machine enforced by trigger; self-approval blocked |
| **D** | Quizzes & protected grading | `learning_assessments*` | `sai_quiz_questions`, `sai_quiz_grading` RPC | Revokes answer-key reads and score writes from students |
| **E** | Reception & front office | `admissions_enquiries` | `sai_visitors`, `sai_appointments`, `sai_complaints` | Branch-scoped RLS; receptionist cannot approve admissions |
| **F** | Learning progress gaps | `learning_lesson_progress`, `learning_vocab_progress` | review scheduling columns + RPC | Prevents client-side achievement forgery |
| **G** | Indexes, integrity & verification | all above | indexes, constraints, verification queries | Non-destructive |

### 4.1 Required safeguards for every group

- No `drop table`, no data deletion, no database reset.
- RLS remains **enabled** on every new table; no unrestricted grants.
- Service-role credentials never leave the edge function runtime.
- No platform-wide write hold, no maintenance mode.
- Every group ships with verification queries and a rollback procedure.
- Existing workspace records are **not** auto-uploaded; any migration of demonstration data needs a
  separate, reviewed and auditable procedure.

---

## 5. Status

| Task | Status |
|------|--------|
| Task Two — persistence audit | **Complete** (this document) |
| Task Three — schema & security audit | **Complete** for the in-scope tables |
| Group A — shared audit writer | **Applied & verified** (`public.sai_write_audit`, SECURITY INVOKER) |
| Group B — Media Library persistence | **Applied & verified** (`sai_media_assets`, private `media` bucket, 6 policies) |
| Group D — Quiz & protected grading | **Applied & verified** (`sai_quiz_public_questions`, `sai_quiz_grade_attempt`, score guard trigger) |
| Group C — Content approval workflow | **Authorised, not yet applied** |
| Group E — Reception & front office | **Authorised, not yet applied** |
| Frontend rewiring of Media / Approvals / Quizzes / Reception | **Not started** — screens still use `useLocalWorkspace` |
| Tasks Eight–Sixteen | Not started |

### 4.2 Applied migrations

| File | Group |
|------|-------|
| `supabase/migrations/20261121120000_v5_group_a_b_media_assets_and_audit.sql` | A + B |
| `supabase/migrations/20261121121000_v5_group_d_quiz_grading.sql` | D |

### 4.3 Environment constraint discovered

`GRANT` / `REVOKE` statements are rejected by the execution guard. Consequently no new privilege is
tightened by explicit grant; security is enforced **only** through RLS policies, SECURITY INVOKER
functions and guard triggers. This is recorded so a future review does not assume a GRANT exists.