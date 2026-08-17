@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0HuymaierConsole.exe" (
    "%~dp0HuymaierConsole.exe" --windowed
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0HuymaierBootstrap.ps1" -Windowed
)
endlocal
