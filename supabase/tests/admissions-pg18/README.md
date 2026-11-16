# Admissions PostgreSQL 18 replay

The previously completed 33-migration / six-suite replay remains the SQL
validation evidence. Do not rerun it just to check this packaging change.

This directory contains the fixtures and driver needed for a future clean local
replay. No Copilot session files, hosted project configuration, passwords, logs,
database files, or downloaded binaries are required in Git.

From the repository root, validate the package without starting a server:

```powershell
pwsh -File supabase/tests/admissions-pg18/replay.ps1
```

When a new replay is explicitly required, supply an installed PostgreSQL 18 bin
directory and opt in with `-Run`:

```powershell
pwsh -File supabase/tests/admissions-pg18/replay.ps1 -PgBin 'C:\tools\pgsql18\bin' -Run
```

The Windows driver requires `Get-NetTCPConnection`, creates a unique directory
under the OS temporary directory, refuses existing state directories and an
occupied port 55439, starts a loopback-only disposable cluster, and compares
`SHOW data_directory` before creating either database. It never resets or opens
an existing cluster, including `D:\pgsql\data`. It stops its cluster in `finally`;
shutdown failure is an error. State is retained outside Git for inspection and
manual cleanup after verifying shutdown. Loopback trust authentication is only
for this short-lived, nonsensitive local emulation.

`snapshot_replay` receives an existing enquiry plus forged audit row before
protected events; the verification requires exactly one current-state snapshot
and no audit backfill. `regression_test` receives all six current repository SQL
suites. Transaction fixtures get the required local isolation marker.

Because roles are cluster-wide, the second database reuses the finance/event
writer roles created by the first. The driver checks all role security flags and
adapts only role creation in disposable SQL copies; repository migrations and
database-local ACLs remain unchanged. Adapter source mismatches fail closed.
The bootstrap includes `auth.users.raw_user_meta_data` and the seed uses an
authorized fixture identity, addressing the errors found in the earlier replay.

This is minimal Auth/Storage/PostgREST-role emulation, not a Supabase instance.
It cannot verify real JWT validation, gateway IP sanitization, hosted APIs,
email delivery, Realtime publication availability, or deployed migration state.
The packaged driver is validated without a database in the admissions closeout;
its complete execution has not been repeated.
