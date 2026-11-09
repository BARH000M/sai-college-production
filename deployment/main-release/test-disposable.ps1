[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Run,
    [int]$Port,
    [string]$Database = 'sai_disposable_main',
    [string]$ClusterId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $Run -and ($PSBoundParameters.ContainsKey('Port') -or
    $PSBoundParameters.ContainsKey('Database') -or $PSBoundParameters.ContainsKey('ClusterId'))) {
    throw 'Target parameters require -Run.'
}
Test-ReleaseFiles
if (-not $Run) {
    Write-Host 'Static checks only; no database connection or SQL execution.'
    exit 0
}
$connection = Get-DisposableConnection -Port $Port -Database $Database -ClusterId $ClusterId
Invoke-DisposableSql -Connection $connection -Mode rehearsal
Write-Host 'Disposable assertions completed. This does not establish production readiness.'
