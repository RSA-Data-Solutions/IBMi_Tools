@echo off
rem IBM i Unified Sync Tool - "isync" shorthand for ibmi-sync.cmd (cmd.exe and PowerShell).
call "%~dp0ibmi-sync.cmd" %*
exit /b %ERRORLEVEL%
