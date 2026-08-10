@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Uninstall-HuymaierConsole.ps1"
set "HC_EXIT=%ERRORLEVEL%"
endlocal & exit /b %HC_EXIT%
