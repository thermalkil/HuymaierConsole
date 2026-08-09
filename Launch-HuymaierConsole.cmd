@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0HuymaierConsole.exe" (
    start "Huymaier Console" "%~dp0HuymaierConsole.exe"
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Install-HuymaierConsole.ps1"
)
endlocal
