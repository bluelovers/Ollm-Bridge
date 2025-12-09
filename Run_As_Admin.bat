@echo off
title Run Ollm Bridge as Administrator

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Already running as administrator...
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File \"%~dp0Ollm_Bridge_v0.6.ps1'"
    goto end
)

:: Run the PowerShell script
echo.
echo Running Ollm Bridge v0.6...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Ollm_Bridge_v0.6.ps1"

:end
echo Ollm Bridge execution completed.
echo Press any key to exit...
pause > nul