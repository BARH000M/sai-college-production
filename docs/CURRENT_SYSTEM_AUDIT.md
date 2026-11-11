# CURRENT SYSTEM AUDIT
### Yemen SAI Educational College — Phase 0 read-only inspection report

**Date:** 2026-11-09 · **Backend:** Supabase `aeryusbrulqdxjdynwfh` · **Deprecated:** `tvkohamtxrkppwcfsuex` (untouched)
**Code changed in this phase:** none · **Database changed in this phase:** none

---

## 1. Architecture as actually built

### 1.1 Web

| Layer | Reality |
|---|---|
| Framework | React 19 + TypeScript + Vite SPA |
| Routing | Two-level: `src/router/config.tsx` exposes `/`, `/application-status`, `/auth`, `/portal/*`; `src/portal/AppRoot.tsx` is a **nested** `Routes` block for `/portal` |
| Module routing | `pages/ModuleEntry.tsx` is a **switch on `moduleId`**, not a route table. 30 module ids resolve to components through `if` chains |
| Shell | `components/AppShell.tsx` (sidebar + header) with a single global `styles.css` design system |
| Auth | `lib/auth.ts` — Supabase email/password, persisted session, `profiles` + `user_roles` load on boot, `subscribeToAuthChanges` |
| Guard | `AppRoot.protectedPage()` — loading → signed-out redirect → profile error → no-role `WaitingForRole` → shell. A **real route guard**, applied per route |
| Data | 35 files under `lib/`; 15 call `supabase.from(...)` directly, 7 call `supabase.rpc(...)` or edge functions |
| Functions | 7 deployed: `manage-roles`, `provision-learning-account`, `link-student-account`, `admission-notify`, `admission-reminders`, `announcement-email`, admissions bundle |
| Print | `lib/printDocument.ts`, `components/PrintLetterhead.tsx`, 5 printable sheets |
| i18n | `src/i18n` used by the **public site** only; the portal is Arabic-only hard-coded |
| Styling | Cairo bundled locally (`portal/assets/Cairo-*.ttf`), RTL by layout, no runtime direction switching |

### 1.2 Mobile (Flutter)

| Layer | Reality |
|---|---|
| Entry | `mobile/lib/main.dart` → Supabase init from `--dart-define` → `AuthGate` |
| Shells | **Two navigation shells exist.** `features/home/app_shell.dart` (primary, used by `AuthGate`) and `screens/shell.dart` (imported in `main.dart` as `alternate`) |
| Navigation | `core/app_nav.dart` (14 slots, per-role bottom bar) + `core/feature_catalog.dart` (32 modules with tabs) |
| Screens | `features/*` — 9 real workflows; `screens/*` — a second parallel set of 14 screens built on the new design system |
| Module fallback | `features/modules/module_page.dart` renders a "شاشة تأسيسية" placeholder for every module it does not special-case (only `students` and `vocabulary` are special-cased) |
| Design system | `mobile/lib/design_system/` — theme tokens, typography, `SaiCard`, `SaiPageScaffold`, `SaiListTile`, `SaiMetricCard`, `SaiAsyncState`, plus a barrel export |
| Tests | `mobile/test/**` — 47 tests passing, `flutter analyze --fatal-infos --fatal-warnings` clean (user-verified) |
| CI | `.github/workflows/mobile-ci.yml` — analyze with fatal infos + test on every push/PR touching `mobile/` |

**Finding A1 (High).** Two parallel navigation shells and two parallel screen sets mean two places to
maintain, two visual languages and a real risk of a feature landing in one and not the other. This
predates the design-system migration and should be resolved by retiring `screens/shell.dart` in
favour of `features/home/app_shell.dart`.

---

## 2. Authentication, session and roles

| Concern | Implementation | Assessment |
|---|---|---|
| Sign-in | `supabase.auth.signInWithPassword` via `lib/auth.ts` and `/auth` page | Real |
| Session restore | `restoreAuthState()` on boot, `subscribeToAuthChanges` | Real; listener correctly does not await DB calls |
| Sign-out | `signOut()` with error surfaced | Real |
| Password recovery | `features/auth/password_recovery_page.dart` → `updateUser(password:)` | Real (mobile only); no web recovery page |
| Role source | `user_roles` (enum `app_role`) | Real |
| Multi-role | `AppRoot` passes `auth.roles[]`; mobile `AppShell` shows a role switcher when `roles.length > 1` | Real on both clients |
| Role grant/revoke | `manage-roles` edge function only; `Roles.tsx` never writes tables directly | Real and correctly centralised |
| Role vocabulary | 9 roles identical in DB enum, `navigation.ts`, `roles.ts`, `app_role.dart` | Consistent |
| Permission checks | Web: per-module `item.roles` array in `navigation.ts`; mobile: `feature_catalog.dart` role list + ad-hoc `const {...}.contains()` sets | **Client-side only** — see S1 |

### Finding S1 (High, security) — navigation is the only per-module gate on web

`ModuleEntry.tsx` checks `item.roles.some(role => roles.includes(role))` and then renders the
component. That check is **client-side**; the real protection is Supabase RLS. Acceptable *only* if
every table has a correct policy. Migrations 002–028 exist for this and
`docs/WAVE-1-SECURITY-REVIEW.md` records prior audit work, but a table-by-table RLS assertion
covering **all 36 tables** is not present in this workspace and is therefore `NOT_VERIFIED`.

### Finding S2 (Medium) — no job-title layer

The brief asks for inventory officer / transport officer / admissions officer / branch manager to
exist as **job titles with explicit permission grants**, not as administrative roles. Only the 9-role
enum exists today. There is no `job_title` column and no granular permission table.

---

## 3. Database objects vs. screens

36 `public` tables. Mapping to UI:

| Table | UI that uses it | Orphan? |
|---|---|---|
| `profiles`, `user_roles` | `/portal/profile`, `/portal/modules/roles`, auth | bridged |
| `branches`, `academic_sessions`, `branch_memberships` | `/portal/modules/branches`, `/sessions`, dashboards | bridged |
| `classes`, `students` | `/portal/modules/classes`, `/students` | bridged |
| `parent_student_links` | `StudentAccountLink.tsx`, mobile parent link | bridged |
| `admissions_enquiries`, `admission_reminder_runs`, `admission_reminder_log` | `/portal/modules/admissions` | bridged (reminder runs: no screen) |
| `attendance_sessions`, `attendance_records` | `/portal/modules/attendance`, mobile register | bridged |
| `learning_courses`, `learning_lessons`, `learning_lesson_progress` | `/portal/modules/courses`, `/progress` | bridged |
| `learning_homework`, `learning_homework_submissions` | `/portal/modules/homework` | bridged |
| `learning_vocabulary`, `learning_vocab_progress` | `/portal/modules/vocabulary`, `/review` | bridged |
| `learning_inbox_reads` | `lib/notifications.ts` | bridged |
| `library_items`, `library_loans` | `/portal/modules/library` | bridged |
| `announcements`, `announcement_reads`, `announcement_deliveries` | `/portal/modules/communications` | bridged |
| `notification_reads` | `/portal/modules/notifications` | bridged |
| `fee_groups`, `fee_assignments`, `fee_payments`, `fee_waivers`, `fee_refunds`, `finance_audit_log` | `/portal/modules/finance` (via `sai_*` RPCs) | bridged |
| `cms_site_content`, `cms_programs`, `cms_news` | `/portal/modules/cms` + public site | bridged |
| `audit_logs` | `lib/dashboard.ts` summary only | **partially orphaned** — no browsable screen |

**Finding D1 (Low).** No table exists without *some* reader. There is no hidden orphan data.

**Finding D2 (Critical).** The inverse is the real problem: **12 modules have no table at all** —
exams/questions/results, certificates, staff/leave/payroll, inventory, income/expense, behaviour,
visitors/calls/postal/complaints, timetable, lesson plans, alumni, downloads. Those modules cannot be
"made consistent" by UI work; they need approved schema first.

---

## 4. Web ↔ mobile parity matrix

Legend: **Both** = real on both clients · **Web** = real web only · **Mob** = real mobile only ·
**Static** = sample data · **None** = neither.

| Capability | Web | Mobile | Gap |
|---|---|---|---|
| Sign-in / session / multi-role | Real | Real | parity OK |
| Password recovery | None | Real | web missing |
| Role dashboard | Real (4 per-role variants) | Real (greeting + shortcuts, no live stats) | mobile has no live KPIs |
| Students list / create / edit | Real | Real (read + import) | mobile cannot edit a student |
| Student transfer | None | Real | web missing |
| CSV student import | None | Real | web missing |
| Parent ↔ child linking | Real | Real | parity OK |
| Classes / seats / occupancy | Real | Real | parity OK |
| Class roster + monthly attendance | Real (`Reports`) | Real (`class_roster_sheet`) | parity OK |
| Attendance register | Real | Real | parity OK |
| Admissions | Real | **Placeholder** | mobile missing |
| Finance | Real (full ledger) | **Placeholder** | mobile missing |
| Library | Real | **Placeholder** | mobile missing |
| Courses / lessons | Real | **Placeholder** | mobile missing |
| Homework | Real (create + grade) | **Placeholder** | mobile missing |
| Progress | Real | **Placeholder** | mobile missing |
| Vocabulary | Real | Real (read) | mobile read-only |
| Notifications | Real | Real (derived feed) | parity OK |
| Announcements | Real | **Placeholder** | mobile missing |
| CMS | Real | None (correctly excluded) | n/a |
| Roles / permissions | Real (grant/revoke) | Read-only by design | correct |
| Reports | Real | **Placeholder** | mobile missing |
| Timetable | Static | **Placeholder** | both missing |
| QR attendance | Static | **Placeholder** | both missing |
| Chinese labs (5 of 6) | Static | **Placeholder** | both missing |
| Branches / sessions admin | Real | Not in catalog | mobile missing |

**Finding P1 (Critical for the parity mandate).** Of the 12 areas the brief lists as *required* for
student, parent and teacher, **6 exist on mobile only as placeholders**: courses, lessons, homework,
exams, progress, announcements. The mobile app is currently a strong *administration* client and a
weak *learning* client — the opposite of the brief's emphasis.

---

## 5. What is genuinely finished vs. what looks finished

### 5.1 Reference-quality workflows (the standard everything else should meet)

1. **Finance** — `sai_finance_*` RPCs, idempotency key on payments, void/refund with reason,
   `finance_audit_log`, decimal normalisation (`normalizeYER`), paginated RPC reads with count
   consistency checks.
2. **Attendance** — session open/close, per-student upsert, class-scoped; mobile register mirrors it.
3. **Library** — catalogue, issue, return, overdue sheet, per-student history, printable slip.
4. **RBAC** — every write goes through one audited edge function; the client never touches `user_roles`.
5. **CMS** — three tables, ordered, publish/delete with optimistic checks; the public site consumes
   the same rows.

### 5.2 Screens that render convincingly but write nothing

`Timetable`, `AcademicAffairs`, `QrAttendance`, `Scanner`, `ListeningLab`, `SpeakingLab`, `TonesLab`,
`HandwritingLab`, `ReadingLab`. All nine import `@/mocks/**` or hold local state only. They are
`UI_ONLY`.

**Finding U1 (High).** `QrAttendance` presents a roster and a scanning surface. A user can reasonably
conclude attendance is being recorded. It is not. This is the most misleading screen in the product
and should either be wired to `attendance_sessions`/`attendance_records` with a token table, or
plainly labelled as a preview.

### 5.3 Deliberately hidden modules

`navigation.ts` maintains `availableModuleIds` (30 ids) and `pendingModules` (9 ids with a written
reason). A module outside `availableModuleIds` is reachable nowhere: not the sidebar, not the mobile
bar, not search, not the role dashboard. This is a **good** pattern and should be preserved.

---

## 6. Design and UX state

| Requirement | State |
|---|---|
| Cairo typography | Met on both clients (bundled TTFs, not CDN) |
| Arabic RTL | Met by layout; `dir` is not toggled at runtime |
| English LTR | `PARTIALLY_IMPLEMENTED` — public site only |
| Chinese support | `MISSING` as a UI locale (Hanzi appears as content, not as a language) |
| Modern university dashboard | Met on web; mobile dashboard has no real KPIs |
| Role-specific dashboards | Met on web (4 home variants); mobile has one generic home |
| Persistent selectors (session / branch) | Web: per-screen `<fieldset className="context-card">`, **not global**. Mobile: none |
| Mobile bottom navigation | Met (`NavigationBar`, per-role slots) |
| Mobile drawer for secondary modules | Met (`sai_drawer.dart`) |
| No miniature desktop sidebar on mobile | Met |
| Loading / empty / error + retry | Met — `SaiAsyncState` + `StatusCard` are consistent |
| Accessibility | `NOT_VERIFIED` — no audit performed |

**Finding X1 (Medium).** Academic session and branch are chosen **per screen**, not once per
session. A user who switches class on `/students` still sees the old branch on `/attendance`. The
brief requires session/branch scoping as global context.

---

## 7. Security posture — what can and cannot be asserted

### Assertable from this inspection

- No service-role key exists anywhere in frontend or mobile source. Only the anon key at build time
  (`VITE_PUBLIC_SUPABASE_ANON_KEY`, `--dart-define=SUPABASE_ANON_KEY`).
- All privileged operations route through edge functions (`manage-roles`,
  `provision-learning-account`, `link-student-account`, finance RPCs).
- Finance writes are append-only with an audit log and a void path rather than destructive updates.
- A public user cannot assign themselves a role: the client has no write path to `user_roles`, and
  the only writer is a JWT-verified function.
- Parent access to children is mediated by `parent_student_links` with a `verified_at` gate, checked
  on both clients.
- `docs/SECURITY-RPC-AUDIT.md` and `docs/WAVE-1-SECURITY-REVIEW.md` record a prior review that
  revoked `sai_set_role` (migration 024) and retired finance oracles (migration 028).

### Not assertable — must not be claimed

- **Per-table RLS correctness across all 36 tables** — `NOT_VERIFIED` in this phase.
- **Cross-role isolation at runtime** (student reading staff rows, a parent reading another family's
  child) — `NOT_VERIFIED`; requires negative tests against the live project.
- **Branch isolation** for every module — policies exist for classes/students/attendance; not proven
  for library, CMS, announcements or the finance report paths.
- **Audit-log tamper resistance** — `NEXT-MODULE-PLAN.md` already flags that authenticated clients
  can submit audit entries imitating trigger metadata. Unresolved.
- **Resend email delivery** — domain not configured, so the email path is `BROKEN` in practice
  regardless of code quality.

---

## 8. Test coverage reality

| Suite | Count | What it proves |
|---|---|---|
| `mobile/test/**` | 47 tests, passing | Role resolution, navigation composition, config parsing, access rules, design-system widgets, class form sheet |
| `web/tests/*.cjs` | 7 suites | Admissions, attendance, finance, finance-api, management, navigation, startup — **pure-logic node tests**, not live DB tests |
| `supabase/tests/*.sql` | 6 SQL suites + 2 runners | Behaviour tests for admissions, attendance, finance, management, write paths, security invariants |
| `prototype/.../tests/` | 26 checks | Prototype only — not production evidence |

**Finding T1 (High).** There is **no web component test** and **no test that exercises a real
Supabase round trip**. `npm run test:management:db` exists but, per `NEXT-MODULE-PLAN.md`, has never
run against an isolated environment. That security gate is still open.

---

## 9. Top findings, ranked

| ID | Finding | Severity | Evidence |
|---|---|---|---|
| D2 | 12 modules have no database schema at all, including the whole examinations domain | Critical | Table inventory vs. `pendingModules` |
| P1 | Mobile learning experience is placeholder for courses, lessons, homework, progress, announcements | Critical | `module_page.dart` special-cases only `students` + `vocabulary` |
| U1 | `QrAttendance` and `Scanner` look operational but write nothing | High | `@/mocks/academics` import, no write path |
| S1 | Per-module authorization is client-side; RLS completeness unproven for all 36 tables | High | `ModuleEntry.tsx` role check |
| T1 | No DB round-trip test, no web component test; management gate never run | High | `NEXT-MODULE-PLAN.md` |
| A1 | Two parallel mobile shells / screen sets | High | `main.dart` imports `screens/shell.dart as alternate` |
| X1 | Session + branch are per-screen, not global context | Medium | `context-card` fieldsets |
| S2 | No job-title / granular permission layer | Medium | 9-role enum only |
| D1' | `audit_logs` has no browsable screen | Medium | only aggregated in `dashboard.ts` |
| C1 | Resend domain unverified — all email non-functional | Medium | provider status |
| R1 | Reports cover roster/attendance/learning only; no finance, HR or library reports | Medium | `lib/reports.ts` |
| P2 | Timetable/calendar static on both clients | Medium | `@/mocks/academics` |
| I1 | Inventory, behaviour, alumni, downloads entirely absent | Low (scope) | no tables, no routes |

---

## 10. Phase 0 conclusion

The system is **substantially real, not a mock-up**. Eleven operational areas complete a genuine
round trip to Supabase with audit trails: admissions, classes, sessions, branches, students,
attendance, finance, library, announcements, learning (courses/homework/vocabulary), CMS and RBAC.

The gaps cluster into three kinds, and they need different treatment:

1. **Schema-first gaps** (exams, HR operations, inventory, income/expenses, behaviour, front-office
   registers). UI work here would be theatre. They need approved migrations, RLS design and security
   review before a single screen is built.
2. **Wiring gaps** (timetable, calendar, QR attendance, five learning labs, scanner). The screens
   exist and are well built; they need tables and repositories, not redesign.
3. **Parity gaps** (mobile placeholders for admissions, finance, library, courses, homework,
   progress, announcements). The web logic already exists and can be ported behind the same RLS.

**No code was changed. No database object was created, altered or dropped. No deployment occurred.**

The next phase produces the structured gap matrix, role-permission matrix, web/mobile parity matrix
and database/API gap report, then stops at the approval gate before any implementation.