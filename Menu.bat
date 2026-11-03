@echo off
rem Compatibility entry point. Edit launchers\Menu.bat instead.
call "%~dp0launchers\Menu.bat" %*
exit /b %errorlevel%
