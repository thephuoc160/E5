@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "core\E5-OneDriveSync.ps1"
echo.
pause
