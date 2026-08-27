@echo off
title Microsoft 365 E5 Renew - Live Dashboard Server
cd /d "%~dp0"
echo ==================================================================
echo   KHOI DONG DASHBOARD QUAN LY & THEO DOI E5 RENEW
echo ==================================================================
echo.
echo Dang khoi dong Web Server cuc bo tai http://localhost:5500 ...
python "core\server.py"
if %ERRORLEVEL% NEQ 0 (
    echo Python khong kha dung, khoi dong qua PowerShell...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "core\E5-Dashboard.ps1"
)
pause
