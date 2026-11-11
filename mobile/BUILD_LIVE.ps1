$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'config/live.json')) { throw 'Copy config/live.example.json to config/live.json and paste your public key.' }
$config = Get-Content 'config/live.json' -Raw | ConvertFrom-Json
if ($config.SAI_PREVIEW -ne 'false') { throw 'Live builds require SAI_PREVIEW=false.' }
if (-not $config.SUPABASE_PUBLIC_KEY -or $config.SUPABASE_PUBLIC_KEY -eq 'PASTE_PUBLIC_KEY_HERE' -or $config.SUPABASE_PUBLIC_KEY.StartsWith('sb_secret_')) { throw 'Enter a valid public/publishable key.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter build apk --debug --dart-define-from-file=config/live.json
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
