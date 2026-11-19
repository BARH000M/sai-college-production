param(
    [string]$ConfirmProjectRef,
    [switch]$Apply
)

$ErrorActionPreference = "Stop"

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$expected = "aeryusbrulqdxjdynwfh"
$targetPath = "$root\supabase\target.local.json"

if (-not (Test-Path $targetPath)) {
    throw "Missing target.local.json. Run CONFIGURE_BACKEND.ps1 first."
}

$target = Get-Content $targetPath -Raw | ConvertFrom-Json
$ref = $target.project_ref

if ($ref -ne $expected) {
    throw "Unauthorized Supabase project."
}

if ($ConfirmProjectRef -ne $expected) {
    throw "Project confirmation does not match."
}

if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
    throw "Supabase CLI is not installed."
}

Write-Host "PROJECT VERIFIED: $ref" -ForegroundColor Green

if (-not $Apply) {
    Write-Host "Preview only. Use -Apply to link."
    return
}

supabase link --project-ref $ref

if ($LASTEXITCODE -ne 0) {
    throw "Supabase linking failed."
}

$linked = (Get-Content "supabase\.temp\project-ref" -Raw).Trim()

if ($linked -ne $expected) {
    throw "Linked project verification failed."
}

Write-Host "SUPABASE LINKED SUCCESSFULLY" -ForegroundColor Green

supabase migration list --linked

if ($LASTEXITCODE -ne 0) {
    throw "Migration listing failed."
}