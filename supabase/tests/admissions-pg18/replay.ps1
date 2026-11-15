[CmdletBinding()]
param(
  [string]$PgBin,
  [string]$StateDirectory,
  [switch]$Run
)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$target = '20261115014149_protected_admission_status_events.sql'
$migrations = @(Get-ChildItem (Join-Path $repo 'supabase/migrations') -Filter '*.sql' | Sort-Object Name)
$targetIndex = [array]::IndexOf(@($migrations.Name), $target)
if ($targetIndex -lt 1) { throw 'Protected-events migration missing' }
$migrations = @($migrations | Select-Object -First ($targetIndex + 1))
$tests = @('security_invariants.sql','helper_execute_permissions.sql','admissions_behavior.sql',
  'admissions_tracking_behavior.sql','admission_event_integrity.sql','student_parent_access.sql')
foreach ($file in @('bootstrap.sql','seed_snapshot.sql','verify_snapshot.sql')) {
  if (!(Test-Path (Join-Path $PSScriptRoot $file))) { throw "Missing fixture: $file" }
}
foreach ($test in $tests) {
  if (!(Test-Path (Join-Path $repo "supabase/tests/$test"))) { throw "Missing test: $test" }
}
if (!$Run) {
  Write-Output "VALIDATION ONLY: $($migrations.Count) migrations through $target; six SQL suites; three fixtures. No server started."
  return
}
if (!$PgBin) { throw '-PgBin must name PostgreSQL 18 bin directory' }
$PgBin = [IO.Path]::GetFullPath($PgBin)
foreach ($exe in @('initdb.exe','pg_ctl.exe','psql.exe','postgres.exe')) {
  if (!(Test-Path (Join-Path $PgBin $exe))) { throw "Missing PostgreSQL executable: $exe" }
}
$version = & (Join-Path $PgBin 'postgres.exe') --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch 'PostgreSQL\) 18\.') { throw 'PostgreSQL 18 is required' }
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
if (!$StateDirectory) { $StateDirectory = Join-Path $tempRoot ('sai-admissions-pg18-' + [guid]::NewGuid()) }
$state = [IO.Path]::GetFullPath($StateDirectory).TrimEnd('\','/')
if ([IO.Path]::GetDirectoryName($state) -ine $tempRoot) {
  throw 'StateDirectory must be a new child directory of the OS temporary directory'
}
if (Test-Path -LiteralPath $state) { throw 'StateDirectory already exists; refusing to reuse or reset any cluster' }
if (@(Get-NetTCPConnection -State Listen -LocalPort 55439 -ErrorAction SilentlyContinue).Count) { throw 'Port 55439 occupied' }
New-Item -ItemType Directory -Path $state | Out-Null
$data = Join-Path $state 'data'
$log = Join-Path $state 'replay-and-tests.log'
$psql = Join-Path $PgBin 'psql.exe'
$pgctl = Join-Path $PgBin 'pg_ctl.exe'
$utf8 = [Text.UTF8Encoding]::new($false)
function Log([string]$message) { [IO.File]::AppendAllText($log, $message + "`n", $utf8) }
function Sql([string]$db, [string[]]$arguments, [string]$label) {
  Log(">>> $label")
  $result = & $psql -X -h 127.0.0.1 -p 55439 -U postgres -d $db -v ON_ERROR_STOP=1 @arguments 2>&1
  $code = $LASTEXITCODE
  foreach ($line in $result) { Log($line.ToString()) }
  if ($code -ne 0) { Log("FAIL exit=$code"); throw "$label failed; see $log" }
  Log('PASS'); Write-Output "PASS $label"
}
function MigrationFile([IO.FileInfo]$migration, [string]$db) {
  $file = $migration.FullName
  # The original migrations intentionally refuse existing owner roles. Roles
  # are cluster-wide; validate and reuse only the role created by the first DB.
  # These disposable copies preserve every database-local statement and ACL.
  if ($db -eq 'regression_test' -and $migration.Name -in @('007_finance.sql', $target)) {
    $sql = [IO.File]::ReadAllText($file)
    if ($migration.Name -eq '007_finance.sql') {
      $guard = "if exists (select 1 from pg_roles where rolname = 'sai_finance_owner') then"
      $create = 'create role sai_finance_owner nologin nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls;'
      if (!$sql.Contains($guard) -or !$sql.Contains($create)) { throw 'Finance role adapter requires review after migration change' }
      $sql = $sql.Replace($guard, "if not exists (select 1 from pg_roles where rolname = 'sai_finance_owner' and not rolcanlogin and not rolsuper and not rolcreatedb and not rolcreaterole and not rolinherit and not rolreplication and not rolbypassrls) then")
      $sql = $sql.Replace($create, '-- Existing isolated role validated above.')
    } else {
      $create = 'create role sai_admission_event_writer nologin nosuperuser nocreatedb nocreaterole noinherit nobypassrls;'
      if (!$sql.Contains($create)) { throw 'Event role adapter requires review after migration change' }
      $sql = $sql.Replace($create, @'
do $$ begin
  if not exists (select 1 from pg_roles where rolname='sai_admission_event_writer'
    and not rolcanlogin and not rolsuper and not rolcreatedb and not rolcreaterole
    and not rolinherit and not rolreplication and not rolbypassrls) then
    raise exception 'Unsafe shared event writer role';
  end if;
end $$;
'@)
    }
    $file = Join-Path $state ('shared-role-' + $migration.Name)
    [IO.File]::WriteAllText($file, $sql, $utf8)
  }
  Sql $db @('-f',$file) "Replay $db/$($migration.Name)"
}
$started = $false
try {
  Log("PostgreSQL $version; MIGRATION_COUNT=$($migrations.Count); TARGET=$target")
  # Loopback trust belongs only to this new disposable emulation cluster.
  & (Join-Path $PgBin 'initdb.exe') -D $data -U postgres --auth=trust --encoding=UTF8 --no-locale
  if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
  & $pgctl -D $data -l (Join-Path $state 'server.log') -o '-h 127.0.0.1 -p 55439' -w -t 60 start
  if ($LASTEXITCODE -ne 0) { throw 'pg_ctl start failed' }
  $started = $true
  $actual = & $psql -X -h 127.0.0.1 -p 55439 -U postgres -d postgres -At -c 'SHOW data_directory'
  if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($actual.Trim()) -ine $data) {
    throw 'SHOW data_directory does not match task-owned cluster'
  }
  Log("VERIFIED data_directory=$actual")
  foreach ($db in @('snapshot_replay','regression_test')) {
    Sql postgres @('-c',"CREATE DATABASE $db") "Create $db"
    Sql $db @('-f',(Join-Path $PSScriptRoot 'bootstrap.sql')) "Bootstrap $db"
  }
  foreach ($migration in $migrations[0..($migrations.Count - 2)]) {
    foreach ($db in @('snapshot_replay','regression_test')) { MigrationFile $migration $db }
  }
  Sql snapshot_replay @('-f',(Join-Path $PSScriptRoot 'seed_snapshot.sql')) 'Seed existing enquiry and forged audit'
  foreach ($db in @('snapshot_replay','regression_test')) { MigrationFile $migrations[-1] $db }
  Sql snapshot_replay @('-f',(Join-Path $PSScriptRoot 'verify_snapshot.sql')) 'Verify snapshot without forged audit backfill'
  foreach ($test in $tests) {
    $sql = [IO.File]::ReadAllText((Join-Path $repo "supabase/tests/$test"))
    $sql = [regex]::Replace($sql, '(?im)^begin;', "begin;`nset local sai.wave1_isolated_test = 'yes';")
    $file = Join-Path $state $test
    [IO.File]::WriteAllText($file, $sql, $utf8)
    Sql regression_test @('-f',$file) "SQL TEST $test"
  }
  Log('ALL PASS')
} catch {
  Log("RUN FAILURE: $($_.Exception.Message)")
  throw
} finally {
  # pg_ctl uses this task's absolute -D; never stop by port or kill another PID.
  if ($started -or (Test-Path (Join-Path $data 'postmaster.pid'))) {
    & $pgctl -D $data -m fast -w -t 180 stop
    if ($LASTEXITCODE -ne 0) { Log('STOP FAILURE'); throw "Could not stop isolated server: $data" }
    if (Test-Path (Join-Path $data 'postmaster.pid')) { throw 'postmaster.pid remains after stop' }
    Log('OWN CLUSTER STOPPED')
  }
  Write-Output "Replay artifacts (untracked, outside repository): $state"
}
