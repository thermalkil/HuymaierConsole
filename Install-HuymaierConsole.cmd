@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title Huymaier Console v0.25.6 Installer

echo ============================================================
echo  Huymaier Console v0.25.6 Installer
echo ============================================================
echo.
echo The installer will remain open if anything fails.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-HuymaierConsole.ps1"
set "HC_EXIT=%ERRORLEVEL%"

if not "%HC_EXIT%"=="0" (
    echo.
    echo ============================================================
    echo  INSTALLATION FAILED - exit code %HC_EXIT%
    echo ============================================================
    echo.
    echo The full error was saved under:
    echo   %%LOCALAPPDATA%%\Huymaier Console\Logs
    echo.
    echo Please send the newest install-v0.25.6-*.log file.
    echo.
    pause
    exit /b %HC_EXIT%
)

echo.
echo Installation completed successfully.
timeout /t 3 /nobreak >nul
exit /b 0
