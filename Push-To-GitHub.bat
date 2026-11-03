@echo off
rem Compatibility entry point. Edit launchers\Push-To-GitHub.bat instead.
call "%~dp0launchers\Push-To-GitHub.bat" %*
exit /b %errorlevel%
