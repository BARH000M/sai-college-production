$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test --dart-define-from-file=config/preview.json
if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
flutter build apk --debug --dart-define-from-file=config/preview.json
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
