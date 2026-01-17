@echo off
:: ============================================================================
:: POST-INSTALL LAUNCHER
:: Launches VR Training AI Server after installation completes
:: ============================================================================

:: Wait for installer to fully close
timeout /t 2 /nobreak >nul 2>&1

:: Set script directory
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

:: Find Python
set "PYTHON_EXE="

:: Check PATH first
where python.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%p in ('where python.exe') do (
        set "PYTHON_EXE=%%p"
        goto :FOUND_PYTHON
    )
)

:: Check common locations
for %%p in (
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "C:\Python313\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
) do (
    if exist %%p (
        set "PYTHON_EXE=%%p"
        goto :FOUND_PYTHON
    )
)

:: Python not found - exit silently
exit /b 0

:FOUND_PYTHON
:: Launch the GUI launcher
if exist "%APP_DIR%\server\launcher.py" (
    start "" "%PYTHON_EXE%" "%APP_DIR%\server\launcher.py"
) else if exist "%APP_DIR%\start_server.bat" (
    start "" "%APP_DIR%\start_server.bat"
)

exit /b 0
