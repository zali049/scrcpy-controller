# =============================================================================
# ScrcpyController Windows Installer Builder
# Run on a Windows machine with Flutter and NSIS installed
# Usage: powershell -ExecutionPolicy Bypass -File build_windows_installer.ps1 [-Version 1.0.0]
# =============================================================================
param (
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$AppName    = "ScrcpyController"
$AppExe     = "scrcpy_gui_controller.exe"
$ProjectDir = Split-Path -Parent $PSScriptRoot
$BuildDir   = "$ProjectDir\build\windows\x64\runner\Release"
$BinSrc     = "$ProjectDir\assets\bin\windows"
$DistDir    = "$ProjectDir\dist"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  ScrcpyController Windows Builder v$Version"     -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Step 1: Flutter build
Write-Host "`n▶ [1/3] Building Flutter Windows release..." -ForegroundColor Yellow
Set-Location $ProjectDir
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "Flutter build failed" }

# Step 2: Copy scrcpy binaries
Write-Host "`n▶ [2/3] Copying scrcpy binaries..." -ForegroundColor Yellow
Copy-Item "$BinSrc\*" "$BuildDir\" -Force -Recurse
Write-Host "  Binaries in $BuildDir:"
Get-ChildItem $BuildDir -Filter "*.exe","*.dll","scrcpy-server" | Select-Object Name, @{N='Size(KB)';E={[math]::Round($_.Length/1KB,1)}}

# Step 3: Build NSIS installer
Write-Host "`n▶ [3/3] Building NSIS installer..." -ForegroundColor Yellow

$nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
if (-not (Test-Path $nsisPath)) {
    Write-Host "NSIS not found. Install it: https://nsis.sourceforge.io/Download" -ForegroundColor Red
    Write-Host "Or via chocolatey: choco install nsis" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$OutPkg = "$DistDir\${AppName}-${Version}-Setup.exe"

$nsisScript = @"
!define APP_NAME    "$AppName"
!define APP_VERSION "$Version"
!define APP_EXE     "$AppExe"
!define PUBLISHER   "ScrcpyController"
!define INSTALL_DIR "`$PROGRAMFILES64\$AppName"

Name "`${APP_NAME} `${APP_VERSION}"
OutFile "$OutPkg"
InstallDir "`${INSTALL_DIR}"
InstallDirRegKey HKLM "Software\`${APP_NAME}" "Install_Dir"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetOutPath "`${INSTALL_DIR}"
  File /r "$BuildDir\*.*"

  CreateShortcut "`$DESKTOP\`${APP_NAME}.lnk" "`${INSTALL_DIR}\`${APP_EXE}"
  CreateDirectory "`$SMPROGRAMS\`${APP_NAME}"
  CreateShortcut "`$SMPROGRAMS\`${APP_NAME}\`${APP_NAME}.lnk" "`${INSTALL_DIR}\`${APP_EXE}"
  CreateShortcut "`$SMPROGRAMS\`${APP_NAME}\Uninstall.lnk"    "`${INSTALL_DIR}\Uninstall.exe"

  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}" "DisplayName"    "`${APP_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}" "UninstallString" "`${INSTALL_DIR}\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}" "DisplayVersion"  "`${APP_VERSION}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}" "Publisher"       "`${PUBLISHER}"

  WriteUninstaller "`${INSTALL_DIR}\Uninstall.exe"
SectionEnd

Section "Uninstall"
  RMDir /r "`${INSTALL_DIR}"
  Delete "`$DESKTOP\`${APP_NAME}.lnk"
  RMDir /r "`$SMPROGRAMS\`${APP_NAME}"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\`${APP_NAME}"
SectionEnd
"@

$nsisScript | Out-File -FilePath "$env:TEMP\scrcpy_installer.nsi" -Encoding UTF8
& $nsisPath "$env:TEMP\scrcpy_installer.nsi"
if ($LASTEXITCODE -ne 0) { throw "NSIS build failed" }

$size = [math]::Round((Get-Item $OutPkg).Length / 1MB, 1)
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  Installer ready: ${size}MB"                      -ForegroundColor Green
Write-Host "  $OutPkg"                                          -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
