param([string]$PgBin, [int]$Port, [string]$DataDirectory, [string]$WorkDirectory)
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$psql=Join-Path $PgBin $(if ($IsWindows) {'psql.exe'} else {'psql'})
$env:PGHOST='127.0.0.1'; $env:PGPORT=[string]$Port
$env:PGUSER='postgres'; $env:PGDATABASE='phase3b_main'
$logRoot=$WorkDirectory
$script:manifestHash=('a'*64);$script:gitCommit=('b'*40)
$manifest=Get-Content -Raw (Join-Path $repoRoot 'supabase/deployment/phase7r/main-deployment-manifest.json') | ConvertFrom-Json
function Assert-True([bool]$Condition,[string]$Message) { if (!$Condition) { throw $Message } }
function Get-ManifestPath([string]$RelativePath) { return Join-Path $repoRoot $RelativePath }
function Write-Record { param($Step,$Status,$Message) }
function Invoke-Psql {
  param([string[]]$Arguments)
  $actual=(& $psql -X -h 127.0.0.1 -p $Port -U postgres -d phase3b_main -At -c 'show data_directory').Trim()
  Assert-True ([IO.Path]::GetFullPath($actual) -eq [IO.Path]::GetFullPath($DataDirectory)) 'Wrong isolated cluster'
  $output=@(& $psql @Arguments 2>&1);$code=$LASTEXITCODE
  if ($code -ne 0) { throw ($output -join "`n") }
  return [pscustomobject]@{Output=($output -join "`n");ExitCode=$code}
}
function Invoke-PsqlQuery([string]$Sql) {
  Invoke-Psql -Arguments @('-X','-h','127.0.0.1','-p',[string]$Port,'-U','postgres','-d','phase3b_main','-v','ON_ERROR_STOP=1','-At','-c',$Sql)
}
# Load only the actual SQL-step function, never the executor's entrypoint.
$tokens=$null;$parseErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'supabase/deployment/phase7r/Invoke-MainDeployment.ps1'),[ref]$tokens,[ref]$parseErrors)
Assert-True ($parseErrors.Count -eq 0) 'Executor has PowerShell parse errors'
$function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-SqlStep'},$true)
Invoke-Expression $function.Extent.Text
$step=@($manifest.steps | Where-Object id -eq 'phase3c-own-contact-validation')[0]
Invoke-SqlStep -Step $step
$receipt=Invoke-PsqlQuery "select count(*) from private.sai_deployment_packages where package_id='phase3c-own-contact-validation' and git_commit='$script:gitCommit';"
Assert-True ($receipt.Output.Trim() -eq '1') 'Successful SQL missing its atomic receipt'
$rejected=$false
try { Invoke-SqlStep -Step $step } catch {
  if ($_.Exception.Message -notmatch 'Package already recorded') { throw }
  $rejected=$true
}
Assert-True $rejected 'Package retry was accepted'
# Force a real postcondition failure using an empty, valid transaction file.
$bad=Join-Path $logRoot 'bad-package.sql'
[IO.File]::WriteAllText($bad,"begin;`ncreate table public.phase7m_failed_package_probe(id int);`ncommit;`n")
$badStep=[pscustomobject]@{id='phase7m-finance';path=[IO.Path]::GetRelativePath($repoRoot,$bad)}
$manifest.required_source_files+= [pscustomobject]@{path=$badStep.path;sha256=(Get-FileHash -LiteralPath $bad -Algorithm SHA256).Hash.ToLowerInvariant()}
$saved=[IO.File]::ReadAllText($bad)
[IO.File]::AppendAllText($bad,"-- changed after preflight`n")
$rejected=$false
try { Invoke-SqlStep -Step $badStep } catch {
  if ($_.Exception.Message -notmatch 'Package changed after manifest preflight') { throw }
  $rejected=$true
}
Assert-True $rejected 'Package changed after preflight was accepted'
[IO.File]::WriteAllText($bad,$saved,[Text.UTF8Encoding]::new($false))
$rejected=$false
try { Invoke-SqlStep -Step $badStep } catch {
  if ($_.Exception.Message -notmatch 'Package postcondition failed') { throw }
  $rejected=$true
}
Assert-True $rejected 'Failed package postcondition was accepted'
$result=Invoke-PsqlQuery "select case when to_regclass('public.phase7m_failed_package_probe') is null and not exists(select 1 from private.sai_deployment_packages where package_id='phase7m-finance') then 'OK' else 'FAIL' end;"
Assert-True ($result.Output.Trim() -eq 'OK') 'Failed package DDL or receipt escaped rollback'
Remove-Item -LiteralPath $bad
Write-Output 'PASS: actual executor package receipt, retry rejection, postcondition failure and atomic rollback'
