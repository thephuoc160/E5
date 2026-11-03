@echo off
rem Compatibility entry point. Edit launchers\Run-SharePoint.bat instead.
call "%~dp0launchers\Run-SharePoint.bat" %*
exit /b %errorlevel%
