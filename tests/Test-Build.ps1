<#
.SYNOPSIS
    ClickPaste build verification tests
.DESCRIPTION
    Verifies build outputs are correct and functional.
    Run after building Release and Release-NoAutoIt configurations.
.PARAMETER Version
    Expected version (e.g., "1.4.1"). If provided, validates EXE version matches.
#>
param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
$script:TestsPassed = 0
$script:TestsFailed = 0

function Test-Condition {
    param(
        [string]$Name,
        [scriptblock]$Condition,
        [string]$FailMessage
    )

    Write-Host -NoNewline "  Testing: $Name... "

    try {
        $result = & $Condition
        if ($result) {
            Write-Host "PASSED" -ForegroundColor Green
            $script:TestsPassed++
            return $true
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            if ($FailMessage) { Write-Host "    $FailMessage" -ForegroundColor Yellow }
            $script:TestsFailed++
            return $false
        }
    } catch {
        Write-Host "FAILED (Exception)" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Yellow
        $script:TestsFailed++
        return $false
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ClickPaste Build Verification Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# Release Build Tests
# =============================================================================
Write-Host "Release Build:" -ForegroundColor White

$releaseDir = "bin/Release"
$releaseExe = "$releaseDir/ClickPaste.exe"

Test-Condition "Release directory exists" {
    Test-Path $releaseDir
} "Directory not found: $releaseDir"

Test-Condition "ClickPaste.exe exists" {
    Test-Path $releaseExe
} "File not found: $releaseExe"

Test-Condition "Install.cmd exists" {
    Test-Path "$releaseDir/Install.cmd"
} "Install script missing"

Test-Condition "Uninstall.cmd exists" {
    Test-Path "$releaseDir/Uninstall.cmd"
} "Uninstall script missing"

Test-Condition "AutoIt_License.html exists (Release has AutoIt)" {
    Test-Path "$releaseDir/AutoIt_License.html"
} "AutoIt license missing - Costura may not have embedded AutoIt"

Test-Condition "No loose DLLs (single-file build)" {
    $dlls = Get-ChildItem "$releaseDir/*.dll" -ErrorAction SilentlyContinue
    $dlls.Count -eq 0
} "Found loose DLLs - Costura embedding may have failed"

Test-Condition "No PDB files in Release" {
    $pdbs = Get-ChildItem "$releaseDir/*.pdb" -ErrorAction SilentlyContinue
    $pdbs.Count -eq 0
} "Found PDB files in Release output"

# Version test (if version provided)
if ($Version) {
    Test-Condition "EXE version matches $Version" {
        $exeVersion = (Get-Item $releaseExe).VersionInfo.FileVersion
        # FileVersion is X.Y.Z.W, we check X.Y.Z matches
        $exeVersion -match "^$([regex]::Escape($Version))\."
    } "EXE version does not match expected: $Version"
}

Write-Host ""

# =============================================================================
# Release-NoAutoIt Build Tests
# =============================================================================
Write-Host "Release-NoAutoIt Build:" -ForegroundColor White

$noAutoItDir = "bin/Release-NoAutoIt"
$noAutoItExe = "$noAutoItDir/ClickPaste.exe"

Test-Condition "Release-NoAutoIt directory exists" {
    Test-Path $noAutoItDir
} "Directory not found: $noAutoItDir"

Test-Condition "ClickPaste.exe exists" {
    Test-Path $noAutoItExe
} "File not found: $noAutoItExe"

Test-Condition "Install.cmd exists" {
    Test-Path "$noAutoItDir/Install.cmd"
} "Install script missing"

Test-Condition "Uninstall.cmd exists" {
    Test-Path "$noAutoItDir/Uninstall.cmd"
} "Uninstall script missing"

Test-Condition "No AutoIt_License.html (NoAutoIt build)" {
    -not (Test-Path "$noAutoItDir/AutoIt_License.html")
} "AutoIt license should NOT be in NoAutoIt build"

Test-Condition "No loose DLLs (single-file build)" {
    $dlls = Get-ChildItem "$noAutoItDir/*.dll" -ErrorAction SilentlyContinue
    $dlls.Count -eq 0
} "Found loose DLLs - Costura embedding may have failed"

Test-Condition "NoAutoIt EXE is smaller than Release EXE" {
    $releaseSize = (Get-Item $releaseExe).Length
    $noAutoItSize = (Get-Item $noAutoItExe).Length
    $noAutoItSize -lt $releaseSize
} "NoAutoIt build should be smaller (no AutoIt DLLs embedded)"

# Version test (if version provided)
if ($Version) {
    Test-Condition "EXE version matches $Version" {
        $exeVersion = (Get-Item $noAutoItExe).VersionInfo.FileVersion
        $exeVersion -match "^$([regex]::Escape($Version))\."
    } "EXE version does not match expected: $Version"
}

Write-Host ""

# =============================================================================
# Install Script Syntax Tests
# =============================================================================
Write-Host "Install Script Validation:" -ForegroundColor White

Test-Condition "Install.cmd has valid syntax" {
    $content = Get-Content "$releaseDir/Install.cmd" -Raw
    # Check for common CMD patterns that indicate valid script
    $content -match "setlocal" -and $content -match "endlocal"
} "Install.cmd may have syntax issues"

Test-Condition "Uninstall.cmd has valid syntax" {
    $content = Get-Content "$releaseDir/Uninstall.cmd" -Raw
    $content -match "setlocal" -and $content -match "endlocal"
} "Uninstall.cmd may have syntax issues"

Test-Condition "Install.cmd contains expected app name" {
    $content = Get-Content "$releaseDir/Install.cmd" -Raw
    $content -match "ClickPaste"
} "Install.cmd missing app name"

Write-Host ""

# =============================================================================
# Summary
# =============================================================================
Write-Host "========================================" -ForegroundColor Cyan
$total = $script:TestsPassed + $script:TestsFailed
Write-Host "  Results: $($script:TestsPassed)/$total tests passed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($script:TestsFailed -gt 0) {
    Write-Error "$($script:TestsFailed) test(s) failed!"
    exit 1
}

Write-Host "All tests passed!" -ForegroundColor Green
exit 0
