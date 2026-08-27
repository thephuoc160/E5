@echo off
title Microsoft 365 E5 Renew - Master Runner
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Run-All.ps1"
echo.
pause
