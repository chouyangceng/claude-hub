@echo off
setlocal
chcp 65001 >nul 2>&1
title Claude Hub Installer

echo ============================================
echo        Claude Hub -- One-Click Install
echo ============================================
echo.

set "INSTALL_DIR=%USERPROFILE%\claude-hub"
set "SCRIPT_DIR=%~dp0"

REM Check if already installed
if not exist "%INSTALL_DIR%" goto install
echo [WARN] %INSTALL_DIR% already exists.
echo.
set "OVERWRITE="
set /p "OVERWRITE=Update Claude Hub files? [y/N]: "
if /i "%OVERWRITE%"=="y" goto install
echo.
echo [CANCEL] Installation aborted.
pause
exit /b 0

:install
echo [1/3] Creating install directory...
if exist "%INSTALL_DIR%" goto copy_files
mkdir "%INSTALL_DIR%"
if errorlevel 1 goto install_error

:copy_files
echo [2/3] Copying files...
copy /y "%SCRIPT_DIR%claude-hub.bat" "%INSTALL_DIR%\claude-hub.bat" >nul || goto install_error
copy /y "%SCRIPT_DIR%claude-hub.ps1" "%INSTALL_DIR%\claude-hub.ps1" >nul || goto install_error
copy /y "%SCRIPT_DIR%claude-hub.ico" "%INSTALL_DIR%\claude-hub.ico" >nul || goto install_error

echo [OK] Files copied to %INSTALL_DIR%

echo [3/3] Creating desktop shortcut...

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
   $sc.Save()" || goto install_error

echo [OK] Shortcut created on desktop

echo.
echo ============================================
echo   [DONE] Claude Hub installed successfully!
echo ============================================
echo.
echo   Double-click "Claude Hub" on your desktop.
echo.
pause
exit /b 0

:install_error
echo.
echo [ERROR] Installation failed. Existing files were left in place.
pause
exit /b 1
