@echo off
rem Compatibility entry point. Edit launchers\Run-Api.bat instead.
call "%~dp0launchers\Run-Api.bat" %*
exit /b %errorlevel%
