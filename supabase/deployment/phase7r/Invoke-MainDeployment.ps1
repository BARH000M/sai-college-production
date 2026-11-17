[CmdletBinding()]
param(
  [switch]$Execute,
  [string]$ProjectRef = "aeryusbrulqdxjdynwfh",
  [string]$ApprovalFile,
  [string]$RecoveryAttestationFile,
  [string]$ExternalHoldAttestationFile,
  [string]$ManifestPath,
  [string]$PsqlPath,
  [string]$LogDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\.."))
$expectedOrigin = "https://github.com/BARH000M/sai-college-production.git"
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
  $ManifestPath = Join-Path $PSScriptRoot "main-deployment-manifest.json"
}
if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
  $LogDirectory = Join-Path $env:LOCALAPPDATA "SAI-Production\deployment-records"
}
$logFile = $null
$script:manifestHash = "unavailable"
$script:executorHash = "unavailable"
$script:gitCommit = "unavailable"
$script:holdActivated = $false
$logRoot = [IO.Path]::GetFullPath($LogDirectory)
if ($logRoot.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Deployment records must be stored outside the repository."
}
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
$logFile = Join-Path $logRoot ("phase7r-main-" + [DateTimeOffset]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" + [guid]::NewGuid().ToString("N") + ".jsonl")
New-Item -ItemType File -Path $logFile | Out-Null

function Write-Record {
  param(
    [Parameter(Mandatory)][string]$Step,
    [Parameter(Mandatory)][string]$Status,
    [Parameter(Mandatory)][string]$Message
  )

  $record = [ordered]@{
    timestamp_utc = [DateTimeOffset]::UtcNow.ToString("o")
    step = $Step
    status = $Status
    message = $Message
    project_ref = $ProjectRef
    manifest_sha256 = $script:manifestHash
    git_commit = $script:gitCommit
  }
  $record | ConvertTo-Json -Compress | Add-Content -LiteralPath $script:logFile -Encoding UTF8
}

function Invoke-External {
  param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string[]]$Arguments
  )

  $output = & $Executable @Arguments 2>&1
  $exitCode = $LASTEXITCODE
  $text = (@($output) | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
  [pscustomobject]@{ ExitCode = $exitCode; Output = $text }
}

function Invoke-SupabaseJson {
  param([Parameter(Mandatory)][string[]]$Arguments)

  $result = Invoke-External -Executable $script:supabasePath -Arguments $Arguments
  if ($result.ExitCode -ne 0) {
    throw "Supabase CLI read-only preflight failed (exit $($result.ExitCode))."
  }
  try {
    return ConvertFrom-Json -InputObject $result.Output
  }
  catch {
    throw "Supabase CLI did not return valid JSON for the requested preflight."
  }
}

function Assert-True {
  param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Get-ManifestPath {
  param([Parameter(Mandatory)][string]$RelativePath)
  if ([IO.Path]::IsPathRooted($RelativePath)) {
    throw "Manifest paths must be repository-relative."
  }
  $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $RelativePath))
  if (-not $fullPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Manifest path escapes the repository."
  }
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    throw "Manifest source file is missing: $RelativePath"
  }
  return $fullPath
}

function Test-RecentUtc {
  param(
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][int]$MaximumAgeMinutes
  )
  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse($Value, [ref]$parsed)) { return $false }
  return $parsed -le [DateTimeOffset]::UtcNow.AddMinutes(2) -and
    $parsed -ge [DateTimeOffset]::UtcNow.AddMinutes(-$MaximumAgeMinutes)
}

function Test-FutureUtc {
  param(
    [Parameter(Mandatory)][string]$Value,
    [Parameter(Mandatory)][int]$MaximumFutureMinutes
  )
  $parsed = [DateTimeOffset]::MinValue
  if (-not [DateTimeOffset]::TryParse($Value, [ref]$parsed)) { return $false }
  return $parsed -gt [DateTimeOffset]::UtcNow -and
    $parsed -le [DateTimeOffset]::UtcNow.AddMinutes($MaximumFutureMinutes)
}

function Invoke-Psql {
  param(
    [Parameter(Mandatory)][string[]]$Arguments,
    [switch]$ExpectedFailure
  )
  $result = Invoke-External -Executable $script:psqlPath -Arguments $Arguments
  if (-not $ExpectedFailure -and $result.ExitCode -ne 0) {
    throw "PostgreSQL command failed (exit $($result.ExitCode)); details are not written to the deployment log."
  }
  return $result
}

function Invoke-PsqlQuery {
  param([Parameter(Mandatory)][string]$Sql)
  $args = @(
    "--no-psqlrc", "--host", $env:PGHOST, "--port", $env:PGPORT,
    "--username", $env:PGUSER, "--dbname", $env:PGDATABASE,
    "--set", "ON_ERROR_STOP=1", "--tuples-only", "--no-align", "--quiet",
    "--command", $Sql
  )
  return Invoke-Psql -Arguments $args
}

function Assert-DatabaseIdentity {
  $identity = Invoke-PsqlQuery -Sql @"
SELECT CASE
  WHEN current_database() = 'postgres'
   AND current_user = 'postgres'
   AND current_setting('server_version_num')::integer >= 150000
   AND NOT pg_catalog.pg_is_in_recovery()
  THEN 'OK' ELSE 'MISMATCH' END;
"@
  Assert-True ($identity.Output.Trim() -eq "OK") "PostgreSQL target identity check failed."
}

function Assert-ExecutionAttestations {
  foreach ($path in @($ApprovalFile, $RecoveryAttestationFile, $ExternalHoldAttestationFile)) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($path)) "Execution requires all three external attestation files."
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "An execution attestation file is missing."
  }

  $approval = Get-Content -LiteralPath $ApprovalFile -Raw | ConvertFrom-Json
  Assert-True ($approval.owner_approved -eq $true) "Owner approval is not explicit."
  Assert-True ($approval.project_ref -eq $ProjectRef) "Owner approval targets another project."
  Assert-True ($approval.manifest_sha256 -eq $script:manifestHash) "Owner approval does not bind this manifest."
  Assert-True ($approval.executor_sha256 -eq $script:executorHash) "Owner approval does not bind this executor."
  Assert-True ($approval.git_commit -eq $script:gitCommit) "Owner approval does not bind the current commit."
  Assert-True (@($approval.actions) -contains "apply_sql") "Owner approval does not authorize SQL."
  Assert-True (@($approval.actions) -contains "activate_hold") "Owner approval does not authorize hold activation."
  Assert-True (@($approval.actions) -contains "deploy_edge_functions") "Owner approval does not authorize Edge deployment."
  Assert-True ($approval.local_validation_passed -eq $true) "Local recovery, database and Edge validations are not attested."
  Assert-True (Test-FutureUtc -Value ([string]$approval.expires_at) -MaximumFutureMinutes 1440) "Owner approval is expired or has an invalid expiry."

  $recovery = Get-Content -LiteralPath $RecoveryAttestationFile -Raw | ConvertFrom-Json
  Assert-True ($recovery.project_ref -eq $ProjectRef) "Recovery attestation targets another project."
  Assert-True ($recovery.managed_backup_verified -eq $true) "Managed backup verification is missing."
  Assert-True ($recovery.supabase_compatible_restore_verified -eq $true) "A Supabase-compatible isolated restore is not verified."
  Assert-True ($recovery.storage_bytes_verified -eq $true) "Storage object recovery is not verified."
  Assert-True ($recovery.edge_secrets_recoverable -eq $true) "Edge secret recovery is not verified."
  Assert-True ($recovery.scope_limitations_acknowledged -eq $true) "Recovery limitations are not acknowledged."
  Assert-True (Test-RecentUtc -Value ([string]$recovery.verified_at) -MaximumAgeMinutes 1440) "Recovery attestation is stale or has an invalid timestamp."

  $externalHold = Get-Content -LiteralPath $ExternalHoldAttestationFile -Raw | ConvertFrom-Json
  Assert-True ($externalHold.project_ref -eq $ProjectRef) "External hold attestation targets another project."
  Assert-True ($externalHold.external_hold_active -eq $true) "The external write hold is not confirmed active."
  Assert-True ($externalHold.edge_ingress_blocked -eq $true) "Legacy Edge ingress is not blocked."
  Assert-True ($externalHold.direct_api_mutations_blocked -eq $true) "Direct API mutations are not blocked."
  Assert-True ($externalHold.scheduled_jobs_paused -eq $true) "Managed scheduled jobs are not paused."
  Assert-True ($externalHold.privileged_writers_accounted_for -eq $true) "Privileged writers are not accounted for."
  Assert-True (Test-RecentUtc -Value ([string]$externalHold.verified_at) -MaximumAgeMinutes 15) "External hold attestation is stale or has an invalid timestamp."
}

function Assert-ProductionConnection {
  Assert-True ($env:PGHOST -eq $manifest.database.host) "PGHOST must be the exact Main direct database host."
  Assert-True ($env:PGPORT -eq [string]$manifest.database.port) "PGPORT does not match the Main manifest."
  Assert-True ($env:PGDATABASE -eq $manifest.database.name) "PGDATABASE does not match the Main manifest."
  Assert-True ($env:PGUSER -eq $manifest.database.user) "PGUSER must be the reviewed deployment account."
  Assert-True ($env:PGSSLMODE -eq $manifest.database.sslmode) "PGSSLMODE must be verify-full."
  Assert-True (-not [string]::IsNullOrWhiteSpace($env:PGPASSWORD)) "PGPASSWORD is required in the protected process environment."
  Assert-True (-not [string]::IsNullOrWhiteSpace($env:PGSSLROOTCERT)) "PGSSLROOTCERT is required for TLS certificate validation."
  Assert-True (Test-Path -LiteralPath $env:PGSSLROOTCERT -PathType Leaf) "PGSSLROOTCERT does not resolve to a certificate file."
  Assert-True (-not $env:PGHOSTADDR -and -not $env:PGSERVICE -and -not $env:PGSERVICEFILE) "PGHOSTADDR and libpq service overrides are not allowed."
  Assert-True (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_ANON_KEY)) "SUPABASE_ANON_KEY is required in the protected process environment."
  Assert-True (-not [string]::IsNullOrWhiteSpace($env:SAI_SUPER_ADMIN_ACCESS_TOKEN)) "A usable Super Admin access token is required in the protected process environment."
  Assert-DatabaseIdentity
}

function Get-ProjectRecord {
  $response = Invoke-SupabaseJson -Arguments @("projects", "list", "--output-format", "json")
  $projects = if ($response.projects) { @($response.projects) } else { @($response) }
  $matches = @($projects | Where-Object { $_.id -eq $manifest.project.ref })
  Assert-True ($matches.Count -eq 1) "Supabase CLI cannot resolve the unique Main project."
  Assert-True ($matches[0].name -eq $manifest.project.name) "Resolved project name does not match Main."
}

function Get-FunctionInventory {
  $response = Invoke-SupabaseJson -Arguments @(
    "functions", "list", "--project-ref", $ProjectRef, "--output-format", "json"
  )
  if ($response.functions) { return @($response.functions) }
  return @($response)
}

function Assert-FunctionBaseline {
  param([Parameter(Mandatory)][object[]]$Inventory)
  $expected = @($manifest.edge_function_baseline)
  Assert-True ($Inventory.Count -eq $expected.Count) "Hosted Edge Function count differs from the approved baseline."
  foreach ($expectedFunction in $expected) {
    $matches = @($Inventory | Where-Object { $_.slug -eq $expectedFunction.slug })
    Assert-True ($matches.Count -eq 1) "Hosted Edge Function is missing or duplicated: $($expectedFunction.slug)"
    Assert-True ($matches[0].status -eq $expectedFunction.status) "Hosted Edge Function is not active: $($expectedFunction.slug)"
    Assert-True ([int]$matches[0].version -eq [int]$expectedFunction.version) "Hosted Edge Function version changed since manifest review: $($expectedFunction.slug)"
    Assert-True ([bool]$matches[0].verify_jwt -eq [bool]$expectedFunction.verify_jwt) "Hosted JWT configuration changed since manifest review: $($expectedFunction.slug)"
  }
}

function Assert-Manifest {
  Assert-True ($ProjectRef -eq $manifest.project.ref) "Production execution is restricted to the exact Main project."
  Assert-True ($manifest.project.git_branch -eq "main") "Manifest does not target the main branch."

  $seenPaths = @{}
  foreach ($source in $manifest.required_source_files) {
    Assert-True (-not $seenPaths.ContainsKey($source.path)) "Manifest repeats a source path."
    $seenPaths[$source.path] = $true
    $fullPath = Get-ManifestPath -RelativePath $source.path
    $actualHash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-True ($actualHash -eq $source.sha256.ToLowerInvariant()) "SHA-256 mismatch: $($source.path)"
  }

  foreach ($function in $manifest.edge_function_baseline) {
    Assert-True ($seenPaths.ContainsKey([string]$function.entrypoint)) "Edge entrypoint is not hash-pinned: $($function.slug)"
    foreach ($dependency in @($function.dependencies)) {
      Assert-True ($seenPaths.ContainsKey([string]$dependency)) "Edge dependency is not hash-pinned: $dependency"
    }
  }

  $functionStep = @($manifest.steps | Where-Object { $_.kind -eq "edge-functions" })
  Assert-True ($functionStep.Count -eq 1) "Manifest must contain one ordered Edge Function deployment step."
  $expectedSlugs = @($manifest.edge_function_baseline | ForEach-Object { [string]$_.slug } | Sort-Object)
  $stepSlugs = @($functionStep[0].functions | ForEach-Object { [string]$_ } | Sort-Object)
  Assert-True (($expectedSlugs -join "|") -eq ($stepSlugs -join "|")) "Edge deployment step must match the complete reviewed Main function set."

  $completed = @{}
  foreach ($step in $manifest.steps) {
    foreach ($dependency in @($step.depends_on)) {
      Assert-True ($completed.ContainsKey([string]$dependency)) "Deployment dependency order is invalid at $($step.id)."
    }
    if ($step.kind -eq "sql") {
      Assert-True ($seenPaths.ContainsKey([string]$step.path)) "SQL deployment step is not hash-pinned."
      [void](Get-ManifestPath -RelativePath $step.path)
    }
    elseif ($step.kind -eq "edge-functions") {
      foreach ($slug in @($step.functions)) {
        Assert-True (@($manifest.edge_function_baseline | Where-Object { $_.slug -eq $slug }).Count -eq 1) "Edge deployment step references an unpinned function."
      }
    }
    elseif ($step.kind -notin @("refresh-mutation-guards", "activate-mutation-hold")) {
      throw "Unsupported deployment step kind: $($step.kind)"
    }
    $completed[[string]$step.id] = $true
  }
  Assert-True ($manifest.rollback.path -and $seenPaths.ContainsKey([string]$manifest.rollback.path)) "Rollback SQL is not hash-pinned."
}

function Invoke-SqlStep {
  param([Parameter(Mandatory)][object]$Step)
  $fullPath = Get-ManifestPath -RelativePath $Step.path
  Write-Record -Step $Step.id -Status "STARTED" -Message "Applying the single reviewed SQL proposal."
  $result = Invoke-Psql -Arguments @(
    "--no-psqlrc", "--host", $env:PGHOST, "--port", $env:PGPORT,
    "--username", $env:PGUSER, "--dbname", $env:PGDATABASE,
    "--set", "ON_ERROR_STOP=1", "--quiet", "--file", $fullPath
  )
  Write-Record -Step $Step.id -Status "APPLIED" -Message "SQL process exited successfully."

  $verifySql = switch ($Step.id) {
    "install-mutation-hold" {
      "SELECT CASE WHEN to_regprocedure('public.sai_set_mutation_hold(boolean,text)') IS NOT NULL AND (SELECT enabled = false FROM private.sai_mutation_hold_state WHERE singleton) THEN 'OK' ELSE 'FAIL' END;"
    }
    "phase3b-role-contract" {
      "SELECT CASE WHEN to_regprocedure('public.sai_manage_role_assignment(uuid,uuid,text,public.app_role,uuid[],boolean,boolean,text,text)') IS NOT NULL AND to_regprocedure('private.sai_guard_last_super_admin()') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname IN ('sai_security_branch_member','sai_security_can_read_branch','sai_security_can_read_class','sai_security_can_read_session','sai_security_can_read_student','sai_security_has_role','sai_learning_can_grade_homework','sai_learning_can_manage_course','sai_learning_can_read_course','sai_learning_can_read_homework','sai_learning_own_student','sai_finance_can_read_student','sai_finance_has_role','sai_finance_staff') AND has_function_privilege('authenticated', p.oid, 'EXECUTE')) THEN 'OK' ELSE 'FAIL' END;"
    }
    "phase3b-teacher-assignment" {
      "SELECT CASE WHEN to_regprocedure('public.sai_manage_teacher_assignment(uuid,uuid,text,uuid)') IS NOT NULL THEN 'OK' ELSE 'FAIL' END;"
    }
    "phase3b-verified-onboarding" {
      "SELECT CASE WHEN to_regprocedure('public.admissions_link_student_account(uuid,uuid)') IS NOT NULL AND to_regprocedure('public.admissions_unlink_student_account(uuid)') IS NOT NULL THEN 'OK' ELSE 'FAIL' END;"
    }
    "phase3c-own-contact-validation" {
      "SELECT CASE WHEN to_regprocedure('public.sai_profiles_validate_contact()') IS NOT NULL AND EXISTS (SELECT 1 FROM pg_catalog.pg_trigger WHERE tgname = 'sai_profiles_contact_guard' AND NOT tgisinternal) THEN 'OK' ELSE 'FAIL' END;"
    }
    "phase4a-examinations" {
      "SELECT CASE WHEN to_regclass('public.exams') IS NOT NULL AND to_regclass('public.exam_results') IS NOT NULL AND EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid = 'public.exams'::regclass AND relrowsecurity) AND EXISTS (SELECT 1 FROM pg_catalog.pg_class WHERE oid = 'public.exam_results'::regclass AND relrowsecurity) THEN 'OK' ELSE 'FAIL' END;"
    }
    default { throw "No post-deployment verifier is defined for $($Step.id)." }
  }
  $verification = Invoke-PsqlQuery -Sql $verifySql
  Assert-True ($verification.Output.Trim() -eq "OK") "Post-SQL verification failed for $($Step.id)."
  Write-Record -Step $Step.id -Status "VERIFIED" -Message "Required database objects and policy state were verified."
}

function Invoke-RefreshAndActivateHold {
  $refresh = Invoke-PsqlQuery -Sql "SELECT private.sai_install_mutation_hold_guards();"
  $guardCount = 0
  Assert-True ([int]::TryParse($refresh.Output.Trim(), [ref]$guardCount) -and $guardCount -gt 0) "Hold guards were not refreshed over the deployed schema."
  Write-Record -Step "refresh-mutation-guards" -Status "VERIFIED" -Message "Hold guards were installed on current relations."

  Write-Record -Step "activate-mutation-hold" -Status "STARTED" -Message "Requesting hold activation through the authenticated Super Admin RPC."
  $headers = @{
    apikey = $env:SUPABASE_ANON_KEY
    Authorization = "Bearer $env:SAI_SUPER_ADMIN_ACCESS_TOKEN"
    "Content-Type" = "application/json"
  }
  $body = @{
    p_enabled = $true
    p_reason = "Approved Phase 7-R Main cutover"
  } | ConvertTo-Json -Compress
  try {
    $null = Invoke-RestMethod -Method Post `
      -Uri "https://$ProjectRef.supabase.co/rest/v1/rpc/sai_set_mutation_hold" `
      -Headers $headers -Body $body -TimeoutSec 30
  }
  catch {
    throw "Super Admin mutation-hold activation RPC failed; keep the independent external hold active."
  }

  $state = Invoke-PsqlQuery -Sql "SELECT CASE WHEN enabled THEN 'ON' ELSE 'OFF' END FROM private.sai_mutation_hold_state WHERE singleton;"
  Assert-True ($state.Output.Trim() -eq "ON") "The database mutation hold did not activate."
  $script:holdActivated = $true
  $blocked = Invoke-Psql -ExpectedFailure -Arguments @(
    "--no-psqlrc", "--host", $env:PGHOST, "--port", $env:PGPORT,
    "--username", $env:PGUSER, "--dbname", $env:PGDATABASE,
    "--set", "ON_ERROR_STOP=1", "--tuples-only", "--no-align", "--quiet",
    "--command", "SELECT public.sai_assert_mutations_enabled();"
  )
  Assert-True ($blocked.ExitCode -ne 0 -and $blocked.Output -match "maintenance_mode") "Active hold did not deny the assertion RPC."
  Write-Record -Step "activate-mutation-hold" -Status "VERIFIED" -Message "Hold is active and the assertion RPC denies writes."
}

function Deploy-EdgeFunctions {
  param([Parameter(Mandatory)][object]$Step)
  foreach ($slug in @($Step.functions)) {
    $function = @($manifest.edge_function_baseline | Where-Object { $_.slug -eq $slug })[0]
    Write-Record -Step "edge:$slug" -Status "STARTED" -Message "Deploying reviewed function source under the active database hold."
    $arguments = @("functions", "deploy", $slug, "--project-ref", $ProjectRef)
    if (-not [bool]$function.verify_jwt) { $arguments += "--no-verify-jwt" }
    $deploy = Invoke-External -Executable $script:supabasePath -Arguments $arguments
    if ($deploy.ExitCode -ne 0) {
      throw "Edge deployment failed for $slug (exit $($deploy.ExitCode)); containment hold remains active."
    }

    $inventory = Get-FunctionInventory
    $deployed = @($inventory | Where-Object { $_.slug -eq $slug })
    Assert-True ($deployed.Count -eq 1) "Deployed Edge Function is missing from Main: $slug"
    Assert-True ($deployed[0].status -eq "ACTIVE") "Deployed Edge Function is not active: $slug"
    Assert-True ([bool]$deployed[0].verify_jwt -eq [bool]$function.verify_jwt) "Edge JWT configuration changed during deployment: $slug"
    Assert-True ([int]$deployed[0].version -eq ([int]$function.version + 1)) "Unexpected Edge version transition for $slug."
    Write-Record -Step "edge:$slug" -Status "VERIFIED" -Message "New version $($deployed[0].version) is active with the approved JWT mode."
  }
}

try {
  Assert-True ($ProjectRef -eq "aeryusbrulqdxjdynwfh") "This executor is locked to the existing Main project."
  Assert-True (Test-Path -LiteralPath $ManifestPath -PathType Leaf) "Deployment manifest is missing."
  $manifestHash = (Get-FileHash -LiteralPath $ManifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
  Assert-Manifest

  $gitRoot = (Invoke-External -Executable "git" -Arguments @("rev-parse", "--show-toplevel")).Output.Trim()
  Assert-True ([IO.Path]::GetFullPath($gitRoot) -eq $repoRoot) "Git root does not match the expected repository."
  $branch = (Invoke-External -Executable "git" -Arguments @("branch", "--show-current")).Output.Trim()
  Assert-True ($branch -eq "main") "Executor may only run from the main branch."
  $gitCommit = (Invoke-External -Executable "git" -Arguments @("rev-parse", "HEAD")).Output.Trim()
  $origin = (Invoke-External -Executable "git" -Arguments @("remote", "get-url", "origin")).Output.Trim()
  Assert-True ($origin -eq $expectedOrigin) "Git origin does not match BARH000M/sai-college-production."

  $gitStatus = Invoke-External -Executable "git" -Arguments @("status", "--porcelain", "--untracked-files=all")
  if ($Execute) {
    Assert-True ($gitStatus.Output.Trim().Length -eq 0) "Production execution requires a clean reviewed worktree."
  }

  $supabaseCommand = Get-Command "supabase" -ErrorAction Stop
  $supabasePath = if ($supabaseCommand.Source) { $supabaseCommand.Source } else { $supabaseCommand.Path }
  $versionOutput = Invoke-External -Executable $supabasePath -Arguments @("--version")
  Assert-True ($versionOutput.ExitCode -eq 0) "Supabase CLI version check failed."
  $versionMatch = [regex]::Match($versionOutput.Output, "(\d+\.\d+\.\d+)")
  Assert-True ($versionMatch.Success -and ([version]$versionMatch.Groups[1].Value -ge [version]"2.111.0") -and ([version]$versionMatch.Groups[1].Value -lt [version]"3.0.0")) "Supabase CLI v2.111.0 or later within major version 2 is required."

  if ([string]::IsNullOrWhiteSpace($PsqlPath)) {
    $psqlCommand = Get-Command "psql" -ErrorAction SilentlyContinue
    if ($psqlCommand) {
      $PsqlPath = if ($psqlCommand.Source) { $psqlCommand.Source } else { $psqlCommand.Path }
    }
    else {
      $candidatePaths = @(
        (Join-Path $env:ProgramFiles "PostgreSQL\17\bin\psql.exe"),
        "C:\Program Files\PostgreSQL\17\bin\psql.exe"
      )
      $PsqlPath = $candidatePaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
  }
  Assert-True (-not [string]::IsNullOrWhiteSpace($PsqlPath) -and (Test-Path -LiteralPath $PsqlPath -PathType Leaf)) "PostgreSQL psql 17 is required."
  $psqlPath = [IO.Path]::GetFullPath($PsqlPath)
  Get-ProjectRecord
  $functionInventory = Get-FunctionInventory
  Assert-FunctionBaseline -Inventory $functionInventory

  $executorHash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($Execute) {
    Assert-ExecutionAttestations
    Assert-ProductionConnection
    Write-Record -Step "preflight" -Status "VERIFIED" -Message "Project identity, hashes, dependency graph, recovery, external hold and approval verified."
  }
  else {
    Write-Record -Step "preflight" -Status "DRY_RUN_PASS" -Message "Project identity, hashes, dependency graph and hosted Edge baseline verified; no writes performed."
  }

  if (-not $Execute) {
    Write-Output "DRY RUN PASS - no production database or Edge Function writes were performed."
    Write-Output "Record: $logFile"
    exit 0
  }

  $sqlSteps = @($manifest.steps | Where-Object { $_.kind -eq "sql" })
  foreach ($step in $sqlSteps) {
    Invoke-SqlStep -Step $step
  }

  $refreshStep = @($manifest.steps | Where-Object { $_.kind -eq "refresh-mutation-guards" })[0]
  $activateStep = @($manifest.steps | Where-Object { $_.kind -eq "activate-mutation-hold" })[0]
  $edgeStep = @($manifest.steps | Where-Object { $_.kind -eq "edge-functions" })[0]
  Assert-True ($refreshStep -and $activateStep -and $edgeStep) "Manifest is missing a required safety step."
  Invoke-RefreshAndActivateHold
  Deploy-EdgeFunctions -Step $edgeStep

  Write-Record -Step "completion" -Status "CUTOVER_READY_HOLD_ACTIVE" -Message "All approved SQL and Edge steps verified. Hold intentionally remains active pending acceptance and separately approved release."
  Write-Output "CUTOVER STEPS PASS - database maintenance hold remains active; no automatic release was attempted."
  Write-Output "Record: $logFile"
  exit 0
}
catch {
  $message = $_.Exception.Message
  if ($logFile) {
    $containment = if ($script:holdActivated) {
      "Database and external holds must remain active; no automatic rollback or release was attempted."
    }
    else {
      "Keep the independent external hold active; confirm whether the database hold was installed or activated."
    }
    Write-Record -Step "failure" -Status "STOPPED_NO_GO" -Message "$message $containment"
  }
  Write-Error "NO-GO: $message"
  if ($script:holdActivated) {
    Write-Error "Containment: database and external holds must remain active. No automatic rollback or release was attempted."
  }
  exit 1
}
