@echo off
title Run Ollm Bridge as Administrator

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Already running as administrator...
) else (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" && Ollm_Bridge_v0.6.ps1' -Verb RunAs"
    goto :eof
)

:: Run the PowerShell script
echo.
echo Running Ollm Bridge v0.6...
echo.
powershell -ExecutionPolicy Bypass -File "Ollm_Bridge_v0.6.ps1"
pause