@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "core\E5-SharePointSync.ps1"
echo.
pause
