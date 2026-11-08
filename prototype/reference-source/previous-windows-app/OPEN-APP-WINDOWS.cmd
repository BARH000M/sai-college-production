@echo off
setlocal
title Sai College App
cd /d "%~dp0"

echo.
echo Starting Sai College App...
echo Keep this window open while using the app.
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is required but is not installed.
  echo Install the LTS version from https://nodejs.org/ then run this file again.
  start "" "https://nodejs.org/"
  pause
  exit /b 1
)

if not exist "node_modules" (
  echo First-time setup: installing app components. Please wait...
  call npm install
  if errorlevel 1 goto :failed
)

if not exist "dist\boot.js" (
  echo Preparing the app...
  call npm run build
  if errorlevel 1 goto :failed
)

start "" cmd /c "timeout /t 4 /nobreak >nul & start "" "http://localhost:3000""
call npm start
goto :eof

:failed
echo.
echo The app could not start. Take a screenshot of this window and send it back.
pause
exit /b 1
