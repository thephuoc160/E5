@echo off
rem Compatibility entry point. Edit launchers\Dashboard.bat instead.
call "%~dp0launchers\Dashboard.bat" %*
exit /b %errorlevel%
