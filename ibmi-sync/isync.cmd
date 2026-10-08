@echo off
REM IBM i Unified Sync Tool - Windows Batch Wrapper for isync
REM This file allows running isync from Windows Command Prompt or PowerShell

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

REM Check if Git Bash is installed
where bash >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Git Bash not found. Please install Git for Windows and ensure bash is in PATH.
    exit /b 1
)

REM Determine the location of isync script
REM We need to find the script relative to this batch file
set ISYNC_SCRIPT=%SCRIPT_DIR%ibmi-sync

REM Run the main script using bash
bash -c "cd '%SCRIPT_DIR%'; exec ./ibmi-sync "$@"" %*

REM Exit with the same error code as the bash script
exit /b %errorlevel%
