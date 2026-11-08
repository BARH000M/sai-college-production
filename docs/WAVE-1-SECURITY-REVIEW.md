# Wave 1 security review status

## Student and class management review

**Post-deployment update:** The linked migration history lists 003 as applied. Read-only catalog checks confirmed the ten management write policies, existing SELECT policy definitions, two deactivation columns, five audit triggers, and student/class validation trigger. RLS is enabled on the five management tables, `user_roles`, and `audit_logs`; neither browser role has table `TRUNCATE` on those tables, authenticated has no table `DELETE`, and authenticated has no role-assignment insert or update. The descriptions of 003 as unapplied below are historical. Catalog inspection does not establish whether the policies and triggers behave correctly under real user claims; isolated positive and negative role tests remain outstanding.

The current linked catalog reports migrations 001 and 002 in the migration history, RLS on all nine public tables, the 12 policies from 002, and no effective browser insert/update grants on the five management tables. The inspected remote helper definitions match their 002 counterparts. `PUBLIC`, `anon`, and `authenticated` lack schema `CREATE`. The historical findings below describe the earlier inspection, not the current remote state.

Migration `003_staff_management_policies.sql` is local and unapplied. It keeps existing SELECT policy definitions unchanged, and changes the branch-membership helper so inactive memberships no longer authorize staff access. It permits super-admin management, scoped admin branch/class/student management, and super-admin-only branch creation and global session management. To avoid disclosing another user's membership, membership creation and management of other users is super-admin-only; an admin can only deactivate their own currently active membership. Column grants prevent browser updates to identifiers, account ownership, branch/session scope, and teacher assignment. A database trigger validates student/class branch consistency, and triggers add audit rows transactionally.

Existing 002 audit privileges allow authenticated users to insert actor-bound but otherwise untrusted audit rows, including forged trigger-like metadata. The new triggers ensure entries are written with managed mutations, but do not make the existing audit log tamper-proof. Audit authenticity, function ownership, schema privileges, concurrency, mutation permissions, and positive and negative role/JWT cases require isolated database execution and security review. Docker was unavailable during this work; SQL parsing and dry-run do not establish those properties. Do not deploy 003 before those checks and approval.

## Earlier security review (historical)

Status: **blocked; remote security gate failed; not a security sign-off**.

## Prepared remediation: not applied

`supabase/migrations/002_security_policies.sql` is a locally prepared baseline for the nine existing application tables. It adds no tables, does not drop tables, and contains no data-deletion statements. It must not be applied until the migration history is reconciled, its behavior is tested against an isolated representative database, and deployment is authorized.

### Privilege changes in the migration

- For `profiles`, `user_roles`, `branches`, `academic_sessions`, `branch_memberships`, `classes`, `students`, `parent_student_links`, and `audit_logs`, revoke all table privileges from `PUBLIC`, `anon`, and `authenticated`, including `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, and the server's `MAINTAIN` privilege.
- Regrant `authenticated` `SELECT` on those nine tables, subject to RLS. Regrant `authenticated` only `INSERT (id, full_name, phone, preferred_locale)` and `UPDATE (full_name, phone, preferred_locale)` on `profiles`, subject to self-only RLS. No profile email or timestamp mutation is granted.
- Grant `authenticated` only `INSERT (actor_user_id, action, entity_type, entity_id, metadata)` on `audit_logs`; RLS requires the authenticated actor's own ID. No browser update, delete, or truncate privilege is granted on audit logs.
- No browser write privilege is granted on role assignments or other operational tables. The migration does not change grants to `postgres` or `service_role`, or set default privileges on future tables. Client roles receive no table privileges from this migration on the nine tables other than those stated above.
- The six helper functions below revoke all function privileges from `PUBLIC`, `anon`, and `authenticated`, then grant `EXECUTE` to `authenticated` only. Trusted owners retain their inherent rights.

### Policies in the migration

| Policy | Table | Intended access |
|---|---|---|
| `profiles_select_self` | `profiles` | Own profile only, including for super admins. |
| `profiles_insert_self` | `profiles` | Insert own profile only, limited by column grants. |
| `profiles_update_self` | `profiles` | Update own profile only, limited by column grants. |
| `user_roles_select_self_or_super_admin` | `user_roles` | Own assignments; super admin can read all. |
| `branches_select_authorized` | `branches` | Super admin, member staff, or own/verified-linked learner branch. |
| `academic_sessions_select_authorized` | `academic_sessions` | Super admin, or session connected to a class the user may read. |
| `branch_memberships_select_self_or_super_admin` | `branch_memberships` | Own memberships; super admin can read all. |
| `classes_select_authorized` | `classes` | Super admin; branch-member admin; assigned branch-member teacher; enrolled student or verified parent. |
| `students_select_authorized` | `students` | Super admin; branch-member admin; assigned branch-member teacher; self or verified parent. |
| `parent_student_links_select_parent_or_super_admin` | `parent_student_links` | Super admin or a parent's own verified links. |
| `audit_logs_select_super_admin` | `audit_logs` | Super admin only; audit rows have no branch field. |
| `audit_logs_insert_self` | `audit_logs` | Authenticated users may insert only with their own actor ID. |

These are intended rules, not verified outcomes. A non-super-admin cannot see an academic session until an accessible class is associated with it. Teachers require both a class assignment and branch membership. Access combines all assigned roles. Other operational writes, receptionist student access, and branch-scoped audit access are intentionally not granted by this security-only baseline; future features need separately reviewed policies.

### Helper functions

`sai_security_has_role`, `sai_security_branch_member`, `sai_security_can_read_student`, `sai_security_can_read_class`, `sai_security_can_read_branch`, and `sai_security_can_read_session` are stable SQL `SECURITY DEFINER` functions with the requested fixed `search_path = public` and schema-qualified table and function references. They use `auth.uid()` for the principal; arguments identify roles or resources, not an arbitrary user. The migration aborts if `PUBLIC`, `anon`, or `authenticated` can create objects in `public`. It also aborts on unexpected public tables or policies. These checks do not replace continuing control of schema privileges or verification of every untrusted role. The functions rely on a trusted owner that can read the referenced RLS-protected tables without recursion. Verify ownership, bypass behavior, execute grants, and schema creation privileges in the actual deployment environment.

### Validation and risks

- A read-only catalog comparison inspected public columns/types/defaults/nullability, constraints, indexes, policies, triggers, owners, RLS state, table privileges, explicit column ACLs, browser-role memberships, and helper-name conflicts. The current nine-table layout aligns with the local foundation at the inspected structural level, but the remote has RLS enabled and the local migration does not. Migration history is absent; this is not full behavioral equivalence.
- Catalog ACL inspection also found `MAINTAIN` grants for the browser roles, omitted by the earlier `information_schema.role_table_grants` view. The prepared `REVOKE ALL` addresses it.
- PostgreSQL parser checks passed for both migrations and all six SQL function bodies; no top-level `DELETE`, `TRUNCATE`, or `DROP TABLE` statements were found. Existing migration 001 does contain foreign-key `ON DELETE` actions, which operate when referenced records are deleted separately. Parser success does not validate names, permissions, function ownership, or RLS behavior.
- `supabase db push --linked --dry-run` succeeded and lists **both `001_initial_schema.sql` and `002_security_policies.sql`**. Running a real push now would attempt to recreate existing foundation objects and is unsafe. Do not repair migration history or run a real push until the baseline is independently reconciled.
- CLI local lint could not connect because the local database/Docker daemon was unavailable. No policy, helper, ownership, effective grant, session restore, or role behavior was executed against a representative database. In particular every policy in the table above requires positive and negative role/JWT tests.
- Direct client audit inserts bind the actor ID but **do not authenticate the action, target, or metadata**. A user can submit misleading or excessive entries under their own identity. Do not treat these entries as tamper-proof security evidence; server-generated audited mutations, validation and abuse controls remain necessary.
- The migration replaces only its named policies, uses replaceable helper definitions, and fails closed on unexpected public tables or policies. Retest repeat execution and review pre-existing column-level grants: table-level `REVOKE ALL` does not remove independent column grants. No such grants were observed in the remote inspection, but that must be rechecked immediately before deployment.
- After successful isolated tests, backup, complete schema/history reconciliation, and deployment authorization, the intended linked deployment command is `supabase db push --linked`. It is **not safe to run against the current history state**.

## Evidence and unresolved gates

- Remote read-only catalog inspection found RLS enabled on all nine public foundation tables, but **zero policies on each table**. The checked-in migration does not include that remote RLS enablement. RLS without policies denies ordinary role access; actual application sign-in and queries were not tested.
- Both `anon` and `authenticated` have `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, and `TRIGGER` grants on every one of those tables. RLS does not govern `TRUNCATE` or `REFERENCES`; broad privileges must be reconciled and revoked where unnecessary before release. Grants alone do not demonstrate that PostgREST exposes a TRUNCATE endpoint.
- There are no policies enforcing the requested student ownership, verified parent links, teacher assignments, branch/session scope, or authorized audit visibility. Nor has audit immutability been established in the presence of the broad grants.
- A read-only query verified that the expected account exists and is assigned `super_admin`. This is not a successful password sign-in or end-to-end authorization test.
- The remote `supabase_migrations.schema_migrations` table was not found. The migration history and full schema equivalence must be reconciled before deploying new migrations.
- A source search of `web/src` found no literal `service_role`, `SUPABASE_SERVICE_ROLE_KEY`, or `VITE_SUPABASE_SERVICE` references. This limited search is not proof that no secret exists anywhere in the workspace or deployed artifacts.
- No production Flutter project exists to inspect.

**Required before release:** inspect and test actual database RLS and grants for every sensitive table and role, including denied writes to `user_roles` and audit logs, student ownership, verified parent-child access, teacher assignments, and branch/session constraints. Treat this gate as unresolved until verified.
