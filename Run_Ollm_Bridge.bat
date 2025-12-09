@echo off
title Ollm Bridge v0.6 - Administrator Execution
color 0A

echo.
echo ================================================
echo          Ollm Bridge v0.6 Launcher
echo ================================================
echo.
echo This batch file will run Ollm Bridge with administrator rights.
echo.
echo Usage examples:
echo   1. Run with manual confirmation (default)
echo   2. Run with skip deletion mode
echo   3. Run with automatic execution mode
echo   4. Run with manual confirmation mode
echo.
echo Choose execution mode or press Enter for default:
echo.
echo   [1] Default (Manual Confirmation)
echo   [2] Safe Mode (-SafeMode true)
echo   [3] Auto Mode (-SafeMode false)
echo   [4] Manual Mode (-SafeMode null)
echo.
set /p choice="Enter your choice (1-4) or press Enter for default: "

if "%choice%"=="" set choice=1
if "%choice%"=="1" goto manual
if "%choice%"=="2" goto skip
if "%choice%"=="3" goto auto
if "%choice%"=="4" goto manual_mode

:manual
echo.
echo Running Ollm Bridge with default settings...
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File \"%~dp0Ollm_Bridge_v0.6.ps1'"
goto end

:skip
echo.
echo Running Ollm Bridge in Safe Mode (skip deletion)...
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File \"%~dp0Ollm_Bridge_v0.6.ps1' '-SafeMode true'"
goto end

:auto
echo.
echo Running Ollm Bridge in Auto Mode (no confirmation)...
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File \"%~dp0Ollm_Bridge_v0.6.ps1' '-SafeMode false'"
goto end

:manual_mode
echo.
echo Running Ollm Bridge in Manual Mode (confirmation required)...
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-File \"%~dp0Ollm_Bridge_v0.6.ps1' '-SafeMode null'"
goto end

:end
echo.
echo Ollm Bridge execution completed.
echo Press any key to exit...
pause > nul