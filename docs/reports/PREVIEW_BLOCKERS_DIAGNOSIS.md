# Preview blockers diagnosis

Inspection date: 2026-11-16. Branch confirmed: `feature/v2-completion`.
Workspace: `D:\SAI-College-Production-v2-completion`.

## Scope and safety

The first hosted call was `supabase-preview.get_project_url`, which returned exactly `https://mgibjusuglafbnlrkbep.supabase.co`. Every hosted inspection used that read-only MCP server. Only catalog SELECTs, the specified test-account SELECT, migration listing, and historical log queries were performed. No function was invoked, no authentication session was created, and no hosted writes, migrations, deployments, account creation, or role assignment occurred. Production was not contacted.

All initial uncommitted files were preserved, including Phase 1 repairs, `.mcp.json`, `.codex/`, `auto-imports.d.ts`, Flutter plugin registration and dependency lockfile changes. No pull/reset/clean/merge/rebase/commit/push was run.

## Confirmed role-management failure

| Integration | Exact Preview endpoint | Evidence |
| --- | --- | --- |
| Role administration, user directory, summary | `https://mgibjusuglafbnlrkbep.supabase.co/functions/v1/manage-roles` | Historical POST 500 at 2026-11-15 20:59:42.149 UTC; deployment suffix `_7`. OPTIONS 200. |
| Student learning-account and teacher-account panels | `https://mgibjusuglafbnlrkbep.supabase.co/functions/v1/provision-learning-account` | Historical POST 500 at 2026-11-15 20:59:42.076 UTC; deployment suffix `_6`. OPTIONS 200 and runtime boot events. |
| Link an existing student account | `https://mgibjusuglafbnlrkbep.supabase.co/functions/v1/link-student-account` | Checked-in integration exists. No matching invocation appeared in the inspected recent log sample; deployment/version cannot be established from the available MCP capabilities. |

These logs establish that the first two functions were deployed and reached the service. They do not prove that the currently checked-in source exactly matches deployed artifacts. The configured read-only MCP exposes no function source/deployment-list or secret-list tool.

Postgres logs at 20:59:42.072, 20:59:42.001 and nearby timestamps report **`permission denied for table user_roles`**. Read-only `has_table_privilege` checks confirm `service_role` has no SELECT/INSERT/UPDATE/DELETE on `user_roles`, `profiles`, `branch_memberships`, `students`, `classes`, and most other operational tables. Schema USAGE on `public` is present; `service_role` has BYPASSRLS and is not a superuser. BYPASSRLS does not supply missing table privileges. This is an ACL/backend contract defect, not a reason to disable RLS or change user roles.

Both checked-in functions validate the caller with `auth.getUser(token)`, then use a server-only service client to SELECT the caller's `super_admin` role from `user_roles`. This denied query occurs before directory/overview work. The log correlation and current ACLs identify the common failure cause; no authenticated replay was performed. No evidence supports treating these 500s as a missing deployment or simply an expired JWT.

The checked-in denial branch returns HTTP 500 with `{ "ok": false, "message": "permission denied for table user_roles" }`. Historical logs do not retain the response body, so that exact response body is **source-derived**, not captured from the browser. The old client discarded `FunctionsHttpError.context`, replacing the useful status/body classification with the generic non-2xx message.

### Authentication and dependencies

- `manage-roles`: POST with an authenticated bearer session; verified caller must have database-assigned `super_admin`. No/invalid session is 401; valid non-Super-Admin caller is 403 after the authorization query succeeds. Browser navigation also restricts the role administration page.
- `provision-learning-account`: same authentication and explicit Super Admin requirement. Student/parent invitation and teacher operations are actions on this same function, not separate teacher endpoints.
- `link-student-account`: authenticated Admin or Super Admin; Admin is constrained to active branch memberships. Link/unlink delegates to existing authorized admission RPCs using the caller's session.
- Common server environment names: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`. Their values were never read. Reaching table permission errors is evidence against the initial missing-environment branch for the observed requests, but is not a complete secret-configuration verification.
- Optional teacher notification code uses `RESEND_API_KEY` and `RESEND_FROM_DOMAIN`. Their presence/delivery behavior is unverified. Invitation delivery also depends on Auth email configuration and allowed redirect destinations. None was modified.
- Directory/role writes require Auth Admin API plus `user_roles`, `profiles`, `branches`, `branch_memberships`, `audit_logs`. Summary additionally reads `students`, `classes`, `academic_sessions`, `learning_courses`, `learning_lessons`, `learning_lesson_progress`, `learning_homework_submissions`, `admissions_enquiries`.
- Provisioning additionally reads `parent_student_links`, `learning_homework`; teacher changes update classes/courses/memberships and write profile/role/audit rows. Linking RPCs `admissions_link_student_account`, `admissions_unlink_student_account`, `admissions_list_parent_links`, and `admissions_verify_parent_student` exist in Preview.

## Confirmed settings failure

`systemSettings.ts` queries `public.sai_system_settings` with `category`, `setting_key`, `value_text`, `updated_at`, `updated_by`, and upserts on `(category,setting_key)`. Flutter references the same table.

Catalog inspection found **no application settings relation in any inspected application schema**, including no alternate schema containing `sai_system_settings`. Checked-in migrations do not create that table. Preview migration history contains `001`–`031` and five timestamped migrations through `20261116013950_learning_scored_exercises`; none installs settings storage.

Conclusion: the UI references a backend contract that has never been implemented in this baseline/Preview. There is no verified alternative contract to switch to. A schema-cache reload or a different schema qualifier cannot create the absent relation. No evidence identifies a missing existing settings migration; a new reviewed migration is required. API exposure/grants/RLS must then be verified separately after an authorized installation.

### Local fixes completed

- `functionErrors.ts`: extracts HTTP status from a cloned error Response; allowlists the database-permission classification; provides Arabic status-specific guidance. Never echoes arbitrary response JSON, HTML, tokens, passwords, or credentials. Original response body is left unconsumed. No automatic mutation retry or authorization fallback.
- `roles.ts`, `learningAccounts.ts`, `studentAccounts.ts`: use the safe helper for invocation failures. All panel layouts and action contracts remain unchanged.
- `systemSettings.ts`: missing-table codes `PGRST205` and `42P01` become a clear backend-unavailable error; permission errors remain distinct.
- `SystemSettings.tsx`: records the successfully loaded category; hides editing/save controls after a failed load and while the selected category is stale; blocks the save handler unless Super Admin and ready; offers a read-only reload action. No sample/default configuration is saved as though loaded from Preview.
- Flutter settings already return an error/retry state before rendering fields when the read fails; no Flutter source changes were needed in this task.

These fixes make failure reporting and operation availability truthful. They **do not restore hosted account management or create settings storage**.

## Waiting-for-role account

For `e2e-v2-student@example.test`, the authorized read-only check found: Auth account exists, email confirmed, no ban timestamp, profile exists, **zero `user_roles` rows and zero `students.user_id` links**. Do not infer role from the email, editable user metadata, or the intended test purpose. Both clients load assigned roles from `public.user_roles`; self-read RLS exists. Waiting-for-role is correct for this account.

After the service ACL repair is separately approved and verified, a Super Admin should identify the correct existing student record, then use **StudentAccountLink → existing verified account → Link**. The existing `admissions_link_student_account` transaction verifies the caller and branch, links `students.user_id`, inserts the `student` role idempotently, and records an audit event. This is preferable to merely granting a student role without linking a student record. Do not invent a student ID or invite a duplicate account. If no legitimate student record exists, use the existing approved admissions/enrollment process first. Refresh the account's roles after linking. No recovery action was executed.

## Proposed backend repairs — review only, NOT applied

Read the Postgres best-practices skill and its RLS guidance for these proposals. Create real migration filenames using the installed CLI only in a separately authorized implementation phase. No migration file was added to the runnable migration chain here.

### Proposal 1: explicit service-client ACL restoration

The following exact SQL proposal restores only operations used by the inspected functions and summary; it grants nothing to browser roles and leaves RLS/policies unchanged. It must be tested in a disposable database and reviewed against the deployed function source before approval. It does not resolve existing multi-step mutation atomicity/audit-error handling risks.

```sql
begin;
grant usage on schema public to service_role;
grant select on public.user_roles, public.profiles, public.branches,
  public.branch_memberships, public.students, public.parent_student_links,
  public.classes, public.academic_sessions, public.learning_courses,
  public.learning_lessons, public.learning_lesson_progress,
  public.learning_homework, public.learning_homework_submissions,
  public.admissions_enquiries to service_role;
grant insert, update on public.profiles to service_role;
grant insert, update, delete on public.user_roles,
  public.branch_memberships to service_role;
grant update on public.classes, public.learning_courses to service_role;
grant insert on public.audit_logs to service_role;
commit;
```

Auth Admin permissions/secrets are separate from these table grants. Do not use blanket `GRANT ALL ON ALL TABLES`, disable RLS, or grant SQL roles to the test user. Existing service clients bypass RLS, so retaining the Edge Functions' verified caller authorization is mandatory. Investigate why baseline provisioning omitted these grants; local source does not establish a historical revocation event.

### Proposal 2: settings contract

Exact SQL shape for a reviewable non-secret preference store follows. It is a proposal, not verified deployed behavior. Integrations, module enablement, backup execution and role assignment remain separate services; storing a preference never enables those operations. This initial proposal deliberately permits only the five General fields. The UI must expose only `general` when this proposal is implemented; remaining sections require a reviewed allowlist extension and consumers before release.

```sql
begin;
create table public.sai_system_settings (
  category text not null check (category = 'general'),
  setting_key text not null check (setting_key in
    ('college_name','website_url','contact_email','contact_phone','address')),
  value_text text not null check (char_length(value_text) <= 2000),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id),
  primary key (category, setting_key)
);
alter table public.sai_system_settings enable row level security;
revoke all on public.sai_system_settings from public, anon, authenticated;
grant select on public.sai_system_settings to authenticated;
grant insert (category, setting_key, value_text), update (value_text)
  on public.sai_system_settings to authenticated;
create policy settings_read on public.sai_system_settings
  for select to authenticated using (
    private.sai_security_has_role('super_admin'::public.app_role)
    or private.sai_security_has_role('admin'::public.app_role)
  );
create policy settings_insert on public.sai_system_settings
  for insert to authenticated with check (
    private.sai_security_has_role('super_admin'::public.app_role)
  );
create policy settings_update on public.sai_system_settings
  for update to authenticated
  using (private.sai_security_has_role('super_admin'::public.app_role))
  with check (private.sai_security_has_role('super_admin'::public.app_role));
create function private.stamp_system_setting()
returns trigger language plpgsql security invoker
set search_path = pg_catalog, public, auth as $$
begin
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$$;
revoke all on function private.stamp_system_setting()
  from public, anon, authenticated;
create trigger stamp_system_setting
  before insert or update on public.sai_system_settings
  for each row execute function private.stamp_system_setting();
commit;
```

Before approval: verify private helper EXECUTE privileges, test PostgREST upsert with column-level grants, verify API exposure, add an append-only audit trigger under a tightly scoped owner, validate URLs/email server-side, and add policy/value tests. Sensitive settings categories require Super-Admin-only SELECT as well as writes; secrets must never enter this store. This proposal is intentionally not a complete production migration or a claim that existing settings consumers are wired.

## Validation and files

Changed this task: `src/portal/lib/functionErrors.ts`, `roles.ts`, `learningAccounts.ts`, `studentAccounts.ts`, `systemSettings.ts`, `src/portal/pages/SystemSettings.tsx`, `web/tests/learning-accounts.test.cjs`, `web/tests/preview-blockers.test.cjs`, and the three requested reports. Phase 1 changes remain intact.

`npm --prefix web test`: PASS, 64 tests, 0 failures, 0 skipped, exit 0. Four new tests cover safe status diagnostics, account-wrapper failure propagation/no retries, settings missing-contract errors versus RLS denial, and settings load/save gating. Additional web validation results are recorded in `WEB_MOBILE_NEXT_BUILD_BACKLOG.md` after completion. Flutter source was unchanged, so Flutter checks were not rerun in this task; Phase 1 recorded analysis PASS and 48 tests PASS.

Authenticated browser/REST/RPC role isolation, successful account provisioning, email delivery and successful settings persistence remain unverified. No local unit result is presented as live security verification. The sandbox shell failed to initialize; approved escalated local commands were used. No hosted workaround was attempted.

References: [Supabase function invocation](https://supabase.com/docs/reference/javascript/functions-invoke), [Postgres roles](https://supabase.com/docs/guides/database/postgres/roles), [Observability](https://supabase.com/docs/guides/observability). Actual project findings above come from this task's read-only Preview evidence and checked-in source.
