@echo off
rem Compatibility entry point. Edit launchers\Sync-OneDrive.bat instead.
call "%~dp0launchers\Sync-OneDrive.bat" %*
exit /b %errorlevel%
