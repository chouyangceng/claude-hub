@echo off
chcp 65001 >nul 2>&1
title Claude Hub Installer

echo ============================================
echo        Claude Hub -- One-Click Install
echo ============================================
echo.

set "INSTALL_DIR=%USERPROFILE%\claude-hub"
set "DESKTOP=%USERPROFILE%\Desktop"
set "SCRIPT_DIR=%~dp0"

REM Check if already installed
if exist "%INSTALL_DIR%" (
    echo [WARN] %INSTALL_DIR% already exists.
    echo.
    set /p "OVERWRITE=Overwrite? [y/N]: "
    if /i not "!OVERWRITE!"=="y" (
        echo.
        echo [CANCEL] Installation aborted.
        pause
        exit /b 0
    )
    echo [OK] Removing old installation...
    rmdir /s /q "%INSTALL_DIR%"
)

echo [1/4] Creating install directory...
mkdir "%INSTALL_DIR%"

echo [2/4] Copying files...
copy /y "%SCRIPT_DIR%claude-hub.bat" "%INSTALL_DIR%\claude-hub.bat" >nul
copy /y "%SCRIPT_DIR%claude-hub.ps1" "%INSTALL_DIR%\claude-hub.ps1" >nul
copy /y "%SCRIPT_DIR%claude-hub.ico" "%INSTALL_DIR%\claude-hub.ico" >nul

echo [OK] Files copied to %INSTALL_DIR%

echo [3/4] Creating desktop shortcut...

REM Kill explorer to refresh icon cache
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul

REM Remove old shortcut
del /f /q "%DESKTOP%\Claude Hub.lnk" >nul 2>&1

REM Create shortcut using PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ws = New-Object -ComObject WScript.Shell; ^
   $sc = $ws.CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Claude Hub.lnk'); ^
   $sc.TargetPath = 'cmd.exe'; ^
   $sc.Arguments = '/c \"'+[Environment]::GetFolderPath('UserProfile')+'\claude-hub\claude-hub.bat\"'; ^
   $sc.WorkingDirectory = [Environment]::GetFolderPath('UserProfile'); ^
   $sc.WindowStyle = 1; ^
   $sc.Description = 'Claude Code'; ^
   $sc.IconLocation = [Environment]::GetFolderPath('UserProfile') + '\claude-hub\claude-hub.ico,0'; ^
   $sc.Save()"

echo [OK] Shortcut created on desktop

echo [4/4] Refreshing icon cache...
del /f /q "%LOCALAPPDATA%\IconCache.db" >nul 2>&1
if exist "%LOCALAPPDATA%\Microsoft\Windows\Explorer" (
    del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*" >nul 2>&1
)
start explorer.exe

echo.
echo ============================================
echo   [DONE] Claude Hub installed successfully!
echo ============================================
echo.
echo   Double-click "Claude Hub" on your desktop.
echo.
pause
