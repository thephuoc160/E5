@echo off
title Microsoft 365 E5 - Reconnect rclone 1Drive OAuth
cd /d "%~dp0"
echo ==================================================================
echo   KHOI PHUC / DANG NHAP LAI TOKEN OAUTH RCLONE CHO 1Drive:
echo ==================================================================
echo.
echo Trinh duyet web se tu dong mo ra. 
echo Hay dang nhap tai khoan Microsoft 365 E5 Admin cua ban va chon Accept / Dong y.
echo.
tools\rclone.exe config reconnect 1Drive:
echo.
echo ==================================================================
echo Hoan tat! Bay gio ban co the nhan nut Mount o dia M: tren Dashboard.
echo ==================================================================
pause
