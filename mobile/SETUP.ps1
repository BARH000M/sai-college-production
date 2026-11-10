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
$android = 'http://schemas.android.com/apk/res/android'
$native = Join-Path $PSScriptRoot 'android\app\src\main'
$manifestPath = Join-Path $native 'AndroidManifest.xml'
[xml]$manifest = Get-Content -LiteralPath $manifestPath -Raw
$namespaces = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
$namespaces.AddNamespace('android', $android)
$app = $manifest.SelectSingleNode('/manifest/application')
if (-not $app) { throw 'AndroidManifest.xml must contain a manifest/application element.' }
if (-not $manifest.SelectSingleNode("/manifest/uses-permission[@android:name='android.permission.INTERNET']", $namespaces)) {
    $permission = $manifest.CreateElement('uses-permission')
    [void]$permission.SetAttribute('name', $android, 'android.permission.INTERNET')
    [void]$app.ParentNode.InsertBefore($permission, $app)
}
if (-not $manifest.SelectSingleNode("/manifest/queries/intent/action[@android:name='android.intent.action.TTS_SERVICE']", $namespaces)) {
    $queries = $manifest.SelectSingleNode('/manifest/queries')
    if (-not $queries) {
        $queries = $manifest.CreateElement('queries')
        [void]$app.ParentNode.InsertBefore($queries, $app)
    }
    $intent = $manifest.CreateElement('intent')
    $action = $manifest.CreateElement('action')
    [void]$action.SetAttribute('name', $android, 'android.intent.action.TTS_SERVICE')
    [void]$intent.AppendChild($action)
    [void]$queries.AppendChild($intent)
}

function Add-SessionBackupExclusion([string]$Attribute, [string]$Resource, [string]$Root, [string[]]$Sections) {
    $reference = $app.GetAttribute($Attribute, $android)
    if ($Attribute -eq 'fullBackupContent' -and $reference -eq 'false') { return }
    if ($reference) {
        if ($reference -notmatch '^@xml/([a-z0-9_]+)$') { throw "Unsupported Android backup rule reference: $reference" }
        $Resource = $Matches[1]
    }
    $resourceFolder = Join-Path $native 'res\xml'
    New-Item -Path $resourceFolder -ItemType Directory -Force | Out-Null
    $path = Join-Path $resourceFolder "$Resource.xml"
    if (Test-Path -LiteralPath $path) {
        [xml]$rules = Get-Content -LiteralPath $path -Raw
        if ($rules.DocumentElement.Name -ne $Root) { throw "Unexpected backup rule format: $path" }
    } else {
        [xml]$rules = "<$Root />"
    }
    $parents = [System.Collections.Generic.List[System.Xml.XmlNode]]::new()
    if ($Sections.Count -eq 0) { $parents.Add($rules.DocumentElement) }
    else {
        foreach ($section in $Sections) {
            $node = $rules.DocumentElement.SelectSingleNode($section)
            if (-not $node) {
                $node = $rules.CreateElement($section)
                [void]$rules.DocumentElement.AppendChild($node)
            }
            $parents.Add($node)
        }
    }
    foreach ($parent in $parents) {
        if (-not $parent.SelectSingleNode("exclude[@domain='sharedpref' and @path='FlutterSharedPreferences.xml']")) {
            $exclude = $rules.CreateElement('exclude')
            $exclude.SetAttribute('domain', 'sharedpref')
            $exclude.SetAttribute('path', 'FlutterSharedPreferences.xml')
            [void]$parent.AppendChild($exclude)
        }
    }
    $rules.Save($path)
    [void]$app.SetAttribute($Attribute, $android, "@xml/$Resource")
}

# Preserve the session across normal restarts, but exclude it from reinstall restores.
Add-SessionBackupExclusion 'fullBackupContent' 'sai_session_backup' 'full-backup-content' @()
Add-SessionBackupExclusion 'dataExtractionRules' 'sai_session_transfer' 'data-extraction-rules' @('cloud-backup', 'device-transfer')
# Branded, ASCII-only launcher label prevents the mojibake seen on Android.
$app.SetAttribute('label', $android, 'Yemen SAI')
$app.SetAttribute('icon', $android, '@mipmap/ic_launcher')
$app.SetAttribute('roundIcon', $android, '@mipmap/ic_launcher_round')
$manifest.Save($manifestPath)

# Always refresh native launcher resources even if android/ already existed.
$branding = Join-Path $PSScriptRoot 'branding\android'
if (-not (Test-Path $branding)) { throw 'Missing mobile/branding/android assets.' }
$res = Join-Path $native 'res'
Get-ChildItem -LiteralPath $branding -Recurse -File | ForEach-Object {
    $relative = $_.FullName.Substring($branding.Length + 1)
    $dest = Join-Path $res $relative
    New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
}
$utf8 = [Text.UTF8Encoding]::new($false)
$adaptive = '<?xml version="1.0" encoding="utf-8"?><adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@color/sai_icon_red"/><foreground android:drawable="@drawable/sai_icon_foreground"/></adaptive-icon>'
$adaptiveDir = Join-Path $res 'mipmap-anydpi-v26'
New-Item -ItemType Directory -Path $adaptiveDir -Force | Out-Null
foreach ($name in @('ic_launcher.xml', 'ic_launcher_round.xml')) {
    [IO.File]::WriteAllText((Join-Path $adaptiveDir $name), $adaptive, $utf8)
}
$values = Join-Path $res 'values'
New-Item -ItemType Directory -Path $values -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $values 'sai_icon_colors.xml'), '<?xml version="1.0" encoding="utf-8"?><resources><color name="sai_icon_red">#B6000B</color></resources>', $utf8)

# iOS: same display name and opaque icon from the identical SAI artwork.
$iosInfo = Join-Path $PSScriptRoot 'ios\Runner\Info.plist'
if (Test-Path -LiteralPath $iosInfo) {
    $plist = [IO.File]::ReadAllText($iosInfo)
    $pattern = '(<key>CFBundleDisplayName</key>\s*<string>).*?(</string>)'
    if ($plist -match $pattern) {
        $plist = [regex]::Replace($plist, $pattern, '${1}Yemen SAI${2}')
    } else {
        $plist = $plist.Replace('<dict>', "<dict>`n    <key>CFBundleDisplayName</key>`n    <string>Yemen SAI</string>")
    }
    [IO.File]::WriteAllText($iosInfo, $plist, $utf8)
    $iconSrc = Join-Path $PSScriptRoot 'branding\ios\AppIcon.appiconset'
    $iconDst = Join-Path $PSScriptRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
    if (Test-Path $iconSrc) {
        New-Item -ItemType Directory -Path $iconDst -Force | Out-Null
        Copy-Item -Path (Join-Path $iconSrc '*') -Destination $iconDst -Force
    }
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency download failed.' }
Write-Host 'Setup complete. Run .\BUILD_PREVIEW.ps1' -ForegroundColor Green
