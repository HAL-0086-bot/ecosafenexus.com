@echo off
rem ============================================================
rem  Kindle capture launcher (double-click this file to start)
rem  capture_kindle.ps1 must sit in the SAME folder as this file.
rem ============================================================
chcp 65001 >nul
echo Starting Kindle auto-capture...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture_kindle.ps1"
echo.
echo ------------------------------------------------------------
echo  Done. You can close this window.
echo ------------------------------------------------------------
pause
