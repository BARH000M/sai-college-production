$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'config/live.json')) { throw 'Copy config/live.example.json to config/live.json and paste your public key.' }
try {
    $config = Get-Content 'config/live.json' -Raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    throw 'config/live.json is invalid. Recreate it from config/live.example.json and place only the public key in SUPABASE_PUBLIC_KEY.'
}
if ($config -isnot [PSCustomObject]) { throw 'config/live.json must contain a JSON object.' }
if ($config.SAI_PREVIEW -ne 'false') { throw 'Live builds require SAI_PREVIEW=false.' }
$key = $config.SUPABASE_PUBLIC_KEY
if ($key -isnot [string] -or -not $key -or $key -eq 'PASTE_PUBLIC_KEY_HERE' -or $key.StartsWith('sb_secret_')) { throw 'Enter a valid public/publishable key.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test --dart-define-from-file=config/preview.json
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build apk --debug --dart-define-from-file=config/live.json
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
