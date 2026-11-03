@echo off
title Microsoft 365 E5 Renew - Control Center
cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "launchers\Menu.ps1" %*
