# Yemen SAI V2 — Read-only Supabase CMS schema comparison

**Checked:** 2026-11-13. **Source:** direct read-only Supabase PostgreSQL catalog queries and migration listings. No schema, data, RLS, migration history, function, or deployment changes were made.

## Project references and migration status

| Property | Production | Supabase Preview |
|---|---|---|
| Project reference | `aeryusbrulqdxjdynwfh` | `mgibjusuglafbnlrkbep` |
| Direct SQL query | Successful | Successful |
| Normal project management lookup | Listed | Not found in normal project listing; SQL remains accessible |
| `cms_programs` | Present, RLS enabled | Absent |
| `cms_news` | Present, RLS enabled | Absent |
| `cms_site_content` | Present, RLS enabled | Absent |
| `private.sai_security_has_role(app_role)` | Present | Absent |
| `014_public_read_and_status_permissions` migration | Recorded | Not recorded |
| Latest sequential migration recorded | `014` | `013` |
| Sequential migrations `020`–`028` | Not recorded | Not recorded |

Production migration ledger additionally records `20261110172940` (`sai_system_settings_shared_20261110`), `20261110173339` (`sai_unified_modules_web_mobile_secure`), and `20261110173506` (`sai_unified_module_realtime`). Preview has `001`–`013`, including `007` (`finance`), and no later entries. Production's ledger does not record `007`.

**Diagnosis:** Preview stops before migration `014` because that migration references CMS tables that do not exist in Preview. Migration `020` cannot create its prerequisites for an unguarded `014` because `020` runs afterward. The local proposed `014` guard may change clean replay behavior but cannot retroactively re-run `014` in Production, where it is already recorded.

## Verified Production CMS columns

All listed columns are `NOT NULL` unless explicitly marked **nullable**. Defaults are copied from Postgres catalog output.

### `public.cms_programs`

| Column | Type | Default |
|---|---|---|
| id | uuid | `gen_random_uuid()` |
| title_ar | text | none |
| title_en | text | `''::text` |
| summary_ar | text | `''::text` |
| summary_en | text | `''::text` |
| duration_ar | text | `''::text` |
| duration_en | text | `''::text` |
| icon | text | `'ri-book-open-line'::text` |
| is_published | boolean | `true` |
| sort_order | integer | `0` |
| created_at | timestamptz | `now()` |
| updated_at | timestamptz | `now()` |

Primary key: `cms_programs_pkey (id)`; unique btree PK index. RLS enabled, not forced.

### `public.cms_news`

| Column | Type | Default / nullable |
|---|---|---|
| id | uuid | `gen_random_uuid()` |
| title_ar | text | none |
| title_en | text | `''::text` |
| summary_ar | text | `''::text` |
| summary_en | text | `''::text` |
| tag_ar | text | `'أخبار'::text` |
| tag_en | text | `'News'::text` |
| image_url | text | **nullable**, no default |
| published_at | date | `CURRENT_DATE` |
| is_published | boolean | `true` |
| sort_order | integer | `0` |
| created_at | timestamptz | `now()` |
| updated_at | timestamptz | `now()` |

Primary key: `cms_news_pkey (id)`; unique btree PK index. RLS enabled, not forced.

### `public.cms_site_content`

| Column | Type | Default / nullable |
|---|---|---|
| key | text | none |
| section | text | `'general'::text` |
| label_ar | text | none |
| value_ar | text | `''::text` |
| value_en | text | `''::text` |
| sort_order | integer | `0` |
| updated_at | timestamptz | `now()` |
| updated_by | uuid | **nullable**, no default |

Primary key: `cms_site_content_pkey (key)`; unique btree PK index. Foreign key: `cms_site_content_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL`. RLS enabled, not forced.

**Indexes:** Only the three primary-key btree indexes listed above were returned for these tables.

## Verified Production CMS policies

All policies below are `PERMISSIVE`:

| Table | Policy | Command / To | Exact USING | Exact WITH CHECK |
|---|---|---|---|---|
| cms_programs | `cms_programs_public_read` | SELECT / public | `is_published` | — |
| cms_programs | `cms_programs_staff_read` | SELECT / authenticated | `private.sai_security_has_role('super_admin'::app_role) OR private.sai_security_has_role('admin'::app_role) OR private.sai_security_has_role('content_editor'::app_role)` | — |
| cms_programs | `cms_programs_write` | ALL / authenticated | same role predicate as staff read | same role predicate |
| cms_news | `cms_news_public_read` | SELECT / public | `is_published` | — |
| cms_news | `cms_news_staff_read` | SELECT / authenticated | same role predicate as staff read | — |
| cms_news | `cms_news_write` | ALL / authenticated | same role predicate | same role predicate |
| cms_site_content | `cms_site_content_public_read` | SELECT / public | `true` | — |
| cms_site_content | `cms_site_content_write` | ALL / authenticated | same role predicate | same role predicate |

The role predicate is parenthesized with three `OR` clauses. **Preview has no CMS policies**, since the CMS tables do not exist there.

## Verified Production private helper

- Function: `private.sai_security_has_role(wanted_role app_role)` → boolean.
- Language: SQL; `STABLE`, `SECURITY DEFINER`; owner `postgres`.
- Search path: `pg_catalog, public, private`.
- Parallel safety: `UNSAFE`.
- Function ACL (from `proacl`): `{postgres=X/postgres,service_role=X/postgres,authenticated=X/postgres}`. In particular, `anon` has no listed direct EXECUTE grant.

```sql
CREATE OR REPLACE FUNCTION private.sai_security_has_role(wanted_role app_role)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'private'
AS $function$
  select exists (
    select 1 from public.user_roles r
    where r.user_id = (select auth.uid()) and r.role = wanted_role
  );
$function$;
```

The helper does **not** exist in Preview as of this query. Any bootstrap needs carefully reviewed privilege and migration ordering, not simply an unconstrained `SECURITY DEFINER` function.

## Verified Production grants

For each of `cms_programs`, `cms_news`, `cms_site_content`:

- `anon`: `SELECT`.
- `authenticated`: `DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE`.
- `postgres`: `DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE`.
- `service_role`: `DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE`.
- No CMS-related sequence grants were returned.

**Security review needed:** The direct `TRUNCATE` grant to `authenticated` is unusually broad. PostgreSQL RLS does not restrict `TRUNCATE`. This finding should be assessed separately and **must not be blindly reproduced in Preview**. Do not revoke or modify Production privileges without explicit approval and compatibility review.

## Other production-only schema confirmations

All these relations exist in Production and have RLS enabled: `sai_system_settings`, `sai_download_resources`, `sai_inventory_items`, `sai_transport_routes`, `sai_student_portfolios`, `sai_housing_rooms`, `sai_certificates`, `sai_cms_pages`, `sai_alumni`. This establishes existence only, not feature completeness or schema replay parity.

## Required next engineering action (repo-only)

1. Review the pending local migrations `014_public_read_and_status_permissions.sql` and `020_cms_schema_and_private_helpers.sql` against this verified data. The earlier reconstructed `020` omitted `cms_site_content.updated_by` and its FK; check all other default values, policies, helper ACLs and table grants.
2. Make a safe, ordered clean-Preview bootstrap with exact verified objects. Do **not** apply migrations against Production or Preview manually. Respect the fact `014` is already recorded in Production; a changed historical migration will affect clean replays only.
3. Inspect the full `020` proposal's **other** helper definitions; only `private.sai_security_has_role` has been verified by this report.
4. Preserve security. Reproduction of unsafe privileges is not an objective. Document intentional grant differences and their rationale.
5. Test fresh migration replay in a disposable environment or Preview CI, not Production. Report any subsequent blockers. Do not bypass CI.
6. Leave PR #4 open, do not push, merge, deploy, or alter any production data without separate user approval.

**Limitation:** The Preview project is SQL-accessible despite the management API returning "Project not found"; no Preview project-management or connection credentials were retrieved. No migration changes were executed here. The report covers the requested CMS objects, target helper, grants and migration versions, not every private function in the database.
