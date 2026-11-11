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
if ($key -isnot [string] -or -not $key -or $key -eq 'PASTE_PUBLIC_KEY_HERE') { throw 'Enter a public anon or sb_publishable key.' }
if ($key.StartsWith('sb_secret_')) { throw 'Never put an sb_secret key in a mobile build.' }
if ($key.StartsWith('eyJ')) {
    $parts = $key.Split('.')
    if ($parts.Length -ne 3) { throw 'The anon key is malformed.' }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    switch ($payload.Length % 4) {
        1 { throw 'The anon key is malformed.' }
        2 { $payload += '==' }
        3 { $payload += '=' }
    }
    try {
        $claimsJson = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
        $claims = $claimsJson | ConvertFrom-Json -ErrorAction Stop
    } catch { throw 'The anon key could not be decoded. Check config/live.json.' }
    if ($claims.role -eq 'service_role') { throw 'Never put a service_role key in a mobile build.' }
    if ($claims.ref -ne 'aeryusbrulqdxjdynwfh') { throw 'The anon key belongs to a different Supabase project.' }
    if ($claims.role -ne 'anon') { throw 'Use only the anon or sb_publishable key.' }
} elseif (-not $key.StartsWith('sb_publishable_')) {
    throw 'The key must be the public anon JWT or an sb_publishable key.'
}
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
flutter test --dart-define-from-file=config/preview.json
if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
flutter build apk --debug --dart-define-from-file=config/live.json
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
