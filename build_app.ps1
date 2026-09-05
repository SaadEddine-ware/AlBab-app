$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSCommandPath

$Desktop = [Environment]::GetFolderPath("Desktop")
$PyBuildDir = Join-Path -Path $ProjectRoot -ChildPath "dist"

Write-Host "=== Building AlBab Student Hub (onefile) ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectRoot"

# Clean previous
if (Test-Path (Join-Path $ProjectRoot "dist"))  { Remove-Item -Path (Join-Path $ProjectRoot "dist") -Recurse -Force }
if (Test-Path (Join-Path $ProjectRoot "build")) { Remove-Item -Path (Join-Path $ProjectRoot "build") -Recurse -Force }

Write-Host "Running PyInstaller (this will take a while)..." -ForegroundColor Cyan

$pyinstallerArgs = @(
    "--onefile"
    "--name", "AlBab"
    "--noconfirm"
    "--clean"
    "--windowed"
    "--add-data", "ui;ui/"
    "--add-data", "bin;bin/"
    "--add-data", "assets;assets/"
    "--add-binary", "C:\Windows\System32\msvcp140.dll;."
    "--add-binary", "C:\Windows\System32\msvcp140_1.dll;."
    "--add-binary", "C:\Windows\System32\msvcp140_2.dll;."
    "--add-binary", "C:\Windows\System32\msvcp140_atomic_wait.dll;."
    "--add-binary", "C:\Windows\System32\msvcp140_codecvt_ids.dll;."
    "--icon", "assets\app_icon.ico"
    "--hidden-import", "PySide6.QtCore"
    "--hidden-import", "PySide6.QtGui"
    "--hidden-import", "PySide6.QtWidgets"
    "--hidden-import", "PySide6.QtQml"
    "--hidden-import", "PySide6.QtNetwork"
    "--hidden-import", "PySide6.QtSvg"
    "--hidden-import", "PySide6.QtSvgWidgets"
    "--hidden-import", "numpy"
    "--hidden-import", "numpy.core._multiarray_umath"
    "--hidden-import", "numpy.core._methods"
    "--hidden-import", "matplotlib"
    "--hidden-import", "matplotlib.backends.backend_agg"
    "--hidden-import", "matplotlib.backends.backend_template"
    "--hidden-import", "matplotlib.pyplot"
    "--hidden-import", "matplotlib.figure"
    "--hidden-import", "trimesh"
    "--hidden-import", "google.genai"
    "--hidden-import", "google.api_core.exceptions"
    "--collect-submodules", "PySide6.QtQml"
    "--collect-data", "PySide6.QtQml"
    "--exclude-module", "tkinter"
    "--exclude-module", "test"

    "--exclude-module", "setuptools"
    "--exclude-module", "pip"
    "main.py"
)

& pyinstaller $pyinstallerArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "PyInstaller failed!" -ForegroundColor Red
    exit 1
}

# Deploy single EXE to desktop
$exePath = Join-Path -Path $PyBuildDir -ChildPath "AlBab.exe"
if (Test-Path $exePath) {
    Copy-Item -Path $exePath -Destination "$Desktop\AlBab.exe" -Force
    Write-Host "Deployed to desktop: $Desktop\AlBab.exe" -ForegroundColor Green
} else {
    Write-Host "Build output not found at $exePath" -ForegroundColor Red
    exit 1
}

# Create shortcut on desktop
$wshell = New-Object -ComObject WScript.Shell
$shortcut = $wshell.CreateShortcut("$Desktop\AlBab.lnk")
$shortcut.TargetPath = "$Desktop\AlBab.exe"
$shortcut.WorkingDirectory = "$Desktop"
$shortcut.Description = "AlBab Student Hub"
$shortcut.Save()

Write-Host ""
Write-Host "=== Build Complete! ===" -ForegroundColor Green
Write-Host "Single EXE: $Desktop\AlBab.exe"
$size = (Get-Item "$Desktop\AlBab.exe").Length
Write-Host "Size: $([math]::Round($size / 1MB, 1)) MB"
Write-Host "Shortcut: $Desktop\AlBab.lnk"
Write-Host ""
Write-Host "Copy ONLY the AlBab.exe file to USB - one file, no dependencies!" -ForegroundColor Cyan
