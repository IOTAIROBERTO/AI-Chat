@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: TRAINING AI SERVER - Quick Launcher
:: Double-click this file to start the server GUI.
:: ============================================================================

set "DIR=%~dp0"
if "!DIR:~-1!"=="\" set "DIR=!DIR:~0,-1%"

:: Prefer venv Python (installed by setup)
set "PYTHON=!DIR!\venv\Scripts\pythonw.exe"

:: Fallback 1: venv python.exe (shows a console window but works)
if not exist "!PYTHON!" set "PYTHON=!DIR!\venv\Scripts\python.exe"

:: Fallback 2: system Python on PATH
if not exist "!PYTHON!" (
    for /f "delims=" %%p in ('where pythonw.exe 2^>nul') do (
        if not defined _PY set "_PY=%%p"
    )
    if defined _PY (
        set "PYTHON=!_PY!"
    ) else (
        for /f "delims=" %%p in ('where python.exe 2^>nul') do (
            if not defined _PY2 set "_PY2=%%p"
        )
        if defined _PY2 set "PYTHON=!_PY2!"
    )
)

if not exist "!PYTHON!" (
    echo ERROR: Python not found.
    echo Run the TRAINING AI SERVER installer first.
    echo.
    pause
    exit /b 1
)

set "LAUNCHER=!DIR!\server\launcher.py"
if not exist "!LAUNCHER!" (
    echo ERROR: launcher.py not found at:
    echo   !LAUNCHER!
    echo.
    pause
    exit /b 1
)

:: Launch GUI window-less (pythonw suppresses the console)
start "" "!PYTHON!" "!LAUNCHER!"
exit /b 0
