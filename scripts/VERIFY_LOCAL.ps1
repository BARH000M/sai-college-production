# Read-only where possible; builds run locally. Never print secrets.
param([string]$Repo = 'D:\SAI-College-Production')
$ErrorActionPreference='Stop'
Set-Location $Repo
Write-Host 'SAI V2 LOCAL VERIFICATION (no deployment)'
$root = (git rev-parse --show-toplevel).Trim()
if ((Resolve-Path $root).Path -ne (Resolve-Path $Repo).Path) { throw 'Wrong repository directory' }
git status --short
if (-not (Test-Path 'node_modules/.bin/tsc.cmd')) { npm ci --no-audit --no-fund; if($LASTEXITCODE -ne 0) { throw 'npm ci failed' } }
npm run type-check; if($LASTEXITCODE -ne 0) { throw 'Main web type-check failed' }
npm run build; if($LASTEXITCODE -ne 0) { throw 'Main web build failed' }
Set-Location (Join-Path $Repo 'web')
npm ci --no-audit --no-fund; if($LASTEXITCODE -ne 0) { throw 'web npm ci failed' }
npm test; if($LASTEXITCODE -ne 0) { throw 'web test failed' }
Write-Warning 'web/ standalone build unavailable; contract tests only.'
Set-Location (Join-Path $Repo 'mobile')
flutter pub get; if($LASTEXITCODE -ne 0) { throw 'flutter pub get failed: check image/archive override' }
flutter analyze; if($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
flutter test --dart-define-from-file=config/preview.json; if($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
Write-Host 'MAIN WEB BUILD, WEB CONTRACT TESTS AND FLUTTER CHECKS PASSED. Secondary web build NOT VERIFIED. No APK, GitHub push or production deployment was performed.'
