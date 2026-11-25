@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0Install-OpenClaw.ps1"
