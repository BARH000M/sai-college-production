param(
    [string]$ProjectRef = "aeryusbrulqdxjdynwfh",
    [string]$PublishableKey
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent

if ($ProjectRef -ne "aeryusbrulqdxjdynwfh") {
    throw "Incorrect Yemen SAI Supabase project."
}

$url = "https://$ProjectRef.supabase.co"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$rootEnvPath = Join-Path $root ".env.local"
$webEnvPath = Join-Path $root "web\.env.local"
$mobilePath = Join-Path $root "mobile\config\live.json"
$targetPath = Join-Path $root "supabase\target.local.json"

foreach ($dir in @("web", "mobile", "supabase")) {
    if (-not (Test-Path (Join-Path $root $dir))) {
        throw "Missing project directory: $dir"
    }
}

function Get-EnvLines {
    param([Parameter(Mandatory)][string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return @(Get-Content -LiteralPath $Path)
    }
    return @()
}

function Get-EnvValue {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Lines,
        [Parameter(Mandatory)][string]$Name
    )

    foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Name))\s*=(.*)$") {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

$mobileConfig = [PSCustomObject]@{}
$targetConfig = [PSCustomObject]@{}

if (Test-Path -LiteralPath $mobilePath) {
    $mobileConfig = Get-Content -LiteralPath $mobilePath -Raw | ConvertFrom-Json
    if ($mobileConfig.SUPABASE_URL -and $mobileConfig.SUPABASE_URL -ne $url) {
        throw "Mobile configuration targets another database."
    }
    if ($mobileConfig.SAI_TARGET -and $mobileConfig.SAI_TARGET -ne "production") {
        throw "Mobile configuration uses an unsupported target."
    }
}

foreach ($path in @($rootEnvPath, $webEnvPath)) {
    $lines = @(Get-EnvLines -Path $path)
    foreach ($name in @("VITE_PUBLIC_SUPABASE_URL", "VITE_SUPABASE_URL")) {
        $configuredUrl = Get-EnvValue -Lines $lines -Name $name
        if ($configuredUrl -and $configuredUrl.TrimEnd("/") -ne $url) {
            throw "Web configuration targets another database."
        }
    }
    $configuredTarget = Get-EnvValue -Lines $lines -Name "VITE_SAI_TARGET"
    if ($configuredTarget -and $configuredTarget -ne "production") {
        throw "Web configuration uses an unsupported target."
    }
}

if (Test-Path -LiteralPath $targetPath) {
    $targetConfig = Get-Content -LiteralPath $targetPath -Raw | ConvertFrom-Json
    if ($targetConfig.project_ref -and $targetConfig.project_ref -ne $ProjectRef) {
        throw "Existing target configuration uses another project."
    }
    if ($targetConfig.supabase_url -and $targetConfig.supabase_url -ne $url) {
        throw "Existing target configuration uses another database."
    }
}

if ([string]::IsNullOrWhiteSpace($PublishableKey)) {
    $existingKeys = @()
    if ($mobileConfig.SUPABASE_PUBLIC_KEY) {
        $existingKeys += [string]$mobileConfig.SUPABASE_PUBLIC_KEY
    }
    foreach ($path in @($rootEnvPath, $webEnvPath)) {
        $lines = @(Get-EnvLines -Path $path)
        foreach ($name in @(
            "VITE_PUBLIC_SUPABASE_ANON_KEY",
            "VITE_SUPABASE_PUBLISHABLE_KEY",
            "VITE_SUPABASE_PUBLIC_KEY",
            "VITE_SUPABASE_ANON_KEY"
        )) {
            $existingKey = Get-EnvValue -Lines $lines -Name $name
            if ($existingKey) {
                $existingKeys += $existingKey
            }
        }
    }

    $distinctKeys = @($existingKeys | Where-Object { $_ } | Select-Object -Unique)
    if ($distinctKeys.Count -gt 1) {
        throw "Local public keys differ; reconcile them before configuration."
    }
    if ($distinctKeys.Count -eq 1) {
        $PublishableKey = $distinctKeys[0]
    }
}

if ([string]::IsNullOrWhiteSpace($PublishableKey)) {
    $PublishableKey = Read-Host "Paste your Supabase publishable key"
}

$PublishableKey = $PublishableKey.Trim()
if ($PublishableKey -notmatch '^sb_publishable_[A-Za-z0-9_-]+$') {
    throw "Invalid Supabase publishable key."
}

$managedEnvNames = 'VITE_(PUBLIC_SUPABASE_URL|PUBLIC_SUPABASE_ANON_KEY|SAI_TARGET|SUPABASE_URL|SUPABASE_PUBLISHABLE_KEY|SUPABASE_PUBLIC_KEY|SUPABASE_ANON_KEY)'
foreach ($path in @($rootEnvPath, $webEnvPath)) {
    $lines = @(Get-EnvLines -Path $path | Where-Object { $_ -notmatch "^\s*$managedEnvNames\s*=" })
    $lines += @(
        "VITE_PUBLIC_SUPABASE_URL=$url",
        "VITE_PUBLIC_SUPABASE_ANON_KEY=$PublishableKey",
        "VITE_SAI_TARGET=production"
    )
    [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), $utf8)
}

$mobileConfig | Add-Member -NotePropertyName "SAI_TARGET" -NotePropertyValue "production" -Force
$mobileConfig | Add-Member -NotePropertyName "SAI_PREVIEW" -NotePropertyValue "false" -Force
$mobileConfig | Add-Member -NotePropertyName "SUPABASE_URL" -NotePropertyValue $url -Force
$mobileConfig | Add-Member -NotePropertyName "SUPABASE_PUBLIC_KEY" -NotePropertyValue $PublishableKey -Force
[IO.File]::WriteAllText($mobilePath, ($mobileConfig | ConvertTo-Json -Depth 10), $utf8)

$targetConfig | Add-Member -NotePropertyName "project_ref" -NotePropertyValue $ProjectRef -Force
$targetConfig | Add-Member -NotePropertyName "supabase_url" -NotePropertyValue $url -Force
[IO.File]::WriteAllText($targetPath, ($targetConfig | ConvertTo-Json -Depth 10), $utf8)

Write-Host "Configured .env.local, web/.env.local, mobile/config/live.json, and supabase/target.local.json." -ForegroundColor Green
Write-Host "Project: $ProjectRef"
Write-Host "Public key: Configured"
