@echo off
REM ============================================================
REM FinansAsistan - Windows Baslatma (Unified)
REM ============================================================

REM Set UTF-8 encoding for console
chcp 65001 >nul 2>&1

cd /d "%~dp0\.."
powershell -ExecutionPolicy Bypass -File "%~dp0\start-windows.ps1"
pause

