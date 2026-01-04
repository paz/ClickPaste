@echo off
setlocal EnableDelayedExpansion

:: ClickPaste Uninstaller (Batch version)

set "AppName=ClickPaste"
set "ExeName=ClickPaste.exe"
set "ScriptDir=%~dp0"
set "ScriptDir=%ScriptDir:~0,-1%"
set "InstallDir=%ScriptDir%"

echo.
echo ========================================
echo        %AppName% Uninstaller
echo ========================================
echo.

:: Detect install type from location
echo %InstallDir% | findstr /i "%ProgramFiles%" >nul
if %errorLevel% == 0 (
    set "SystemInstall=1"
    set "StartMenuDir=%ProgramData%\Microsoft\Windows\Start Menu\Programs"
    set "StartupReg=HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
) else (
    set "SystemInstall=0"
    set "StartMenuDir=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
    set "StartupReg=HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
)

:: Check for admin if system install
if "%SystemInstall%"=="1" (
    net session >nul 2>&1
    if not %errorLevel% == 0 (
        echo Uninstalling system installation requires administrator privileges.
        echo Please right-click and "Run as administrator".
        echo.
        pause
        exit /b 1
    )
)

echo This will remove %AppName% from: %InstallDir%
echo.
set /p "Confirm=Continue with uninstall? [y/N]: "
if /i not "%Confirm%"=="y" (
    echo Uninstall cancelled.
    goto :end
)

echo.
set /p "RemoveSettings=Remove user settings? [Y/n]: "

echo.
echo Uninstalling %AppName%...

:: Stop running instance
taskkill /f /im "%ExeName%" >nul 2>&1
if %errorLevel% == 0 (
    echo   Stopped running instance
    timeout /t 1 /nobreak >nul
)

:: Remove startup entry (try both locations)
reg delete "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%AppName%" /f >nul 2>&1
if %errorLevel% == 0 echo   Removed from user startup
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%AppName%" /f >nul 2>&1
if %errorLevel% == 0 echo   Removed from system startup

:: Remove Start Menu shortcuts (both locations)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\%AppName%.lnk" (
    del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\%AppName%.lnk" >nul 2>&1
    echo   Removed user Start Menu shortcut
)
if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\%AppName%.lnk" (
    del /f /q "%ProgramData%\Microsoft\Windows\Start Menu\Programs\%AppName%.lnk" >nul 2>&1
    echo   Removed system Start Menu shortcut
)

:: Remove user settings
if /i not "%RemoveSettings%"=="n" (
    reg delete "HKCU\SOFTWARE\%AppName%" /f >nul 2>&1
    if %errorLevel% == 0 echo   Removed user settings
)

:: Schedule removal of install directory (can't delete while script is running)
set "CleanupScript=%TEMP%\clickpaste_cleanup.cmd"
echo @echo off > "%CleanupScript%"
echo timeout /t 2 /nobreak ^> nul >> "%CleanupScript%"
echo rd /s /q "%InstallDir%" >> "%CleanupScript%"
echo del "%%~f0" >> "%CleanupScript%"

start /b "" cmd /c "%CleanupScript%"
echo   Scheduled removal of install directory

echo.
echo ========================================
echo   Uninstall complete!
echo ========================================
echo.

:end
endlocal
