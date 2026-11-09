# SAI College Mobile — Architecture Baseline & Migration Plan

Status: **inspection + comparison complete. No application code changed.**
Baseline date: 2026-11-09
App root: `D:\SAI-College-Production\mobile`
Designated backend: `https://aeryusbrulqdxjdynwfh.supabase.co`

---

## 0. Rules of engagement (fixed)

These are taken as binding for every stage that follows.

1. `mobile/` and its working functionality are preserved — nothing is rewritten that already works.
2. The ten approved screen designs remain the visual reference (cream `#FBF6EA`, maroon `#8E1116`, gold `#C9A24B`, Cairo).
3. Inspect screens, widgets, models, repositories, routes and tests **before** changing anything.
4. New functionality lands inside the feature-based architecture, not in ad-hoc files.
5. All nine roles are supported, including multi-role accounts.
6. Supabase is the only backend of record.
7. A migration file or a UI screen is **not** proof a workflow exists. Only a verified round-trip counts.
8. Production-ready requires `flutter analyze` + `flutter test` + `flutter build` to pass.
9. Existing Android and iOS project configuration is kept as-is; no regeneration.

---

## 1. Current state — factual inventory

`mobile/lib` contains **38 Dart files**. There is **no `mobile/test/` directory** (the tests under
`prototype/reference-source/previous-flutter-app/mobile/test` belong to the archived predecessor, not to this app).

### 1.1 File-by-file

| File | Responsibility | Working state |
|---|---|---|
| `main.dart` | Supabase init from `--dart-define`, RTL/MaterialApp, `AuthGate` | **Working** |
| `core/app_identity.dart` | `AppIdentity` value object (userId, name, email, roles) | Working |
| `core/app_role.dart` | 9-role enum, DB value mapping, Arabic labels, parser | Working |
| `core/app_nav.dart` | 14 nav slots + per-role bottom-bar composition | Working |
| `core/auth_gate.dart` | Session lifecycle, identity load, recovery state, retry | Working |
| `core/auth_repository.dart` | sign-in / reset / sign-out / `loadIdentity` (profiles + user_roles) | Working |
| `core/feature_catalog.dart` | **32** `FeatureModule` records: id, label, pillar, allowed roles, tabs | Data only — drives navigation, not screens |
| `core/sai_theme.dart` | Theme + `SaiColors` palette | Working |
| `features/auth/login_page.dart` | Real `signInWithPassword`, error mapping, reset request | **Working** |
| `features/auth/password_recovery_page.dart` | `updateUser(password:)` | **Working** |
| `features/home/app_shell.dart` | Drawer + role switcher + bottom nav + `IndexedStack` | **Working** |
| `features/home/home_page.dart` | Greeting + per-role shortcuts | Working (no live stats) |
| `features/academics/classes_seats_page.dart` | Reads `classes`, `students`, `branches`, `academic_sessions`; seats/occupancy | **Working** |
| `features/academics/class_form_sheet.dart` | INSERT/UPDATE `classes` with branch/session/teacher pickers | **Working (write)** |
| `features/academics/class_models.dart` | `SaiClass` + occupancy maths | Working |
| `features/academics/class_roster_sheet.dart` | Roster + monthly attendance from `attendance_records` | **Working (read)** |
| `features/academics/class_roster_export.dart` | Letterhead text export (clipboard) | Working |
| `features/academics/student_transfer_page.dart` | Bulk `students.class_id` UPDATE with live capacity re-check | **Working (write)** |
| `features/academics/student_transfer_widgets.dart` | Picker widgets | Working |
| `features/academics/teacher_directory.dart` | Teacher list via `provision-learning-account` edge function | **Working** |
| `features/attendance/class_register_page.dart` | Creates `attendance_sessions`, upserts `attendance_records`, closes session | **Working (write)** |
| `features/students/student_records_page.dart` | Student/parent scoped reads of `students` | **Working (read)** |
| `features/students/student_stats.dart` | Aggregates attendance / scores / lesson progress / news | **Working (read)** |
| `features/students/my_profile_page.dart` | Own record + metrics | **Working** |
| `features/students/my_children_page.dart` | Verified `parent_student_links` children + metrics | **Working** |
| `features/students/student_import_page.dart` | Bulk INSERT `students` with validation preview | **Working (write)** |
| `features/students/parent_link_page.dart` | INSERT `parent_student_links` (`verified_at`) | **Working (write)** |
| `features/learning/vocabulary_bank_page.dart` | `learning_vocabulary` + `learning_lessons` + progress | **Working (read)** |
| `features/notifications/notifications_page.dart` | Derived feed from enquiries / submissions / attendance | **Working (read)** |
| `features/roles/roles_permissions_page.dart` | `user_roles` + `profiles`, conflict detection | Read-only by design |
| `features/account/account_page.dart` | Account + roles + sign out | Working, currently unreferenced |
| `features/modules/module_page.dart` | **Generic placeholder** for every module it does not special-case | **Placeholder** |
| `features/modules/modules_page.dart` | Grouped module directory | Working |
| `features/modules/status_page.dart` | "No access" state | Working |
| `widgets/sai_app_bar.dart`, `sai_drawer.dart`, `section_header.dart`, `metric_tile.dart`, `state_views.dart` | Shared chrome | Working |

### 1.2 What that actually means

**9 real workflows exist and are wired to Supabase:** login, password recovery, class directory,
class create/edit, class roster, student transfer, attendance register, student import, parent link.
Read paths exist for: own profile, children, student records, vocabulary, notifications, roles.

**Everything else resolves to one placeholder.** `ModulePage` renders a "شاشة تأسيسية" card plus a
list of tab names that do not navigate. This is the single largest gap and it covers:

`admissions · academics · timetable · qr · courses · listening · speaking · tones ·
handwriting · reading · review · homework · quizzes · exams · certificates · progress ·
authoring · media · approvals · finance · staff · reception · library · communications ·
branches · reports · cms · settings`

That is 28 of 32 catalog modules.

### 1.3 Structural gap vs. the approved architecture

| Target | Exists today |
|---|---|
| `lib/app/` (app, router, navigation, bootstrap) | ❌ navigation lives in `core/app_nav.dart` + `features/home/app_shell.dart` |
| `lib/core/config/` | ❌ |
| `lib/core/supabase/` | ❌ (client read inline as `Supabase.instance.client` in ~14 files) |
| `lib/core/security/` | ❌ permission checks are ad-hoc `const {...}.contains(...)` in each page |
| `lib/core/errors/` | ❌ only `IdentityLoadException` |
| `lib/core/localization/` | ❌ strings are hard-coded Arabic |
| `lib/core/sync/` | ❌ |
| `lib/design_system/` | ❌ `core/sai_theme.dart` + `lib/widgets/` |
| `lib/features/<f>/{screens,widgets,models,repositories,controllers}` | ❌ flat `features/<f>/*.dart` |
| `mobile/test/` | ❌ does not exist |

**Honest conclusion:** the approved tree is a target, not a description. Today's code is a working
vertical slice with a shared `core`, a shared `widgets`, and flat feature folders.

---

## 2. Role model — source of truth

Nine roles, confirmed: `super_admin, admin, teacher, accountant, receptionist, librarian, student,
parent, content_editor` (`core/app_role.dart`).

| Concern | Authoritative source | Enforced by |
|---|---|---|
| Which roles an account holds | `user_roles` | RLS on `user_roles` |
| Branch scope | `branch_memberships` | RLS policies using branch helpers |
| Parent ↔ child | `parent_student_links` where `verified_at is not null` | RLS |
| Student ↔ login | `students.user_id` | RLS |
| Multi-role UI | union of `navSlotsFor(role)` and `modulesForRole(role)` | client, but backed by the above |

**Multi-role behaviour today:** `AuthGate` loads all roles; `AppShell` shows a role switcher when
`identity.roles.length > 1` and re-composes nav per active role. This already satisfies "union of
permitted modules" — but only for modules that have real screens.

**Open finding carried from the security work:** `roles_permissions_page` is deliberately read-only
and defers writes to the web portal + `manage-roles` edge function. That must stay true — the mobile
app must not grow a second role-management path.

---

## 3. Screen inventory × role matrix

Legend: **R** = real data + real actions · **r** = reads real data, no write · **P** = placeholder.

| # | Module | super_admin | admin | teacher | accountant | receptionist | librarian | student | parent | content_editor |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Authentication | R | R | R | R | R | R | R | R | R |
| 2 | Dashboard / home | r | r | r | r | r | r | r | r | r |
| 3 | Module directory | R | R | R | R | R | R | R | R | R |
| 4 | Students | R | R | r | — | R | — | r | r | — |
| 5 | Classes | R | R | r | — | r | — | — | — | — |
| 6 | Attendance | R | R | R | — | R | — | — | r | — |
| 7 | Admissions | P | P | — | — | P | — | — | — | — |
| 8 | Finance | P | P | — | P | — | — | P | P | — |
| 9 | Library | P | P | — | — | — | P | P | P | — |
| 10 | Courses & lessons | P | P | P | — | — | — | P | P | P |
| 11 | Chinese learning labs | P | P | P | — | — | — | P | — | P |
| 12 | Homework | P | P | P | — | — | — | P | P | — |
| 13 | Progress / reports | P | P | P | P | P | P | P | P | P |
| 14 | Staff | P | P | P | P | P | P | — | — | P |
| 15 | Content / CMS | P | P | P | — | — | — | — | — | P |
| 16 | Communications | P | P | P | P | P | P | P | P | P |
| 17 | Administration (branches, sessions, roles) | r | r | — | — | — | — | — | — | — |
| 18 | Settings / profile menu | r | r | r | r | r | r | r | r | r |

Role sets above are transcribed from `core/feature_catalog.dart`, which is the current client-side
declaration. **The database remains authoritative** — any matrix change must be mirrored in RLS, not
just in this table.

---

## 4. The functional contract (applies to every screen)

A screen is "functional" only when all eight hold:

1. Loads authorised data from Supabase — no invented numbers.
2. Scopes by branch and academic session where the domain requires it.
3. Shows real state (counts, occupancy, balances) computed from rows, not constants.
4. Offers the actions its role permits, and hides/disables the rest.
5. Handles **loading / empty / error+retry** distinctly (`LoadingState`, `EmptyState`, `ErrorState`).
6. Produces a document where the mockup implies one (roster, receipt, report).
7. Is protected by RLS, not only by a hidden button.
8. Has a test that fails if the workflow regresses.

`classes_seats_page`, `class_register_page` and `class_roster_sheet` already meet this bar end-to-end.
They are the reference implementation for everything that follows.

---

## 5. Phased migration plan

Ordering is dependency-first. Each phase is independently shippable and independently verifiable.

### Phase 0 — Foundation (no behaviour change) · ~1 stage
Create the skeleton that later phases hang from, **additively** — no existing file is moved yet:

- `core/config/app_config.dart` — single place for the Supabase URL and the `--dart-define` override.
- `core/supabase/supabase_client.dart` — one accessor replacing the ~14 inline `Supabase.instance.client` reads.
- `core/security/permissions.dart` — `canManageClasses`, `canMarkAttendance`, `canManageStudents`, … 
  derived from `AppIdentity.roles`, replacing the ad-hoc `const {...}` sets in `classes_seats_page` and `app_shell`.
- `core/errors/app_exception.dart` — one error type with an Arabic user message + a log-safe detail.
- `design_system/theme/sai_theme.dart` — re-export of the existing theme so `design_system/` becomes real
  without duplicating colour values.
- `app/navigation/role_navigation.dart` — move `navSlotsFor` semantics here; keep `core/app_nav.dart` as a re-export.

**Acceptance:** `flutter analyze` clean; app runs identically; `git diff` shows no moved files.

### Phase 1 — Design system extraction
Move `lib/widgets/*` → `design_system/widgets/` (app bar, drawer, section header, metric tile, state views),
plus `theme/` and `typography/`. Update the 20 importing files in the same commit.

**Why this can go early:** the widgets are pure presentation with no Supabase coupling.

### Phase 2 — Feature restructuring of the verticals that already work
For each working area, split flat files into `screens/ · widgets/ · models/ · repositories/`:

| Feature | Moves |
|---|---|
| `auth` | login, recovery → `screens/`; `auth_repository` → `repositories/` |
| `classes` | `classes_seats_page` → `screens/`; `class_form_sheet`, `class_roster_*`, `student_transfer_*` → `widgets/`; `class_models` → `models/`; `teacher_directory` → `repositories/` |
| `students` | records, import, parent link, my profile, my children → `screens/`; `student_stats` → `repositories/` |
| `attendance` | register → `screens/` |
| `learning` | vocabulary bank → `screens/` |
| `notifications` | feed → `screens/` |
| `dashboard` | `home_page`, `home/` → `screens/` |

**Acceptance:** every moved file still analysed clean; no page renamed in the UI.

### Phase 3 — Replace the placeholder with real modules, one at a time
Priority by operational weight and by how much data already exists in Supabase:

1. **Admissions** — `admissions_enquiries` already populated; needs list → review → approve → enrol.
2. **Finance** — `fee_groups`, `fee_assignments`, `fee_payments`, `fee_waivers`, `fee_refunds`, `finance_audit_log`.
3. **Courses & lessons** — `learning_courses`, `learning_lessons`, `learning_lesson_progress`.
4. **Homework** — `learning_homework`, `learning_homework_submissions` (grading exists in web).
5. **Library** — `library_items`, `library_loans`.
6. **Staff** — `profiles` + `branch_memberships` + attendance.
7. **Timetable**, **Reports**, **Communications** — read-mostly, lower risk.
8. **Chinese learning labs** — content-driven; largest effort; last.

Each module ships as: repository (queries) → controller/state → screen → tests, and only then
`module_page.dart` stops being the route for it.

### Phase 4 — Retire `ModulePage` fallback
Once no module id resolves to the placeholder, delete the fallback and turn an unknown id into an
explicit error state (so a catalog typo fails loudly).

### Phase 5 — Verification gate
`mobile/test/` with: role resolution, multi-role union, repository mapping against fixtures,
permission matrix, and widget smoke tests for each screen's empty/error/loaded states.

---

## 6. Verification protocol

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Run target, for reference:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://aeryusbrulqdxjdynwfh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon>
```

**Limitation I must be explicit about:** this workspace has no Flutter/Dart toolchain and no Android
or iOS SDK, so I cannot execute `analyze`, `test` or `build` here. Nothing I deliver may be called
production-ready until those four commands pass on the machine that holds `D:\SAI-College-Production`.
Any phase I complete must therefore end with: *"code written — awaiting your `flutter analyze` output."*

Note also that `build_project_check` in this workspace compiles the **React portal**, not the Flutter
app. It proves the web side is intact; it says nothing about Dart.

---

## 7. Risks

| Risk | Mitigation |
|---|---|
| Moving 38 files at once breaks imports with no compiler to catch it | Phase 0/1/2 staged; never more than one feature per commit |
| Placeholder screens look "done" but write nothing | Contract §4 item 1 and 8 enforced per module |
| Client permission sets drift from RLS | Permissions module mirrors RLS; DB stays authoritative |
| Multi-role accounts see a module they cannot actually use | Module visibility is derived from roles, but every screen still fails safely on RLS denial |
| Second role-management path | `roles_permissions_page` stays read-only; `manage-roles` is the only writer |
| Secret leakage | anon key only, via `--dart-define`; never service_role in the app |

---

## 8. Immediate next step

Phase 0, because it changes zero behaviour and gives every later phase a home.
See the accompanying question for the migration style and the first module to take past the placeholder.