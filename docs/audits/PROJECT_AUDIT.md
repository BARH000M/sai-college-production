# Yemen SAI V2 — Evidence-based project audit
**Inspection:** 2026-11-11. **Source:** GitHub `BARH000M/sai-college-production` main tree (`84ae6e7b88d524ece0bfbfa0018c6f171d144aff`), project Supabase metadata and read-only PostgreSQL catalog queries; user's pasted Windows build logs. **No production writes were performed in this audit.**

## Confirmed architecture
- Root website: React 19, Vite 8, TypeScript; public routes, protected portal, 9-role navigation. There is also a **separate** `web/` project with different package dependencies and 7 Node test files; do not mistake it for the root website.
- Mobile: Flutter app in `mobile/`, with 1.2 source, live Supabase/preview configuration, mobile CI workflow, Android/iOS projects and brand assets. Role-aware navigation exists in source, but authorization end-to-end for all nine roles remains untested.
- Backend: Supabase project `aeryusbrulqdxjdynwfh` (name `sai-college-production`), PostgreSQL 17, Auth, 7 active Edge Functions, private `lesson-media` Storage, realtime publication for 8 new shared tables.
- Directory counts from GitHub recursive tree: 1665 tree entries, `mobile/` 240, `web/` 28, `supabase/` 50, `docs/` 13, `prototype/` 709, `.github/` 2. These include files and directory entries, not just executable source.
- Repository contains generated `.gradle` cache, `out/`, a tracked `.env` with only **public** Supabase client configuration values, and a legacy prototype. Review generated artifacts and maintain `.gitignore`; never commit private keys.

## Blocking findings (in order)
| Code | Priority | Status | Evidence | Remedy |
|---|---|---|---|---|
| A01 | P0 | BROKEN/PARTIAL | User's Flutter test compiled `image 4.11.0` against `archive 4.0.9`; remote `mobile/pubspec.yaml` already overrides `image: 4.8.0`, demonstrating local/remote drift. | Preserve local changes, align Flutter dependency override and lockfile; run tests. |
| A02 | P0 | PARTIAL | User's root `npm run build` passed; `npm run type-check` earlier found 10 errors. Remote source now contains fixes for several of them, but current local status is unknown. | Merge latest remote safely; run typecheck, web CI, integration tests. |
| A03 | P0 | BROKEN | Local migrations 001–028, remote history 001–006,008–014 plus 3 timestamped migrations. Schema already contains 47 public tables. | Reconcile migration history on staging **before** any `db push` or `repair`. |
| A04 | P0 | PARTIAL | 47/47 public tables RLS-enabled, but Supabase advisor reports 3 anon-executable SECURITY DEFINER RPCs and 41 authenticated-executable functions, some intentionally reachable. | Audit privilege enforcement per function; run negative access tests, prioritize grants and public admissions. |
| A05 | P0 | MISSING | No Lesson 101 title/position match; 0 linked media URLs and zero objects in `lesson-media`. | Approved curriculum and authentic media; build verified Lesson 101 vertical slice. |
| A06 | P1 | PARTIAL | Public site Arabic primary; portal often Arabic hard-coded, Flutter `supportedLocales` only ar/en. | Extend Chinese locale scaffolding and add translation coverage tests. |
| A07 | P1 | MISSING | No root web CI workflow observed; `.github/workflows/mobile-ci.yml` is present. | Add web workflow. |
| A08 | P1 | NOT VERIFIED | User's physical Windows setup, Android debug APK, iOS archive and hosting credentials not available in this environment. | Run local checks; publish only with explicit approval. |
| A09 | P1 | BLOCKED | GitHub branch creation returned HTTP 403 `Resource not accessible by integration`. | Apply reviewed patch locally and push with user's own Git credentials. |

## Immediate acceptance gate
Zero failed `flutter analyze`, `flutter test`, root `npm run type-check`, `npm run build`, `web/npm test`, `web/npm run build`, no secret leak, and reviewed diff. Run authenticated nine-role tests before stating backend integration passes.

## Guardrails
No data reset, no duplicate database, no mandatory Docker, no automatic production deployments, no service-role/secret key in frontend, no fake content, no production `supabase migration repair` without audited evidence.
