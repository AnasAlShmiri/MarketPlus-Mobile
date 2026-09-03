$ErrorActionPreference = 'Stop'

Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "[1/6] Stopping Gradle daemons..." -ForegroundColor Cyan
if (Test-Path ".\android\gradlew.bat") {
    Push-Location .\android
    try {
        .\gradlew.bat --stop | Out-Host
    }
    finally {
        Pop-Location
    }
}

Write-Host "[2/6] Stopping stale Flutter/Dart build processes for this user session..." -ForegroundColor Cyan
Get-CimInstance Win32_Process |
    Where-Object {
        ($_.Name -in @('java.exe','dart.exe','dartaotruntime.exe')) -and
        ($_.CommandLine -match 'GradleDaemon|flutter_tools|frontend_server')
    } |
    ForEach-Object {
        try {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop
            Write-Host "Stopped $($_.Name) PID $($_.ProcessId)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "Could not stop PID $($_.ProcessId): $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    }

Write-Host "[3/6] Cleaning Flutter outputs..." -ForegroundColor Cyan
flutter clean

Write-Host "[4/6] Removing project-local Gradle/build remnants..." -ForegroundColor Cyan
$paths = @(
    '.\build',
    '.\android\.gradle',
    '.\.dart_tool\flutter_build'
)
foreach ($path in $paths) {
    if (Test-Path $path) {
        Remove-Item $path -Recurse -Force -ErrorAction Stop
    }
}

Write-Host "[5/6] Restoring packages..." -ForegroundColor Cyan
flutter pub get

Write-Host "[6/6] Verifying source before rebuild..." -ForegroundColor Cyan
flutter analyze

Write-Host "" 
Write-Host "Android build workspace recovered." -ForegroundColor Green
Write-Host "Now run:" -ForegroundColor Yellow
Write-Host "  flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5000"
Write-Host "If the same file-lock error returns, close VS Code/Android Studio and temporarily pause real-time antivirus scanning for the project build folder, then run this script again." -ForegroundColor DarkGray
