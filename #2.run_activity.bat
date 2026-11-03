@echo off
rem Compatibility entry point. Edit launchers\Run-Activity.bat instead.
call "%~dp0launchers\Run-Activity.bat" %*
exit /b %errorlevel%
