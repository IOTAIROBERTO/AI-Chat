@echo off
:: ============================================================================
:: TRAINING AI SERVER - Launcher v4.0
:: Improved with Python detection and launcher v4
:: ============================================================================

title TRAINING AI SERVER v4.0 - Starting...

:: Determine script directory
set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: Try to find Python
set "PYTHON_EXE="

:: Method 1: Check if python is in PATH
where python.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%p in ('where python.exe') do (
        set "PYTHON_EXE=%%p"
        goto :FOUND_PYTHON
    )
)

:: Method 2: Check common installation paths
for %%p in (
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "C:\Python313\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
    "%ProgramFiles%\Python313\python.exe"
    "%ProgramFiles%\Python312\python.exe"
    "%ProgramFiles%\Python311\python.exe"
) do (
    if exist %%p (
        set "PYTHON_EXE=%%p"
        goto :FOUND_PYTHON
    )
)

:: Python not found
echo ERROR: Python not found!
echo.
echo Please make sure Python 3.11+ is installed.
echo Download from: https://www.python.org/downloads/
echo.
pause
exit /b 1

:FOUND_PYTHON
:: Check if using launcher (v5.1)
if exist "%SCRIPT_DIR%\server\launcher.py" (
    echo Starting GUI Launcher v5.1...
    echo.
    start "" "%PYTHON_EXE%" "%SCRIPT_DIR%\server\launcher.py"
    exit /b 0
)

:: Fallback to console mode
if exist "%SCRIPT_DIR%\server\offline_server.py" (
    echo Starting server (console mode)...
    echo.
    "%PYTHON_EXE%" "%SCRIPT_DIR%\server\offline_server.py"
    pause
    exit /b 0
)

:: No server found
echo ERROR: Server files not found!
echo.
echo Expected location:
echo   %SCRIPT_DIR%\server\launcher.py
echo   or
echo   %SCRIPT_DIR%\server\offline_server.py
echo.
pause
exit /b 1
