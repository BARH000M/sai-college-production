# Database contract and integration audit

Source: BARH000M/sai-college-production, `supabase/migrations/001_initial_schema.sql` and `006_attendance.sql` inspected 2026-11-09. **Repository source is not proof migrations were deployed to the designated Supabase project.**

| UI | Supabase API | Status |
| --- | --- | --- |
| Login / reset | auth.signInWithPassword, resetPasswordForEmail | implemented, requires key and existing account |
| Roles | public.user_roles (user_id, role) | implemented, fail closed |
| Profile | public.profiles | implemented |
| Dashboard / Courses / Classes | public.classes | implemented, RLS-scoped |
| Student / roster | public.students | implemented, RLS-scoped |
| Attendance | sai_attendance_classes, attendance_sessions, sai_attendance_roster, attendance_records | implemented conditional on migration 006 deployment and grants |
| Lesson video / media | no verified content schema | intentional unavailable state |
| Notifications | no verified notifications schema | intentional unavailable state |
| Finance | schema sai_finance in migration 007 | intentionally not bound without confirmed deployed grants/API contract |
| Admissions | migration 004 | intentionally not bound without deployment verification |

No schema changes, role grants, or RLS policy changes are performed by this package. Never put service_role keys in Flutter. Never infer authorization from UI role visibility alone.

## Read-only verification in Supabase SQL editor
```sql
select version from supabase_migrations.schema_migrations order by version;
select table_schema,table_name from information_schema.tables where table_schema='public' order by table_name;
select schemaname,tablename,policyname from pg_policies where schemaname='public' order by tablename,policyname;
```
Verify against **aeryusbrulqdxjdynwfh** before enabling production workflows. Do not run migrations from this package.
