Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:BundleRoot = $PSScriptRoot
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# These are the only SQL inputs the runner may execute. Hashes cover the
# actual bytes read into the input stream, not a later file lookup by psql.
$script:SqlManifest = [ordered]@{
    'deployment\main-release\fixtures\010_bootstrap.sql' = 'A0919CFB11528B504DB817F06A1E46D39C3412989556612273E403F43791C579'
    'deployment\main-release\fixtures\020_main_admissions_overlay.sql' = '641D7B6FE8CC8CDAD1B38A28AA0564AB4359D7C7B414905F10672CD509454B3B'
    'deployment\main-release\fixtures\030_synthetic_data.sql' = '4D50F1A094063EF4B19359C65D2D0746BFC9EF110B772B86A3408D19FB397180'
    'deployment\main-release\tests\fixture_security.sql' = '44CDF3350AC47CB4BEF085E04569F593F384E78449B749887CC7CB52DAB8DA3E'
    'supabase\migrations\001_initial_schema.sql' = 'F88DA7F1B53DA4CE0EDEDDFA91FF002B5501FB644BC07E068DB2E50DAA5F7BCB'
    'supabase\migrations\002_security_policies.sql' = 'B3A99C954D76AE102422BEA4754F1B0FA180DABE3EEEE123C83FA6A2939B776C'
    'supabase\migrations\003_staff_management_policies.sql' = '7663AF295A84AD266DC592F9C5FE869E77EEEF96519BE36CE111A10BEDE74744'
    'supabase\migrations\004_admissions.sql' = '59DFE557DE7786D9AB4237FE4FF34FBC03D9674F513D747E7ACD5DF641723FE9'
    'database-backups\main_schema.sql' = 'E0E4168D281ABA5B8CC3C0B3F34B510B385203822662B79639F616BADA139F06'
    'deployment\main-release\sql\preflight.sql' = 'B1486CB52C28A8D8BCB27DB8F93A053F3B8EC9D228B4EEC0390376CF55F97DBF'
    'deployment\main-release\tests\capture_admissions.sql' = '98680C61ACAF0A7A7465E51F5D4C734EA0F39DDB91831321CDADA4140F4D39C6'
    'deployment\main-release\sql\010_admissions_directory.sql' = 'E31D5B9ECB69C69F5353558ED09FAF5E78FA4089005A8B01D7FF08535742B8A4'
    'supabase\migrations\006_attendance.sql' = 'CBFAD5A4A73D03EDDD0F80520905498BEDE46252AEE5CE4D25AE28DF20DD643E'
    'supabase\migrations\007_finance.sql' = '628A7297753F8C062DE0BD7F308DFBB16B7C012C33622C7F95F46B87BFC34B9B'
    'deployment\main-release\tests\preserved_admissions.sql' = 'E1F4529CF38F8FC0A5B837DF7D23E1F8044C9F9BD4AFAC1C3DF8C89835344182'
    'deployment\main-release\sql\verify.sql' = '61110D8440974A8C574B6E66D205AB07B0F464E7665025A60E3C98A6CD98A89D'
    'deployment\main-release\tests\public_admissions.sql' = 'BE72B31DDAD96DC045003898EE812BF12B2CF102D90E192AC6B66C667D935E1F'
    'deployment\main-release\tests\permissions.sql' = 'D146115508011BC031603944C50A11C697D0BCF2819F79D2AB1F700D7CCFA376'
    'supabase\tests\admissions_behavior.sql' = '8161D58F4AAC45C411A16ED2F6385CD23C3145EB78FCB07AC000F36DD29D8106'
    'supabase\tests\attendance_behavior.sql' = '75DF9DCB2457061D02E10D43C721419529848292797F61B7A008DE6A231617FA'
    'supabase\tests\finance_behavior.sql' = 'A62E71C23799C4BBB6D3EB4845BFC9FCE96950DE9670DBA9D76B7C475D670E87'
}

function Read-ReviewedSql {
    param([Parameter(Mandatory)][string]$Name)
    if (-not $script:SqlManifest.Contains($Name)) { throw "SQL file is not allowlisted: $Name" }
    $current = $script:RepoRoot
    $ancestor = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    while ($null -ne $ancestor) {
        if (($ancestor.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are not permitted in SQL paths: $($ancestor.FullName)"
        }
        $ancestor = $ancestor.Parent
    }
    foreach ($component in ($Name -split '\\')) {
        $current = Join-Path $current $component
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are not permitted in SQL paths: $current"
        }
    }
    $bytes = [System.IO.File]::ReadAllBytes($current)
    $actual = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))
    if ($actual -cne $script:SqlManifest[$Name]) { throw "Reviewed SQL hash mismatch: $Name" }
    $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    if (($Name -cne 'database-backups\main_schema.sql' -and $text.Contains('\')) -or $text.Contains([char]0)) {
        throw "Backslashes and NULs are not allowed in SQL inputs: $Name"
    }
    return $text
}

function Get-FixtureMainFunction {
    param([Parameter(Mandatory)][ValidateSet('sai_admissions_prepare', 'sai_admissions_audit',
        'sai_public_admission_submit', 'sai_submit_application')][string]$Name)
    $snapshot = Read-ReviewedSql 'database-backups\main_schema.sql'
    $pattern = '(?ms)^CREATE FUNCTION public\.' + [regex]::Escape($Name) +
        '\([^\r\n]*\).*?^\$(?:_)?\$;'
    $matches = [regex]::Matches($snapshot, $pattern)
    if ($matches.Count -ne 1) { throw "Expected one function definition in MAIN snapshot: $Name" }
    $definition = $matches[0].Value
    if ($Name -in @('sai_admissions_prepare', 'sai_admissions_audit')) {
        $definition = $definition.Replace('CREATE FUNCTION public.', 'CREATE OR REPLACE FUNCTION public.')
    }
    return $definition
}

function Test-ReleaseFiles {
    foreach ($name in $script:SqlManifest.Keys) { [void](Read-ReviewedSql -Name $name) }
    Write-Host 'All allowlisted SQL bytes match reviewed hashes; no psql include commands are accepted.'
}

function Get-DisposableConnection {
    param([int]$Port, [string]$Database, [string]$ClusterId)
    if ($Port -lt 1024 -or $Port -gt 65535) { throw 'Specify an isolated local port from 1024 to 65535.' }
    if ($Database -cnotmatch '^sai_disposable_[a-z0-9_]{1,48}$' -or
        $Database -match 'aeryusbrulqdxjdynwfh|tvkohamtxrkppwcfsuex') {
        throw 'Invalid disposable database name.'
    }
    if ($ClusterId -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' -or
        $ClusterId -ceq '00000000-0000-0000-0000-000000000000') {
        throw 'ClusterId must be the independently provisioned nonzero lowercase UUID.'
    }
    foreach ($variable in Get-ChildItem Env:) {
        if ($variable.Name -match '^PG' -and $variable.Name -ne 'PGPASSWORD' -and
            -not [string]::IsNullOrEmpty($variable.Value)) {
            throw "Unset PostgreSQL environment variable $($variable.Name); only disposable PGPASSWORD is permitted."
        }
    }
    return @{
        Arguments = @('-X', '-w', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1', '-p', "$Port",
            '-d', $Database, '-U', 'sai_release_test', '-f', '-')
        Guard = "DO `$guard`$ BEGIN IF current_database() <> '$Database' OR current_user <> 'sai_release_test' OR session_user <> 'sai_release_test' OR inet_server_addr() IS DISTINCT FROM '127.0.0.1'::inet OR inet_server_port() IS DISTINCT FROM $Port OR current_setting('sai.disposable_cluster_id', true) IS DISTINCT FROM '$ClusterId' THEN RAISE EXCEPTION 'Disposable target verification failed'; END IF; END `$guard`$;"
    }
}

function New-DisposableInput {
    param(
        [Parameter(Mandatory)][hashtable]$Connection,
        [Parameter(Mandatory)][ValidateSet('setup', 'preflight', 'verify', 'rehearsal')][string]$Mode
    )
    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add($Connection.Guard)
    if ($Mode -eq 'setup') {
        $parts.Add('begin;')
        foreach ($name in @(
            'deployment\main-release\fixtures\010_bootstrap.sql',
            'supabase\migrations\001_initial_schema.sql',
            'supabase\migrations\002_security_policies.sql',
            'supabase\migrations\003_staff_management_policies.sql',
            'supabase\migrations\004_admissions.sql'
        )) { $parts.Add((Read-ReviewedSql $name)) }
        foreach ($name in @('sai_admissions_prepare', 'sai_admissions_audit',
                            'sai_public_admission_submit', 'sai_submit_application')) {
            $definition = Get-FixtureMainFunction $name
            $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($definition))
            $parts.Add("DO `$fixture`$ BEGIN EXECUTE convert_from(decode('$encoded','base64'),'UTF8'); END `$fixture`$;")
        }
        foreach ($name in @(
            'deployment\main-release\fixtures\020_main_admissions_overlay.sql',
            'deployment\main-release\fixtures\030_synthetic_data.sql',
            'deployment\main-release\tests\fixture_security.sql',
            'deployment\main-release\sql\preflight.sql'
        )) { $parts.Add((Read-ReviewedSql $name)) }
        $parts.Add('commit;')
    }
    if ($Mode -eq 'preflight' -or $Mode -eq 'rehearsal') {
        $parts.Add('begin read only;')
        $parts.Add((Read-ReviewedSql 'deployment\main-release\sql\preflight.sql'))
        $parts.Add('commit;')
    }
    if ($Mode -eq 'verify') {
        $parts.Add('begin read only;')
        $parts.Add((Read-ReviewedSql 'deployment\main-release\sql\verify.sql'))
        $parts.Add('commit;')
    }
    if ($Mode -eq 'rehearsal') {
        $parts.Add('begin;')
        foreach ($name in @(
            'deployment\main-release\tests\capture_admissions.sql',
            'deployment\main-release\sql\010_admissions_directory.sql',
            'supabase\migrations\006_attendance.sql',
            'supabase\migrations\007_finance.sql',
            'deployment\main-release\tests\preserved_admissions.sql',
            'deployment\main-release\sql\verify.sql'
        )) { $parts.Add((Read-ReviewedSql $name)) }
        $parts.Add('commit;')
        foreach ($test in @(
            @('sai.wave1_isolated_test', 'deployment\main-release\tests\public_admissions.sql'),
            @('sai.wave1_isolated_test', 'deployment\main-release\tests\permissions.sql'),
            @('sai.wave1_isolated_test', 'supabase\tests\admissions_behavior.sql'),
            @('sai.attendance_isolated_test', 'supabase\tests\attendance_behavior.sql'),
            @('sai.finance_isolated_test', 'supabase\tests\finance_behavior.sql')
        )) {
            $parts.Add("set $($test[0]) = 'yes';")
            $parts.Add((Read-ReviewedSql $test[1]))
        }
    }
    return ($parts -join "`n") + "`n"
}

function Invoke-DisposableSql {
    param([hashtable]$Connection, [ValidateSet('setup', 'preflight', 'verify', 'rehearsal')][string]$Mode)
    $inputText = New-DisposableInput -Connection $Connection -Mode $Mode
    $psql = Get-Command psql -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $inputText | & $psql.Source @($Connection.Arguments)
    if ($LASTEXITCODE -ne 0) { throw "psql failed with exit code $LASTEXITCODE; inspect the disposable database." }
}
