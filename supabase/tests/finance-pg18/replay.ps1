[CmdletBinding()]
param([string]$PgBin = 'D:/pgsql/bin')
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if ((& "$PgBin/postgres.exe" --version) -notmatch 'PostgreSQL\) 18\.') { throw 'PostgreSQL 18 required' }
$state = Join-Path ([IO.Path]::GetTempPath()) ('sai-finance-pg18-' + [guid]::NewGuid())
$data = Join-Path $state 'data'
$port = 55440
if (@(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue).Count) { throw 'Test port occupied' }
New-Item -ItemType Directory -Path $state | Out-Null
$started = $false
function Sql([string]$file) {
  try {
    $ErrorActionPreference = 'Continue'
    $result = & "$PgBin/psql.exe" -X -h 127.0.0.1 -p $port -U postgres -d postgres -v ON_ERROR_STOP=1 -f $file 2>&1
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = 'Stop' }
  $result | Out-File (Join-Path $state 'replay.log') -Encoding utf8 -Append
  if ($code -ne 0) { throw "Failed $file; see $state/replay.log" }
  Write-Output "PASS $([IO.Path]::GetFileName($file))"
}
try {
  & "$PgBin/initdb.exe" -D $data -U postgres --auth=trust --encoding=UTF8 --no-locale
  if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
  & "$PgBin/pg_ctl.exe" -D $data -l (Join-Path $state 'server.log') -o "-h 127.0.0.1 -p $port" -w -t 60 start
  if ($LASTEXITCODE -ne 0) { throw 'start failed' }
  $started = $true
  $actual = & "$PgBin/psql.exe" -X -h 127.0.0.1 -p $port -U postgres -d postgres -At -c 'show data_directory'
  if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($actual.Trim()) -ine $data) { throw 'Cluster identity mismatch' }
  Sql (Join-Path $repo 'supabase/tests/admissions-pg18/bootstrap.sql')
  foreach ($migration in (Get-ChildItem (Join-Path $repo 'supabase/migrations') -Filter '*.sql' | Sort-Object Name)) { Sql $migration.FullName }
  foreach ($test in @('finance_behavior.sql','finance_completion_behavior.sql','security_invariants.sql','helper_execute_permissions.sql')) {
    $sql = [IO.File]::ReadAllText((Join-Path $repo "supabase/tests/$test"))
    $sql = [regex]::Replace($sql, '(?im)^begin;', "begin;`nset local sai.finance_isolated_test = 'yes';`nset local sai.wave1_isolated_test = 'yes';")
    $file = Join-Path $state $test
    [IO.File]::WriteAllText($file, $sql, [Text.UTF8Encoding]::new($false))
    Sql $file
  }
} finally {
  if ($started -or (Test-Path (Join-Path $data 'postmaster.pid'))) {
    & "$PgBin/pg_ctl.exe" -D $data -m fast -w -t 60 stop
    if ($LASTEXITCODE -ne 0 -or (Test-Path (Join-Path $data 'postmaster.pid'))) { throw "Cluster stop failed: $data" }
    Write-Output 'OWN CLUSTER STOPPED'
  }
  Write-Output "Local test artifacts: $state"
}
