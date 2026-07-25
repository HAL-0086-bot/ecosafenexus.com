@echo off
rem ============================================================
rem  Kindle capture launcher for JAPANESE vertical / right-bound
rem  books (next page is on the LEFT). Double-click to start.
rem  capture_kindle.ps1 must sit in the SAME folder as this file.
rem ============================================================
chcp 65001 >nul
echo Starting capture for a Japanese vertical (right-bound) book...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture_kindle.ps1" -Rtl
echo.
echo ------------------------------------------------------------
echo  Done. You can close this window.
echo ------------------------------------------------------------
pause
