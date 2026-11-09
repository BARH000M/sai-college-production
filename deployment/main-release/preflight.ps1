[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$InspectDisposable,
    [int]$Port,
    [string]$Database = 'sai_disposable_main',
    [string]$ClusterId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $InspectDisposable -and ($PSBoundParameters.ContainsKey('Port') -or
    $PSBoundParameters.ContainsKey('Database') -or $PSBoundParameters.ContainsKey('ClusterId'))) {
    throw 'Target parameters require -InspectDisposable.'
}
Test-ReleaseFiles
if ($InspectDisposable) {
    $connection = Get-DisposableConnection -Port $Port -Database $Database -ClusterId $ClusterId
    Invoke-DisposableSql -Connection $connection -Mode preflight
}
Write-Warning 'BLOCKED: project identity, production state, full effective privileges, trusted restore evidence and history reconciliation remain UNVERIFIED.'
exit 2
