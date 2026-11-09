# MAIN release candidate — BLOCKED

This bundle is **review and isolated rehearsal only**, not a production
deployment tool. MAIN is `aeryusbrulqdxjdynwfh`; STAGING is
`tvkohamtxrkppwcfsuex`. The scripts accept no remote host, URI, connection
string or project reference and explicitly target loopback. A loopback
connection can still reach a remote database through a tunnel or proxy, so
independently verify and isolate the local cluster. There is no production
executor or history/ledger writer. Production
catalog checks, actual executor privileges and independently verified backup
readiness remain **UNVERIFIED**. Do not deploy until the
[checklist](RELEASE_CHECKLIST.md) is complete.

## What is in this candidate

1. `sql/010_admissions_directory.sql` adds the session-directory function and
   grants in one transaction without replacing the existing MAIN preparation,
   audit or public submit functions. It fails if the directory exists or
   expected triggers/functions are absent. It does not fix or validate MAIN's
   custom-GUC bypass or JWT claim impersonation.
2. The runner reads the **unchanged** repository 006 and 007 directly from a
   fixed allowlist, validates the bytes it reads against pinned SHA-256 values,
   and embeds them in its one input stream. `sql/020_attendance.sql` and
   `sql/030_finance.sql` remain review-only wrappers; the runner never reads
   or executes them or any psql include. All executable SQL inputs have pinned
   hashes, reject backslashes and NULs, and reject reparse points along their
   paths. The executable input consists solely of allowlisted bytes held in
   memory, so a later file replacement cannot change that session's SQL.
   Record and review a signed manifest of **all** exact files and runner code
   before any future release. The finance role, grants,
   RLS, functions and ownership are not weakened by this bundle; their
   adequacy on MAIN is unverified.
3. `sql/preflight.sql` checks a subset of expected history, dependencies,
   version and privileges and prints catalog evidence. It does not establish
   every needed privilege, ownership, effective policy, trigger definition,
   project identity, production state or backup. `sql/verify.sql` asserts a
   subset of postconditions, not every security or behavior requirement.
   Their PowerShell wrappers connect only to an explicitly identified local
   disposable cluster and accept no project reference. Both deliberately
   exit 2 (BLOCKED), even when their local checks pass.
4. `test-disposable.ps1` defaults to offline source checks. With `-Run`, one
   `psql` process receives a single constructed stdin stream, with
   `ON_ERROR_STOP=1`, a target guard first, read-only preflight next, and only
   then the candidate and tests. The guard checks database, current and session
   user, loopback server address, port and cluster marker on **that same
   connection**. A guard error stops psql before any subsequent SQL. SQL input
   cannot contain psql commands such as reconnect or include. No separate
   connection authorizes another connection.
   It does not implement a production runner or write migration history.
   A successful run is not production authorization.

## Supabase migration history

The reported MAIN history is 001–004; STAGING is 001–007. Original 005
replaces MAIN's admissions trigger and must not run independently on MAIN.
The directory candidate is not the original 005, so **do not record 005 as
applied**. Likewise 020/030 are bundle artifacts, not evidence that Supabase
recorded 006/007. `psql` does not update Supabase migration history. This
bundle writes no separate ledger either; designing an atomic, auditable
runner and actual execution ledger, plus supported future convergence, is
still a blocker. Disabling automatic replay only during deployment is
insufficient. Keep all MAIN auto-migration paths disabled/controlled until
the whole future strategy is proven; do not use `db push`, migration repair,
manual history inserts, or a later 008 to conceal the divergence.

## Local static checks

From `D:\SAI-College-Production` in PowerShell:

```powershell
pwsh -NoProfile -File .\deployment\main-release\tests\static.ps1
pwsh -NoProfile -File .\deployment\main-release\setup-disposable.ps1
pwsh -NoProfile -File .\deployment\main-release\test-disposable.ps1
pwsh -NoProfile -File .\deployment\main-release\preflight.ps1
```

The preflight exits 2 intentionally: no proof of the live target, backup, or
deployment privileges has been supplied. Static checks do not test SQL
execution or verify a backup.

## Disposable rehearsal (future, native tools, no Docker)

### Future Windows PowerShell initialization — do not run against live data

These are instructions for a later authorized rehearsal, **not commands run
in this task**. Use PowerShell 7 and the installed PostgreSQL 17.11 binaries.
This creates a fresh local superuser and SCRAM password; use a
disposable-only password. Do not use any live project credentials, database,
cluster directory, port forwarding or proxy. Limit local access to the
authorized operator and confirm no other listener occupies the port.

```powershell
Set-Location D:\SAI-College-Production
$pgBin = 'C:\Program Files\PostgreSQL\17\bin'
$env:PATH = "$pgBin;$env:PATH"
Get-Command initdb, pg_ctl, pg_isready, createdb, psql -ErrorAction Stop
& (Join-Path $pgBin 'psql.exe') --version
if ($LASTEXITCODE -ne 0) { throw 'psql version check failed.' }
foreach ($v in Get-ChildItem Env: | Where-Object Name -Match '^PG') {
    Remove-Item -LiteralPath ("Env:" + $v.Name)
}
$clusterId = [guid]::NewGuid().ToString()
$clusterRoot = Join-Path $env:LOCALAPPDATA ("SAI-disposable-" + $clusterId)
if (Test-Path -LiteralPath $clusterRoot) { throw 'Cluster path already exists.' }
New-Item -ItemType Directory -Path $clusterRoot -ErrorAction Stop | Out-Null
$principal = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $clusterRoot /inheritance:r /grant:r "${principal}:(OI)(CI)F"
if ($LASTEXITCODE -ne 0) { throw 'Could not restrict cluster directory ACL.' }
$dataDir = Join-Path $clusterRoot 'data'
$logFile = Join-Path $clusterRoot 'postgres.log'
& initdb -D $dataDir -U sai_release_test --auth-host=scram-sha-256 --auth-local=scram-sha-256 --pwprompt
if ($LASTEXITCODE -ne 0) { throw 'initdb failed; do not continue.' }
Add-Content -LiteralPath (Join-Path $dataDir 'postgresql.conf') -Encoding utf8 -Value @(
    "listen_addresses = '127.0.0.1'"
    "port = 55439"
    "sai.disposable_cluster_id = '$clusterId'"
)
& pg_ctl -D $dataDir -l $logFile start
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL start failed; inspect log.' }
& pg_isready -h 127.0.0.1 -p 55439 -U sai_release_test
if ($LASTEXITCODE -ne 0) { throw 'Disposable server is not ready.' }
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Disposable password' -AsSecureString)).Password
try {
    & createdb -w -h 127.0.0.1 -p 55439 -U sai_release_test sai_disposable_main
    if ($LASTEXITCODE -ne 0) { throw 'Disposable database creation failed.' }
    Write-Host "Created isolated cluster $clusterId at $clusterRoot."
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
```

The configured UUID, loopback address and database name are **accident
guards**, not authentication or proof that the listener is not a tunnel.
Independently verify the running process, port owner, data directory and
network isolation before every run. The initdb account is a superuser: never
use it outside this dedicated cluster. Do not reuse the marker. The runner
rejects every nonempty `PG*` environment variable except `PGPASSWORD`; it
sets host, port, user and database explicitly. `psql -w` does not prompt.
The password is temporarily present in process memory/environment and must be
limited to the disposable credential; remove it afterward.

### Synthetic baseline setup

The [fixture files](fixtures/) and `setup-disposable.ps1` provide a **candidate**
MAIN-like baseline. The guarded setup transaction creates test-only `auth.users`,
`auth.uid()`, anon/authenticated roles, applies the pinned local 001–004
sources, and replaces the admissions prepare/audit functions with their exact
saved MAIN bodies. It installs the two saved MAIN public submission functions,
removes the directory that local 004 creates but the saved MAIN dump lacks,
reproduces MAIN's application-number default, and inserts synthetic people and
branches. Exact saved function statements are hash-checked and encoded into
the input stream; their SQL bodies are not rewritten. Existing trigger
attachments survive the `CREATE OR REPLACE` of the two trigger functions.

The local history table contains **synthetic test labels** for 001–004: local
004 and the MAIN overlay are not a claim about what MAIN actually executed.
This is not a restore or a production baseline. The dump omits owners and
ACLs; public-function grants and Supabase roles in this fixture are explicit
test assumptions. The `auth.uid()` implementation is a minimal claim stub,
not Supabase Auth. Local 001–004 RLS and grants provide test behavior but may
not match MAIN's actual policies or effective privileges. The fixture does
not reproduce all production-only functions, event triggers, extensions,
integration configuration, data, or default privileges. It cannot establish
MAIN behavior or security, nor model PostgREST, real JWT validation or pooling.

The fixture grants `authenticated` only `USAGE` on the application-number
sequence. This enables direct staff inserts that run as that shared database
role; it does not grant anonymous access or `UPDATE`/`setval`. Any authenticated
user can nevertheless call `nextval` directly and consume numbers, including
users who cannot insert an enquiry. Sequence usage does not override admission
RLS, column grants, or trigger validation. MAIN's effective sequence ACL and
owner are absent from the saved dump and remain **UNVERIFIED**; this fixture
grant is not evidence that MAIN should or does use the same permission.

Setup refuses a non-fresh cluster/database, verifies PostgreSQL 17.11, and
runs fixture-specific anonymous submission and RLS denial checks plus the
existing preflight before committing. These checks are **not executed yet**;
if any fail the transaction must roll back. Never weaken a failed preflight.
Never put real personal data into the fixture.

The earlier failed rehearsal committed release DDL before the admission test.
Do not rerun it against that database. Follow the initialization commands above
to create a **new cluster with a new UUID and a fresh database**, verify that
the chosen port is free and the listener is not a tunnel, then run setup and
the rehearsal below. Do not reset or modify the earlier cluster as a shortcut.

```powershell
# Only after verifying the process, data directory, port and cluster ID:
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Disposable password' -AsSecureString)).Password
try {
    pwsh -NoProfile -File .\deployment\main-release\setup-disposable.ps1 `
      -Run -Port 55439 -Database sai_disposable_main -ClusterId $clusterId
    if ($LASTEXITCODE -ne 0) { throw 'Fixture setup failed; do not run tests.' }
    pwsh -NoProfile -File .\deployment\main-release\test-disposable.ps1 `
      -Run -Port 55439 -Database sai_disposable_main -ClusterId $clusterId
    if ($LASTEXITCODE -ne 0) { throw 'Disposable rehearsal failed.' }
} finally {
    Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
}
# When finished, stop only this independently identified cluster:
& pg_ctl -D $dataDir stop -m fast
if ($LASTEXITCODE -ne 0) { throw 'Disposable cluster did not stop cleanly.' }
```

Setup is one guarded psql session and one transaction, including checks before
commit. It is not idempotent: a second invocation rejects existing fixture
roles or objects. The target guard applies to the same connection as setup;
the marker and loopback address still do not rule out a tunnel. If setup fails,
inspect the isolated database and cluster roles before retrying; create a
fresh disposable cluster rather than dropping unknown objects. The test runner
uses a separate guarded connection; setup does not authorize that connection.
No live history is changed.

### Teardown

The `pg_ctl ... stop` command above stops only the cluster named by `$dataDir`.
After independently confirming the exact local directory, its contents and
that it contains no data requiring retention, an operator may remove the
specific `$clusterRoot` with `Remove-Item -LiteralPath $clusterRoot -Recurse`.
Do not use a wildcard or remove a parent directory. If target identity or
contents are uncertain, leave the files in place and investigate.

The guard runs before the read-only preflight transaction. The candidate DDL,
baseline comparisons and structural verification are wrapped in a **second,
explicit transaction**, which commits before the individual tests. Each
existing test manages its own transaction/rollback; the tests and the whole
stream are **not atomic together**. A post-commit test failure leaves DDL
committed in the disposable database. Sequence values can advance even on
rollback. The script is **not** a dry run. Use a fresh cluster per rehearsal; it deliberately
fails if attendance/finance objects or the directory already exist. The
DDL transaction is not evidence that a future production runner
can atomically commit each artifact with an independent ledger. It also does
not cover real concurrent transactions, pooled requests, all ACLs or every
actor case: see the checklist and
[strategy](../../docs/MAIN_SAFE_MIGRATION_STRATEGY.md).

## Recovery

Before any real release, verify a recent consistent backup by a successful
isolated test restore and data, role/ACL, sequence, Storage, configuration and
integration checks; an archive or table-of-contents listing alone is not
proof. Define RPO/RTO, a freeze and incident owners. If DDL fails inside an
actual transaction, inspect both schema and any execution record after
rollback; other committed transactions and consumed sequences may remain.
If writes have committed, preserve records and audit evidence, stop affected
features, and prefer a reviewed forward correction. Financial payments,
refunds and external settlements may require approved compensating
transactions and reconciliation rather than destructive restore. If restore
is necessary, restore to a separate protected target, validate it, reconcile
all later writes and external payments, and execute an approved cutover.
