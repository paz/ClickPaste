<#
.SYNOPSIS
    ClickPaste Uninstaller
.DESCRIPTION
    Removes ClickPaste installation, shortcuts, and startup entries.
.PARAMETER Silent
    Run without prompts.
.PARAMETER KeepSettings
    Preserve user settings in registry.
#>
param(
    [switch]$Silent,
    [switch]$KeepSettings
)

$ErrorActionPreference = "Stop"
$AppName = "ClickPaste"
$ExeName = "ClickPaste.exe"

# Try to find install info
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installInfoPath = Join-Path $ScriptDir "install.json"

if (Test-Path $installInfoPath) {
    $installInfo = Get-Content $installInfoPath | ConvertFrom-Json
    $InstallDir = $installInfo.InstallDir
    $SystemInstall = $installInfo.SystemInstall
} else {
    # Detect install type from current location
    $InstallDir = $ScriptDir
    $SystemInstall = $InstallDir.StartsWith($env:ProgramFiles)
}

# Set paths based on install type
if ($SystemInstall) {
    $StartMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
    $StartupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
} else {
    $StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    $StartupKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
}

# Check for admin rights if system install
if ($SystemInstall) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "Uninstalling system installation requires administrator privileges." -ForegroundColor Red
        Write-Host "Please run this script as Administrator." -ForegroundColor Yellow
        exit 1
    }
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       $AppName Uninstaller" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will remove $AppName from: $InstallDir" -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "Continue with uninstall? [y/N]"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Uninstall cancelled." -ForegroundColor Gray
        exit 0
    }

    if (-not $KeepSettings) {
        $response = Read-Host "Remove user settings? [Y/n]"
        if ($response -eq 'n' -or $response -eq 'N') {
            $KeepSettings = $true
        }
    }
}

Write-Host ""
Write-Host "Uninstalling $AppName..." -ForegroundColor Yellow

# Stop running instance
$process = Get-Process -Name "ClickPaste" -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "  Stopping running instance..."
    $process | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# Remove startup entry
$startupValue = Get-ItemProperty -Path $StartupKey -Name $AppName -ErrorAction SilentlyContinue
if ($startupValue) {
    Remove-ItemProperty -Path $StartupKey -Name $AppName -Force
    Write-Host "  Removed from Windows startup"
}

# Also check the other startup key (in case install type changed)
$otherKey = if ($SystemInstall) { "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" } else { "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" }
$otherValue = Get-ItemProperty -Path $otherKey -Name $AppName -ErrorAction SilentlyContinue
if ($otherValue) {
    try {
        Remove-ItemProperty -Path $otherKey -Name $AppName -Force -ErrorAction SilentlyContinue
    } catch { }
}

# Remove Start Menu shortcut
$shortcutPath = Join-Path $StartMenuDir "$AppName.lnk"
if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Host "  Removed Start Menu shortcut"
}

# Also check the other Start Menu location
$otherStartMenu = if ($SystemInstall) { Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs" } else { Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs" }
$otherShortcut = Join-Path $otherStartMenu "$AppName.lnk"
if (Test-Path $otherShortcut) {
    try {
        Remove-Item $otherShortcut -Force -ErrorAction SilentlyContinue
    } catch { }
}

# Remove user settings
if (-not $KeepSettings) {
    $settingsKey = "HKCU:\SOFTWARE\ClickPaste"
    if (Test-Path $settingsKey) {
        Remove-Item $settingsKey -Recurse -Force
        Write-Host "  Removed user settings"
    }
}

# Remove install directory
if (Test-Path $InstallDir) {
    # Can't delete ourselves while running, so schedule deletion
    $batchFile = Join-Path $env:TEMP "clickpaste_cleanup.cmd"
    @"
@echo off
timeout /t 2 /nobreak > nul
rd /s /q "$InstallDir"
del "%~f0"
"@ | Set-Content $batchFile -Encoding ASCII

    Start-Process cmd -ArgumentList "/c `"$batchFile`"" -WindowStyle Hidden
    Write-Host "  Scheduled removal of install directory"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Uninstall complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
