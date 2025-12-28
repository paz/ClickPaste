<#
.SYNOPSIS
    ClickPaste Installer
.DESCRIPTION
    Installs ClickPaste to Program Files (system) or AppData (user).
    Optionally configures to start with Windows.
.PARAMETER SystemInstall
    Install for all users (requires admin). Default is current user only.
.PARAMETER StartWithWindows
    Add ClickPaste to Windows startup.
.PARAMETER Silent
    Run without prompts (use defaults or specified parameters).
#>
param(
    [switch]$SystemInstall,
    [switch]$StartWithWindows,
    [switch]$Silent
)

$ErrorActionPreference = "Stop"
$AppName = "ClickPaste"
$ExeName = "ClickPaste.exe"

# Determine install location
if ($SystemInstall) {
    $InstallDir = Join-Path $env:ProgramFiles $AppName
    $StartMenuDir = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
    $StartupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
} else {
    $InstallDir = Join-Path $env:LOCALAPPDATA $AppName
    $StartMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    $StartupKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
}

$ExePath = Join-Path $InstallDir $ExeName
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check for admin rights if system install
if ($SystemInstall) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "System install requires administrator privileges." -ForegroundColor Red
        Write-Host "Please run this script as Administrator, or use user install (no -SystemInstall flag)." -ForegroundColor Yellow
        exit 1
    }
}

# Interactive mode
if (-not $Silent) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       $AppName Installer" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not $SystemInstall) {
        $response = Read-Host "Install for all users (requires admin)? [y/N]"
        if ($response -eq 'y' -or $response -eq 'Y') {
            # Re-launch as admin with SystemInstall flag
            $args = "-ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -SystemInstall"
            if ($StartWithWindows) { $args += " -StartWithWindows" }
            Start-Process powershell -Verb RunAs -ArgumentList $args
            exit 0
        }
    }

    Write-Host "Install location: $InstallDir" -ForegroundColor Gray
    Write-Host ""

    if (-not $StartWithWindows) {
        $response = Read-Host "Start ClickPaste with Windows? [Y/n]"
        if ($response -ne 'n' -and $response -ne 'N') {
            $StartWithWindows = $true
        }
    }
}

Write-Host ""
Write-Host "Installing $AppName..." -ForegroundColor Green

# Create install directory
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "  Created directory: $InstallDir"
}

# Copy files
$filesToCopy = @($ExeName, "Install.ps1", "Uninstall.ps1", "Install.cmd", "Uninstall.cmd")
foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $ScriptDir $file
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath $InstallDir -Force
        Write-Host "  Copied: $file"
    }
}

# Also copy license if present
$licensePath = Join-Path $ScriptDir "AutoIt_License.html"
if (Test-Path $licensePath) {
    Copy-Item $licensePath $InstallDir -Force
    Write-Host "  Copied: AutoIt_License.html"
}

# Create Start Menu shortcut
$shortcutPath = Join-Path $StartMenuDir "$AppName.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $ExePath
$shortcut.Description = "Paste clipboard as keystrokes"
$shortcut.WorkingDirectory = $InstallDir
$shortcut.Save()
Write-Host "  Created Start Menu shortcut"

# Configure startup
if ($StartWithWindows) {
    Set-ItemProperty -Path $StartupKey -Name $AppName -Value $ExePath -Force
    Write-Host "  Added to Windows startup"
}

# Store install info for uninstaller
$installInfo = @{
    InstallDir = $InstallDir
    SystemInstall = $SystemInstall
    StartWithWindows = $StartWithWindows
    InstalledDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$installInfo | ConvertTo-Json | Set-Content (Join-Path $InstallDir "install.json")

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "You can start $AppName from the Start Menu," -ForegroundColor Gray
Write-Host "or run it directly from: $ExePath" -ForegroundColor Gray
Write-Host ""

if (-not $Silent) {
    $response = Read-Host "Start $AppName now? [Y/n]"
    if ($response -ne 'n' -and $response -ne 'N') {
        Start-Process $ExePath
    }
}
