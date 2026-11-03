@echo off
rem Compatibility entry point. Edit launchers\Unmount-Drive.bat instead.
call "%~dp0launchers\Unmount-Drive.bat" %*
exit /b %errorlevel%
