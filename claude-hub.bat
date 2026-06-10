@echo off
chcp 65001 >nul 2>&1
title Claude Hub

REM Use %~dp0 to locate files relative to this bat file
set "HUB_DIR=%~dp0"
set "PATH=%PATH%;%APPDATA%\npm;%USERPROFILE%\AppData\Roaming\npm"

if "%1"=="--direct" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%HUB_DIR%claude-hub.ps1" --direct
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%HUB_DIR%claude-hub.ps1"
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Claude Hub exited with code %ERRORLEVEL%
    pause
)
