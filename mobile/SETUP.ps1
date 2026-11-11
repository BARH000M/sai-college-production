$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Install Flutter and add flutter/bin to PATH first.' }
# Generate platform wrappers only if absent. Keep this package's Dart entry point.
if (-not (Test-Path 'android')) {
    $scaffold = Join-Path $env:TEMP ('sai-platforms-' + [Guid]::NewGuid().ToString('N'))
    flutter create --no-pub --platforms=android,ios,web --org online.yemensai --project-name sai_approved_mobile $scaffold
    if ($LASTEXITCODE -ne 0) { throw 'Platform generation failed.' }
    foreach ($folder in @('android','ios','web')) {
        if (-not (Test-Path $folder)) { Copy-Item (Join-Path $scaffold $folder) $PSScriptRoot -Recurse }
    }
    if (-not (Test-Path '.metadata')) { Copy-Item (Join-Path $scaffold '.metadata') $PSScriptRoot }
    Remove-Item -LiteralPath $scaffold -Recurse -Force
}
$manifest = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
$text = Get-Content -LiteralPath $manifest -Raw
if ($text -notmatch 'android.permission.INTERNET') {
    $text = $text.Replace('<application', '<uses-permission android:name="android.permission.INTERNET" />' + [Environment]::NewLine + '    <application')
    [IO.File]::WriteAllText($manifest, $text, [Text.UTF8Encoding]::new($false))
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency download failed.' }
Write-Host 'Setup complete. Run .\BUILD_PREVIEW.ps1' -ForegroundColor Green
