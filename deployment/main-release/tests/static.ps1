Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$repo = (Resolve-Path (Join-Path $root '..\..')).Path
$scripts = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse
foreach ($file in $scripts) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw "PowerShell parse errors in $($file.FullName): $errors" }
}
$candidate = Get-Content -Raw -LiteralPath (Join-Path $root 'sql\010_admissions_directory.sql')
$review = Get-Content -Raw -LiteralPath (Join-Path $repo 'docs\ADMISSIONS_SESSION_DIRECTORY_REVIEW_ONLY.sql')
$pattern = '(?s)create function public\.sai_admissions_sessions\(wanted_branch uuid\).*'
$candidateBody = [regex]::Match($candidate, $pattern).Value.Replace("`r`n", "`n").Trim()
$reviewBody = [regex]::Match($review, $pattern).Value.Replace("`r`n", "`n").Trim()
if (-not $candidateBody -or $candidateBody -cne $reviewBody) { throw 'Directory SQL differs from the review-only proposal.' }
if ($candidate -match '(?i)create\s+(or\s+replace\s+)?function\s+public\.sai_admissions_prepare') {
    throw 'Candidate replaces the MAIN admissions trigger function.'
}
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
& $pwsh -NoProfile -File (Join-Path $root 'test-disposable.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Static runner failed.' }
& $pwsh -NoProfile -File (Join-Path $root 'setup-disposable.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Static fixture setup check failed.' }
& $pwsh -NoProfile -File (Join-Path $root 'preflight.ps1')
if ($LASTEXITCODE -ne 2) { throw 'Offline preflight did not report blocked.' }
& $pwsh -NoProfile -File (Join-Path $root 'verify.ps1')
if ($LASTEXITCODE -ne 2) { throw 'Offline verification did not report blocked.' }
. (Join-Path $root 'common.ps1')
function Assert-Rejected {
    param([scriptblock]$Operation, [string]$Label)
    $rejected = $false
    try { & $Operation | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw "Unsafe input was accepted: $Label" }
}
$id = '1c215954-0513-46fd-95ef-36903cc1e150'
foreach ($db in @('postgres', 'sai_disposable_', 'sai_disposable_aeryusbrulqdxjdynwfh',
                  'sai_disposable_tvkohamtxrkppwcfsuex', 'sai_disposable_aeryusbrulqdxjdynwfh;host=evil',
                  'postgresql://remote/db', 'host=remote dbname=sai_disposable_main')) {
    Assert-Rejected { Get-DisposableConnection -Port 55439 -Database $db -ClusterId $id } "database $db"
}
foreach ($badId in @('', '00000000-0000-0000-0000-000000000000', "a';select 1;--",
                     'aeryusbrulqdxjdynwfh', '1C215954-0513-46FD-95EF-36903CC1E150')) {
    Assert-Rejected { Get-DisposableConnection -Port 55439 -Database 'sai_disposable_main' -ClusterId $badId } "cluster ID $badId"
}
foreach ($port in @(0, 543, 65536, -1)) {
    Assert-Rejected { Get-DisposableConnection -Port $port -Database 'sai_disposable_main' -ClusterId $id } "port $port"
}
foreach ($name in @('PGHOST', 'PGHOSTADDR', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGSERVICE',
                    'PGSERVICEFILE', 'PGOPTIONS', 'PGAPPNAME', 'PGSYSCONFDIR')) {
    $old = [Environment]::GetEnvironmentVariable($name)
    try {
        [Environment]::SetEnvironmentVariable($name, 'unsafe')
        Assert-Rejected { Get-DisposableConnection -Port 55439 -Database 'sai_disposable_main' -ClusterId $id } "environment $name"
    } finally { [Environment]::SetEnvironmentVariable($name, $old) }
}
foreach ($path in @('..\..\outside.sql', 'deployment\main-release\sql\020_attendance.sql',
                    'supabase\migrations\005_admissions_session_directory.sql')) {
    Assert-Rejected { Read-ReviewedSql $path } "SQL path $path"
}
foreach ($badArgs in @(
    @('-ProjectRef', 'aeryusbrulqdxjdynwfh'),
    @('-ProjectRef', 'tvkohamtxrkppwcfsuex'),
    @('-Host', 'example.com'),
    @('-ConnectionString', 'postgresql://example.com/db'),
    @('-Database', 'postgresql://example.com/db'),
    @('postgresql://example.com/db')
)) {
    & $pwsh -NoProfile -File (Join-Path $root 'test-disposable.ps1') @badArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { throw "Unexpected target argument accepted: $badArgs" }
}
& $pwsh -NoProfile -File (Join-Path $root 'setup-disposable.ps1') -Run -Port 55439 -Database 'postgresql://remote/db' -ClusterId $id 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) { throw 'Fixture setup accepted remote database URL.' }
$connection = Get-DisposableConnection -Port 55439 -Database 'sai_disposable_main' -ClusterId $id
if (($connection.Arguments -join '|') -cne '-X|-w|-v|ON_ERROR_STOP=1|-h|127.0.0.1|-p|55439|-d|sai_disposable_main|-U|sai_release_test|-f|-') {
    throw 'Unexpected psql argument list.'
}
foreach ($field in @('current_database()', 'current_user', 'session_user', 'inet_server_addr()', 'inet_server_port()', 'sai.disposable_cluster_id')) {
    if (-not $connection.Guard.Contains($field)) { throw "Guard missing $field" }
}
foreach ($mode in @('setup', 'preflight', 'verify', 'rehearsal')) {
    $inputText = New-DisposableInput -Connection $connection -Mode $mode
    if (-not $inputText.StartsWith($connection.Guard + "`n") -or $inputText.Contains('\')) {
        throw "Unsafe psql input stream in mode $mode"
    }
    $setup = New-DisposableInput -Connection $connection -Mode setup
    $embedded = [regex]::Matches($setup, "decode\('([A-Za-z0-9+/=]+)','base64'\)")
    if ($embedded.Count -ne 4) { throw 'Fixture must embed exactly four saved MAIN functions.' }
    $functions = @('sai_admissions_prepare', 'sai_admissions_audit',
                   'sai_public_admission_submit', 'sai_submit_application')
    for ($i = 0; $i -lt $functions.Count; $i++) {
        $actual = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($embedded[$i].Groups[1].Value))
        if ($actual -cne (Get-FixtureMainFunction $functions[$i])) {
            throw "Fixture source mismatch: $($functions[$i])"
        }
    }
    if ($setup.IndexOf('begin;') -lt $connection.Guard.Length -or
        $setup.IndexOf('create role anon') -gt $setup.IndexOf('create table public.profiles') -or
        $setup.IndexOf('create table public.admissions_enquiries') -gt $setup.IndexOf("decode('") -or
        $setup.IndexOf('Synthetic Student A') -gt $setup.IndexOf('Anonymous direct admission insert succeeded') -or
        $setup.IndexOf('Anonymous direct admission insert succeeded') -gt $setup.LastIndexOf('commit;')) {
        throw 'Unsafe fixture setup order.'
    }
}
$inputText = New-DisposableInput -Connection $connection -Mode rehearsal
if ($inputText.IndexOf('begin read only;') -gt $inputText.IndexOf('begin;') -or
    $inputText.IndexOf('begin;') -gt $inputText.IndexOf('create role sai_finance_owner') -or
    $inputText.IndexOf('create role sai_finance_owner') -gt $inputText.IndexOf("set sai.wave1_isolated_test = 'yes';")) {
    throw 'Unexpected rehearsal transaction ordering.'
}
Write-Host 'Static syntax, allowlist, guard ordering and fail-closed input checks passed; no database was contacted.'
