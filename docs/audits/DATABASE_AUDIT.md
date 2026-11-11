# Database audit — Supabase production `aeryusbrulqdxjdynwfh`
Inspection: read-only SQL/catalog and Supabase project metadata on 2026-11-11.

| Finding | Observed value |
|---|---|
| Public base tables | 47 |
| Public tables without RLS | 0 |
| Active Edge Functions | 7 |
| Storage buckets | 1 private (`lesson-media`, 100MiB max object) |
| Objects in lesson-media | 0 |
| Lessons | 20 (20 published) |
| Vocabulary items | 30 (30 published; 28 linked to lessons) |
| Distinct lessons with vocab | 5 |
| Lesson progress rows | 60 |
| Homework submissions | 12 |
| Parent/student verified links | 0 total links |
| New settings rows | 7; settings audit rows 8 |
| Unified shared module rows | 0 across the 8 new tables |

**Important:** table counts are not a claim that all functionality is complete. A table can have perfect RLS and no working UI.

Remote migration history: `001,002,003,004,005,006,008,009,010,011,012,013,014,20261110172940,20261110173339,20261110173506` (no `007` or `015`–`028` in the returned history). The GitHub repo has old numbered migrations through 028 with gaps, while the schema includes finance and library structures. Compare the true SQL definitions, not just filenames. Do not run a mass push.

Security lints observed: mutable search_path on two library functions, 3 anon SECURITY DEFINER EXECUTE, 41 authenticated SECURITY DEFINER EXECUTE, leaked-password protection disabled. Some public admissions functions are deliberately public; the correct action is review code and rate limiting rather than indiscriminate revocation. Revisit [Supabase Security Advisors](https://supabase.com/dashboard/project/aeryusbrulqdxjdynwfh/database/security-advisor).

RLS denial proof is **not** established just by inspecting pg_policies. Simulated authenticated student/parent/teacher/accountant/receptionist/librarian/content_editor/superadmin test accounts and negative cases are still required.

No SQL migration or DML was executed by this bundle. See `backend/SUPABASE_MIGRATION_RECONCILIATION.md` and `tests/security/READ_ONLY_LIVE_PREFLIGHT.sql`.
