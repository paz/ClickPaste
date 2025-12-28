@echo off
setlocal EnableDelayedExpansion

:: ClickPaste Installer (Batch version)
:: For users who cannot run PowerShell scripts

set "AppName=ClickPaste"
set "ExeName=ClickPaste.exe"
set "ScriptDir=%~dp0"
set "ScriptDir=%ScriptDir:~0,-1%"

echo.
echo ========================================
echo        %AppName% Installer
echo ========================================
echo.

:: Check for admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    set "IsAdmin=1"
) else (
    set "IsAdmin=0"
)

:: Ask for install type
echo Install options:
echo   1. Current user only (recommended)
echo   2. All users (requires admin)
echo.
set /p "InstallType=Choose [1]: "
if "%InstallType%"=="" set "InstallType=1"

if "%InstallType%"=="2" (
    if "%IsAdmin%"=="0" (
        echo.
        echo System install requires administrator privileges.
        echo Please right-click and "Run as administrator".
        echo.
        pause
        exit /b 1
    )
    set "InstallDir=%ProgramFiles%\%AppName%"
    set "StartMenuDir=%ProgramData%\Microsoft\Windows\Start Menu\Programs"
    set "StartupReg=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
) else (
    set "InstallDir=%LOCALAPPDATA%\%AppName%"
    set "StartMenuDir=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
    set "StartupReg=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

echo.
echo Install location: %InstallDir%
echo.

:: Ask about startup
set /p "StartWithWindows=Start with Windows? [Y/n]: "
if /i "%StartWithWindows%"=="n" (
    set "AddStartup=0"
) else (
    set "AddStartup=1"
)

echo.
echo Installing %AppName%...

:: Create install directory
if not exist "%InstallDir%" (
    mkdir "%InstallDir%"
    echo   Created directory
)

:: Copy files
if exist "%ScriptDir%\%ExeName%" (
    copy /y "%ScriptDir%\%ExeName%" "%InstallDir%\" >nul
    echo   Copied: %ExeName%
)
if exist "%ScriptDir%\Install.ps1" (
    copy /y "%ScriptDir%\Install.ps1" "%InstallDir%\" >nul
    echo   Copied: Install.ps1
)
if exist "%ScriptDir%\Uninstall.ps1" (
    copy /y "%ScriptDir%\Uninstall.ps1" "%InstallDir%\" >nul
    echo   Copied: Uninstall.ps1
)
if exist "%ScriptDir%\Install.cmd" (
    copy /y "%ScriptDir%\Install.cmd" "%InstallDir%\" >nul
    echo   Copied: Install.cmd
)
if exist "%ScriptDir%\Uninstall.cmd" (
    copy /y "%ScriptDir%\Uninstall.cmd" "%InstallDir%\" >nul
    echo   Copied: Uninstall.cmd
)
if exist "%ScriptDir%\AutoIt_License.html" (
    copy /y "%ScriptDir%\AutoIt_License.html" "%InstallDir%\" >nul
    echo   Copied: AutoIt_License.html
)

:: Create Start Menu shortcut using PowerShell (most reliable way)
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%StartMenuDir%\%AppName%.lnk'); $s.TargetPath = '%InstallDir%\%ExeName%'; $s.Description = 'Paste clipboard as keystrokes'; $s.WorkingDirectory = '%InstallDir%'; $s.Save()"
if %errorLevel% == 0 (
    echo   Created Start Menu shortcut
) else (
    echo   Warning: Could not create Start Menu shortcut
)

:: Add to startup
if "%AddStartup%"=="1" (
    reg add "%StartupReg%" /v "%AppName%" /t REG_SZ /d "%InstallDir%\%ExeName%" /f >nul 2>&1
    if %errorLevel% == 0 (
        echo   Added to Windows startup
    ) else (
        echo   Warning: Could not add to startup
    )
)

:: Save install info
echo {"InstallDir":"%InstallDir:\=\\%","SystemInstall":%InstallType:1=false%,"StartWithWindows":%AddStartup%} > "%InstallDir%\install.json"

echo.
echo ========================================
echo   Installation complete!
echo ========================================
echo.
echo You can start %AppName% from the Start Menu,
echo or run it directly from: %InstallDir%\%ExeName%
echo.

set /p "StartNow=Start %AppName% now? [Y/n]: "
if /i not "%StartNow%"=="n" (
    start "" "%InstallDir%\%ExeName%"
)

endlocal
