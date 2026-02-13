@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: VR TRAINING AI SERVER - Security Configuration
:: Configures Firewall and Windows Defender
:: ============================================================================

:: Check Admin
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Administrator privileges required!
    exit /b 1
)

set "INSTALL_DIR=%~1"
if "%INSTALL_DIR%"=="" set "INSTALL_DIR=%~dp0..\.."

:: Resolve absolute path
pushd "%INSTALL_DIR%"
set "ABS_INSTALL_DIR=%CD%"
popd

echo [SECURITY] Configuring security for: %ABS_INSTALL_DIR%

:: 1. FIREWALL RULES
:: =================
echo.
echo [FIREWALL] Configuring rules...

:: Remove old rules
netsh advfirewall firewall delete rule name="TRAINING AI SERVER" >nul 2>&1
netsh advfirewall firewall delete rule name="VR Manual Server" >nul 2>&1

:: Rule 1: Port 5000-5010 (TCP) - All Profiles
echo   - Adding port range rule (5000-5010)...
netsh advfirewall firewall add rule name="TRAINING AI SERVER (Ports)" dir=in action=allow protocol=TCP localport=5000-5010 profile=any >nul

:: Rule 2: Program-based rule for python (if found)
if exist "%ABS_INSTALL_DIR%\server\offline_server.py" (
    echo   - Adding program rule for Python server...
    
    :: Attempt to find python path used by installer
    set "PYTHON_EXE="
    where python.exe >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        for /f "delims=" %%p in ('where python.exe') do set "PYTHON_EXE=%%p"
    )
    
    if defined PYTHON_EXE (
         netsh advfirewall firewall add rule name="TRAINING AI SERVER (Python)" dir=in action=allow program="!PYTHON_EXE!" profile=any >nul
         echo     Linked to: !PYTHON_EXE!
    )
)

:: 2. WINDOWS DEFENDER EXCLUSIONS
:: ==============================
echo.
echo [DEFENDER] Adding exclusions...

:: Exclude Installation Directory
powershell -Command "Add-MpPreference -ExclusionPath '%ABS_INSTALL_DIR%' -Force" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo   - Folder exclusion added: %ABS_INSTALL_DIR%
) else (
    echo   - [WARN] Failed to add folder exclusion
)

:: Exclude Processes
powershell -Command "Add-MpPreference -ExclusionProcess 'python.exe' -Force" >nul 2>&1
powershell -Command "Add-MpPreference -ExclusionProcess 'ollama.exe' -Force" >nul 2>&1
echo   - Process exclusions added (python.exe, ollama.exe)

echo.
echo [SECURITY] Configuration completed.
exit /b 0
