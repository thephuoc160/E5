@echo off
title Microsoft 365 E5 - Day ma nguon len GitHub (thephuoc160/E5)
cd /d "%~dp0"
echo ==================================================================
echo   DANG DONG BO VA DAY MA NGUON LEN GITHUB (thephuoc160/E5)
echo ==================================================================
echo.
git add .
git commit -m "feat: Upgrade Microsoft 365 E5 Renew 2.5 with Dashboard, JSON Batching, Delta Sync & GitHub Actions"
echo.
echo Dang day code len https://github.com/thephuoc160/E5 ...
git push -u origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Dang thu force push de dong bo voi nhanh main hien tai...
    git push -f origin main
)
echo.
echo ==================================================================
echo DA HOAN TAT DONG BO LEN GITHUB!
echo ==================================================================
pause
