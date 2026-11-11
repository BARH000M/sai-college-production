# Yemen SAI V2 — implementation and verification roadmap (evidence-driven)

Source of requirements: `docs/requirements/MASTER_BUILD_PROMPT_SUBMITTED_20261111.md`. This roadmap makes no claim to have completed all deliverables.

## Locked choices
- Authoritative Supabase: `aeryusbrulqdxjdynwfh` (never connect to a deprecated project).
- Existing repository: `BARH000M/sai-college-production` and local root `D:\SAI-College-Production`.
- One root React/Vite portal and one separate `web/` project until code ownership is reconciled; Flutter Android/iOS under `mobile/`.
- Official identities: Yemen SAI Educational College / كلية ساي التعليمية اليمنية الصينية / 也门赛艾教育学院.
- Nine roles: super_admin, admin, teacher, accountant, receptionist, librarian, student, parent, content_editor; multi-role union subject to row scopes.
- No Docker mandate, no database reset, no duplicate backend, no fake success claims.

## Dependency-ordered execution gates

| Gate | Work | Exact exit criterion | Current assessment |
|---|---|---|---|
| G0 Baseline | Preserve user work, snapshot `main`, audit remote and local builds | evidence audit and backups | PARTIAL: this package provides initial remote audit |
| G1 Build recovery | Resolve Flutter package version conflict, root TS errors, 2 web projects CI | all analyses, tests and builds exit 0 on user's PC | NOT VERIFIED; script prepared |
| G2 Schema reconciliation | Compare existing 001–028 SQL files against remote timestamped history; create staged-only reconciled migration plan | DB diff reviewed and non-destructive restore-tested | BLOCKED by history drift |
| G3 Design foundation | Cairo + Chinese fallback, RTL, compact campus style, accessible states, language selectors | responsive screenshots, focus/RTL tests, approved visual review | PARTIAL code provided, screenshots pending |
| G4 Security and roles | Positive/negative cross-branch, parent verification, class ownership, privileged RPC tests | nine-role denial matrix green | NOT VERIFIED |
| G5 Lesson 101 | Approved content, media, listening/reading/speaking/writing, server-graded assessment, checkpoints | mobile-to-web resume verified with the same real account | MISSING; no Lesson 101 data/media yet |
| G6 Engines | SRS, conversation, native audio, speech evaluation provider, offline idempotent sync | learning matrix and cost/provider audit green | NOT VERIFIED |
| G7 Administration | Admissions, sessions, finance, library, CMS, certificate, transport and reports | real persisted role-specific CRUD tests | PARTIAL source/schema only |
| G8 Release | CI, security advisories, GDPR/child privacy, Hostinger, debug APK, signed AAB, iOS cloud signing | reviewed and explicitly approved production release | BLOCKED, no approval or signing keys |

## Next actions after phase-one patch
1. Confirm local `git status`, create a feature branch, apply vetted patch, run both web projects and Flutter gates.
2. Review live schema migration drift on a disposable environment; no unreviewed `supabase db push`.
3. Prepare approved Lesson 101 vocabulary/media/quiz answer material; no invented content.
4. Complete negative RLS/RPC and physical Android login tests; then integrate SRS, offline and speech provider in stages.
5. Prepare signed store artifacts and obtain explicit approval before public publishing.

All reports are in `docs/reports/`; do not mark a gate complete unless matching command output and user-journey evidence exist.
