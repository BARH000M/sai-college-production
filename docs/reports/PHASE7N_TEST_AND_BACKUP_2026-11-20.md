# Phase 7-N — role/hold test findings, lock entries, and the backup gate

Date: 2026-11-20
Project: `aeryusbrulqdxjdynwfh` (Main)
Status: package **still not executed against production**. Nothing in this report
changed production data, migration history, or any deployed function.

---

## 1. Isolated test review — two assertions were wrong

The test could not be executed here (no shell, no local PostgreSQL, and it must
never run against Main). It was therefore traced assertion-by-assertion against
the **live schema**, which is the same shape the local test database must have.

Live schema evidence gathered read-only:

| Object | Verified state |
| --- | --- |
| `public.branches` | `id, name, code, address, is_active, created_at` — `code` is `NOT NULL` |
| `public.user_roles` | `user_id, role (app_role), assigned_by (nullable), assigned_at` |
| `public.profiles` | `full_name` `NOT NULL` with no default |
| `public.audit_logs` | `actor_user_id, action, entity_type, entity_id, metadata, created_at` |
| `public.app_role` | 9 values incl. `content_editor` |
| triggers on `user_roles` | **none** — so the RPC is the only audit writer |
| trigger on `branch_memberships` | `audit_memberships_management` → writes `action = lower(tg_op)` (`insert`/`delete`) with `entity_id = branch_id` |
| `private` schema | exists |
| `sai_manage_role_assignment`, `sai_assert_mutations_enabled`, `sai_set_mutation_hold` | still **absent** (package not applied) |

All fixture inserts satisfy the real constraints (`branches.code` is supplied,
`user_roles.assigned_by` is nullable, `profiles` is written by the RPC with a
non-empty `full_name`). The advisory-lock probe (`classid = 831704`, `objid = 1`)
matches `pg_advisory_xact_lock(831704, 1)`.

### Defect 1 (would have failed) — audit row count expected 8, actual 6

```sql
if audit_count <> 8 then
  raise exception 'Expected 8 transactional role audit rows, found %', audit_count;
```

Only six calls ever reach the audit insert. The other seven raise before it and
roll back inside their own subtransaction, so they must leave no row:

1. grant `teacher` → row
2. grant `student` → row
3. revoke `student` → row
4. grant `super_admin` (confirmed) → row
5. revoke `super_admin` from the actor → row
6. revoke `super_admin` from the banned admin → row

Rejected without a row: non-admin actor, inactive branch, unverified email,
unconfirmed `super_admin` grant, duplicate role, and the last-admin revocation
(both attempts).

**Fixed:** expectation is now `6`, with the six rows and the seven rejections
enumerated in a comment so the number cannot drift again.

### Defect 2 (would have aborted the whole test) — release used a role with no privilege

```sql
execute 'set local role service_role';
update private.sai_mutation_hold_state set enabled = false ...;
```

The migration runs `revoke all on private.sai_mutation_hold_state ... from public,
anon, authenticated, service_role`. Under `service_role` that `UPDATE` raises
`permission denied for table sai_mutation_hold_state`, which is **not** caught —
the entire test aborts.

**Fixed, and turned into a security assertion:** the direct `service_role` write is
now expected to fail with `insufficient_privilege` (proving only the reviewed
super-admin RPC can move the hold), and the release is then performed as the
package owner.

### Defect 3 (documented, not a code change) — it cannot run in the CI cluster

`.github/workflows/database-ci.yml` → `run_native_contracts.py` builds a **bare
`initdb` cluster** with no `auth` schema, no `public.app_role`, no `branches`,
`user_roles`, `profiles`, `audit_logs`, no `private` schema and no `service_role`.
This test needs all of them, so it was deliberately **not** added to that suite.
The header of the test now says so and gives the correct way to run it:

```bash
PGOPTIONS='-c sai.role_and_hold_forward_test=yes' \
  psql -X -v ON_ERROR_STOP=1 -h <host> -p <port> -U postgres -d postgres \
  -f supabase/tests/role_management_and_hold_forward.sql
```

`PGOPTIONS` is required because the marker is a session setting; a separate `psql -c`
would not persist into the `-f` session.

Run it against a local Supabase database or a restored clone. Expected final line:

```
Role management authorization, branch scope, multi-role, last-admin,
advisory-lock, audit, and hold on/off assertions passed; fixtures rolled back
```

---

## 2. Lock entries and pin refresh

`validate_migrations.py` fails today on **five** repository migrations with no lock
entry — the four `2026112000*` files plus this package. Their SHA-256 must be
computed over **LF-normalised** bytes (`digest(p, True)`), and entries need
`version, filename, sha256_lf, history, empty, classification`.

Hand-typing those digests is exactly what breaks the gate, so a reviewable
generator was added instead:

```powershell
# 1. four files whose objects already exist in Main
python supabase/tools/add_migration_lock_entries.py `
  --classification "APPLIED BUT NOT RECORDED" `
  --only 20261120000000 20261120010000 20261120020000 20261120030000 --dry-run

# 2. the package itself is authored but not applied
python supabase/tools/add_migration_lock_entries.py --classification "NOT APPLIED" `
  --only 20261120120000 --dry-run
```

Drop `--dry-run` once the printed digests look right. `history` stays `false` for
all five — none of them is recorded in the remote migration history, and this tool
never claims otherwise.

Then the dependent pins must be regenerated, because `migration-lock.json` is
itself pinned by the manifest **and** `integrity.json`:

```powershell
python supabase/tools/refresh_phase7m_pins.py   # manifest + integrity hashes
python supabase/tools/validate_migrations.py    # expect: PASS
python supabase/tests/test_migration_validation.py
```

Order matters: lock entries first, refresh second. Refreshing first pins the old
lock file and the next edit invalidates it again.

### Still expected to fail after this

`main-deployment-manifest.json` and `integrity.json` describe the **pre-redeploy**
`manage-roles` baseline (`version 9`, `verify_jwt=false`). The deployed function is
now v10 with `verify_jwt=true`. Refresh fixes the hashes, but the manifest's
`edge_function_baseline` block still asserts v9 — it should be updated to v10
`verify_jwt: true` in the same commit, or the file describes a baseline that no
longer exists.

---

## 3. Production backup gate — currently **not** satisfied

Verified read-only against Main:

| Check | Result |
| --- | --- |
| `public.sai_backup_runs` rows | **0** |
| Last completed backup | **none** |
| `backups` storage bucket | exists (private) |
| Database size | 17 MB |
| Backup mechanism | `.github/workflows/db-backup.yml` (pg_dump → gzip → AES-256-CBC → private bucket → checksum recorded) |

**There is no verified backup of production yet.** That must be closed before the
14 history-repair commands or the new package are scheduled.

### Workflow defect found and fixed

The record step previously read:

```bash
STATUS="completed"
[ -f "${DUMP_FILE}.enc" ] || STATUS="completed"   # tautology — always completed
if [ "${{ job.status }}" != "success" ]; then STATUS="failed"; fi
```

A dump that never reached storage could be recorded as `completed`, which defeats
the purpose of the gate. Two changes were made:

1. **Read-back verification step** — the stored object is downloaded again and its
   SHA-256 and size are compared with the locally computed values. `VERIFIED=1` is
   only set on success.
2. **Truthful status** — `completed` now requires `VERIFIED=1` and the encrypted
   file to still exist; otherwise the row is recorded as `failed`.

### Procedure

```bash
gh workflow run "Database Backup" -f retention=manual
gh run list --workflow "Database Backup" --limit 1
```

Repository secrets required: `SUPABASE_DB_URL`, `SUPABASE_URL`,
`SUPABASE_SERVICE_ROLE_KEY`, `BACKUP_ENCRYPTION_KEY`.

Verification query after the run:

```sql
select id, provider, kind, status, retention_class, size_bytes, checksum,
       location, finished_at, error
from public.sai_backup_runs
order by created_at desc
limit 3;
```

Accept the backup only when `status = 'completed'`, `size_bytes > 0`, `checksum` is
a 64-char hex string, and `error is null`. Keep `sai_backup_runs.id`, `checksum`
and `location` as the recovery-point attestation the manifest's
`execution_gates.recovery_attestation` expects.

### Recommended order once the backup is verified

1. Attest the backup (run id + checksum + location) in the external approval JSON.
2. `supabase migration repair --status applied <version> --linked`, **one version
   at a time**, for the 14 verified versions only. Never for `20261116142308` or
   `20261117202728` — their objects are genuinely absent.
3. Review and run `20261120120000_role_management_and_hold_infrastructure.sql`
   against the isolated database first, then Main.
4. Re-run the Super Admin dashboard indicator load as the acceptance check.

---

## 4. Not done here

- No local test execution — no shell and no local PostgreSQL in this environment.
- No hash generated by hand; the generator produces it deterministically instead.
- No `pg_dump`, no GitHub Actions dispatch, and no `git push` from here.