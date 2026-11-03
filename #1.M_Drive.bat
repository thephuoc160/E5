@echo off
rem Compatibility entry point. Edit launchers\Mount-Drive.bat instead.
call "%~dp0launchers\Mount-Drive.bat" %*
exit /b %errorlevel%
