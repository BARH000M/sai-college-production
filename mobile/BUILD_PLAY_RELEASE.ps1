$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Test-Path 'config/live.json')) { throw 'Create config/live.json from config/live.example.json and use the public key only.' }
if (-not (Test-Path 'android/key.properties')) { throw 'Android release signing is not configured. See STORE_READINESS_AR.md.' }
$gradlePath = @('android/app/build.gradle.kts','android/app/build.gradle') | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $gradlePath) { throw 'Android app Gradle file was not found.' }
$gradle = Get-Content -LiteralPath $gradlePath -Raw
if ($gradle -notmatch 'signingConfig\s*=\s*signingConfigs\.getByName\("release"\)|signingConfig\s+signingConfigs\.release') {
    throw 'The release build is not connected to a signing configuration. Follow STORE_READINESS_AR.md first.'
}
if ($gradle -notmatch 'targetSdk\s*=\s*36|targetSdkVersion\s+36') { throw 'Google Play target API 36 is missing. Run SETUP.ps1 again.' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test --dart-define-from-file=config/preview.json
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build appbundle --release --dart-define-from-file=config/live.json
if ($LASTEXITCODE -ne 0) { throw 'Android App Bundle build failed.' }
Write-Host "Release AAB: $PSScriptRoot\build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Green
