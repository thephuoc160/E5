@echo off
title Microsoft 365 E5 Renew - Live Dashboard Server
cd /d "%~dp0.."
echo ==================================================================
echo   KHOI DONG DASHBOARD QUAN LY & THEO DOI E5 RENEW
echo ==================================================================
echo.
echo Dang khoi dong Web Server cuc bo tai http://127.0.0.1:8765 ...
python "dashboard\server.py"
if %ERRORLEVEL% NEQ 0 (
    echo Python khong kha dung, khoi dong qua PowerShell...
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "dashboard\E5-Dashboard.ps1"
)
pause
