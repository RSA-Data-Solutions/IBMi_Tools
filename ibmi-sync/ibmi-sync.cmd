@echo off
rem IBM i Unified Sync Tool - Windows launcher for cmd.exe and PowerShell.
rem Runs the "ibmi-sync" bash script that sits next to this file with Git for Windows' bash.
rem Set IBMI_SYNC_BASH to the full path of a bash.exe to skip the search.
setlocal EnableExtensions DisableDelayedExpansion

set "IBMI_SYNC_SCRIPT=%~dp0ibmi-sync"
if not exist "%IBMI_SYNC_SCRIPT%" goto :no_script

set "IBMI_GIT_BASH="
if defined IBMI_SYNC_BASH if exist "%IBMI_SYNC_BASH%" set "IBMI_GIT_BASH=%IBMI_SYNC_BASH%"
if defined IBMI_GIT_BASH goto :run

rem Git for Windows puts only Git\cmd on PATH by default; bash.exe lives in Git\bin.
rem C:\Windows\System32\bash.exe is the WSL launcher and is deliberately never used.
for /f "delims=" %%G in ('where git.exe 2^>nul') do call :try_git "%%~dpG"
if defined IBMI_GIT_BASH goto :run

call :try "%ProgramFiles%\Git\bin\bash.exe"
call :try "%ProgramW6432%\Git\bin\bash.exe"
call :try "%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
call :try "%USERPROFILE%\scoop\apps\git\current\bin\bash.exe"
call :try "%ProgramFiles(x86)%\Git\bin\bash.exe"
if defined IBMI_GIT_BASH goto :run

echo ibmi-sync: Git Bash was not found. Install Git for Windows ^(https://git-scm.com/download/win^) 1>&2
echo            or set IBMI_SYNC_BASH to the full path of Git's bin\bash.exe. 1>&2
exit /b 1

:run
rem bash accepts C:/... paths; forward slashes avoid backslash escaping inside bash.
set "IBMI_SYNC_SCRIPT=%IBMI_SYNC_SCRIPT:\=/%"
"%IBMI_GIT_BASH%" "%IBMI_SYNC_SCRIPT%" %*
exit /b %ERRORLEVEL%

:no_script
echo ibmi-sync: "%IBMI_SYNC_SCRIPT%" not found next to this launcher. Re-run install.sh from Git Bash. 1>&2
exit /b 1

:try_git
rem %1 is the folder of a git.exe: Git\cmd\ (default) or Git\mingw64\bin\.
call :try "%~1..\bin\bash.exe"
call :try "%~1..\..\bin\bash.exe"
exit /b 0

:try
if defined IBMI_GIT_BASH exit /b 0
if exist "%~1" set "IBMI_GIT_BASH=%~f1"
exit /b 0
