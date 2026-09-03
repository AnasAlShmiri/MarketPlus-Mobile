$ErrorActionPreference = 'Stop'

Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "[1/6] Creating Flutter platform files..." -ForegroundColor Cyan
flutter create . --project-name marketplus_mobile --org com.marketplus --platforms=android,ios

Write-Host "[2/6] Removing Flutter's generated sample widget test..." -ForegroundColor Cyan
$generatedWidgetTest = "test/widget_test.dart"
if (Test-Path $generatedWidgetTest) {
    Remove-Item $generatedWidgetTest -Force
}

Write-Host "[3/6] Configuring Android debug camera + local HTTP..." -ForegroundColor Cyan
$debugManifest = "android/app/src/debug/AndroidManifest.xml"
$debugManifestContent = @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <application android:usesCleartextTraffic="true" />
</manifest>
'@
New-Item -ItemType Directory -Force -Path (Split-Path $debugManifest -Parent) | Out-Null
Set-Content -Path $debugManifest -Value $debugManifestContent -Encoding UTF8

Write-Host "[4/6] Configuring iOS camera permission..." -ForegroundColor Cyan
$iosPlist = "ios/Runner/Info.plist"
if (Test-Path $iosPlist) {
    $plist = Get-Content $iosPlist -Raw
    if ($plist -notmatch 'NSCameraUsageDescription') {
        $cameraEntry = @'
    <key>NSCameraUsageDescription</key>
    <string>يستخدم ماركت بلس الكاميرا لمسح باركود المنتجات أثناء البيع.</string>
'@
        $plist = $plist -replace '</dict>', "$cameraEntry`n</dict>"
        Set-Content -Path $iosPlist -Value $plist -Encoding UTF8
    }
}

Write-Host "[5/6] Restoring Flutter packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "[6/6] Running static analysis..." -ForegroundColor Cyan
flutter analyze

Write-Host ""
Write-Host "MarketPlus.Mobile bootstrap completed." -ForegroundColor Green
Write-Host "Android Emulator:" -ForegroundColor Yellow
Write-Host "  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000"
Write-Host "Physical phone (replace with your PC LAN IP):" -ForegroundColor Yellow
Write-Host "  flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000"
Write-Host "Production must use HTTPS; cleartext HTTP is enabled only in the Android debug manifest." -ForegroundColor DarkGray
