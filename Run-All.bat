@echo off
rem Compatibility entry point. Edit launchers\Run-All.bat instead.
call "%~dp0launchers\Run-All.bat" %*
exit /b %errorlevel%
