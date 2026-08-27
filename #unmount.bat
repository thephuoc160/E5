@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "core\E5-RcloneMount.ps1" -Action Unmount
pause