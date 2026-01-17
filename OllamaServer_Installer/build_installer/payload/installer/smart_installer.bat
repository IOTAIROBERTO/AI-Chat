@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================================
:: TRAINING AI SERVER - VISIBLE Installation Script
:: Version: 3.1.1 - FIXED: Proper path quoting
:: ============================================================================

title TRAINING AI SERVER - Installation in Progress

:: ============================================================================
:: CONFIGURATION
:: ============================================================================
set "SCRIPT_VERSION=3.1.1"
set "APP_NAME=TRAINING AI SERVER"
set "INSTALL_DIR=%~1"
set "SETUP_LOG=%~2"

:: Validate parameters
if "%INSTALL_DIR%"=="" (
    echo [ERROR] Installation directory not provided
    echo Usage: %0 "InstallDir" "LogFile"
    pause
    exit /b 1
)

:: Set paths
set "LOG_DIR=%INSTALL_DIR%\logs"
set "TEMP_DIR=%INSTALL_DIR%\temp"

:: Create timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%"
set "INSTALL_LOG=%LOG_DIR%\installation_%TIMESTAMP%.log"

:: ============================================================================
:: INITIALIZATION
:: ============================================================================

echo.
echo ========================================================================
echo                    %APP_NAME%
echo                  Installation Starting
echo ========================================================================
echo.
echo Version: %SCRIPT_VERSION%
echo Install Directory: %INSTALL_DIR%
echo Log File: %INSTALL_LOG%
echo.

:: Ensure log directory exists
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul

:: Initialize log file
echo ======================================================================== > "%INSTALL_LOG%"
echo  %APP_NAME% - INSTALLATION STARTED >> "%INSTALL_LOG%"
echo  Version: %SCRIPT_VERSION% >> "%INSTALL_LOG%"
echo  Timestamp: %TIMESTAMP% >> "%INSTALL_LOG%"
echo  Install Directory: %INSTALL_DIR% >> "%INSTALL_LOG%"
echo ======================================================================== >> "%INSTALL_LOG%"
echo. >> "%INSTALL_LOG%"

:: ============================================================================
:: PHASE 1: CHECK ADMIN PRIVILEGES
:: ============================================================================

echo [PHASE 1] Checking administrator privileges...
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Administrator privileges required!
    echo [ERROR] Please run the installer as Administrator
    echo [ERROR] Administrator privileges required >> "%INSTALL_LOG%"
    pause
    exit /b 1
)
echo [OK] Administrator privileges confirmed
echo [OK] Administrator privileges confirmed >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: PHASE 2: PYTHON INSTALLATION
:: ============================================================================

echo [PHASE 2] Checking Python installation...
echo [PHASE 2] Checking Python installation... >> "%INSTALL_LOG%"

:: Try to find Python in PATH first
set "PYTHON_CMD="
where python.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%p in ('where python.exe') do (
        set "PYTHON_CMD=%%p"
        goto :PYTHON_FOUND
    )
)

:: Python not found, need to install
echo [INFO] Python not found, installing...
echo [INFO] Python not found, installing... >> "%INSTALL_LOG%"

echo [INFO] Attempting to install Python via winget...
winget install Python.Python.3.11 -e --silent --accept-source-agreements --accept-package-agreements >> "%INSTALL_LOG%" 2>&1

if !ERRORLEVEL! equ 0 (
    echo [OK] Python installed via winget
    echo [OK] Python installed via winget >> "%INSTALL_LOG%"
    
    :: Wait for PATH to update
    echo [INFO] Waiting for Python to be available in PATH...
    timeout /t 5 /nobreak >nul
    
    :: Refresh environment variables
    call :RefreshEnv
    
    :: Try to find Python again
    where python.exe >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        for /f "delims=" %%p in ('where python.exe') do (
            set "PYTHON_CMD=%%p"
            goto :PYTHON_FOUND
        )
    ) else (
        echo [ERROR] Python installed but not found in PATH
        echo [ERROR] Please restart the installer
        echo [ERROR] Python PATH issue >> "%INSTALL_LOG%"
        pause
        exit /b 20
    )
) else (
    echo [WARN] winget installation failed
    echo [WARN] winget installation failed >> "%INSTALL_LOG%"
    echo [WARN] Python must be installed manually
    echo [WARN] Download from: https://www.python.org/downloads/
    pause
    exit /b 21
)

:PYTHON_FOUND
echo [INFO] Python found at: %PYTHON_CMD%
echo [INFO] Python path: %PYTHON_CMD% >> "%INSTALL_LOG%"

"%PYTHON_CMD%" --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python found but cannot execute
    echo [ERROR] Python execution failed >> "%INSTALL_LOG%"
    pause
    exit /b 22
)

for /f "tokens=2" %%v in ('"%PYTHON_CMD%" --version 2^>^&1') do set "PY_VERSION=%%v"
echo [OK] Python %PY_VERSION% ready
echo [OK] Python %PY_VERSION% ready >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: PHASE 3: PIP VERIFICATION
:: ============================================================================

echo [PHASE 3] Verifying pip...
echo [PHASE 3] Verifying pip... >> "%INSTALL_LOG%"

"%PYTHON_CMD%" -m pip --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] pip not available, attempting to install...
    "%PYTHON_CMD%" -m ensurepip --default-pip >> "%INSTALL_LOG%" 2>&1
)
echo [OK] pip verified
echo [OK] pip verified >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: PHASE 4: PYTHON DEPENDENCIES
:: ============================================================================

echo [PHASE 4] Installing Python dependencies...
echo [PHASE 4] Installing Python dependencies... >> "%INSTALL_LOG%"

set "REQUIREMENTS_FILE=%INSTALL_DIR%\server\requirements.txt"

if not exist "%REQUIREMENTS_FILE%" (
    echo [ERROR] requirements.txt not found at: %REQUIREMENTS_FILE%
    echo [ERROR] requirements.txt not found >> "%INSTALL_LOG%"
    pause
    exit /b 30
)

echo [INFO] Upgrading pip...
"%PYTHON_CMD%" -m pip install --upgrade pip >> "%INSTALL_LOG%" 2>&1

echo [INFO] Installing dependencies (this may take a few minutes)...
"%PYTHON_CMD%" -m pip install -r "%REQUIREMENTS_FILE%" >> "%INSTALL_LOG%" 2>&1

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install Python dependencies
    echo [ERROR] Check log file: %INSTALL_LOG%
    echo [ERROR] Failed to install Python dependencies >> "%INSTALL_LOG%"
    pause
    exit /b 31
)

echo [OK] Python dependencies installed
echo [OK] Python dependencies installed >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: PHASE 5: OLLAMA INSTALLATION
:: ============================================================================

echo [PHASE 5] Checking Ollama installation...
echo [PHASE 5] Checking Ollama installation... >> "%INSTALL_LOG%"

:: Find Ollama
set "OLLAMA_CMD="
where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        goto :OLLAMA_FOUND
    )
)

:: Ollama not found, need to install
echo [INFO] Ollama not found, installing...
echo [INFO] Ollama not found, installing... >> "%INSTALL_LOG%"

set "OLLAMA_INSTALLER=%TEMP_DIR%\OllamaSetup.exe"

echo [INFO] Downloading Ollama installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '%OLLAMA_INSTALLER%'" >> "%INSTALL_LOG%" 2>&1

if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed to download Ollama
    echo [ERROR] Check internet connection
    echo [ERROR] Failed to download Ollama >> "%INSTALL_LOG%"
    pause
    exit /b 40
)

echo [INFO] Installing Ollama (this may take a minute)...
start /wait "" "%OLLAMA_INSTALLER%" /S

timeout /t 5 /nobreak >nul

:: Refresh environment
call :RefreshEnv

:: Try to find Ollama again
where ollama.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        goto :OLLAMA_FOUND
    )
) else (
    echo [ERROR] Ollama installation failed or not in PATH
    echo [ERROR] Ollama installation failed >> "%INSTALL_LOG%"
    pause
    exit /b 41
)

:OLLAMA_FOUND
echo [INFO] Ollama found at: %OLLAMA_CMD%
echo [INFO] Ollama path: %OLLAMA_CMD% >> "%INSTALL_LOG%"
echo [OK] Ollama ready
echo [OK] Ollama ready >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: PHASE 6: START OLLAMA SERVICE
:: ============================================================================

echo [PHASE 6] Starting Ollama service...
echo [PHASE 6] Starting Ollama service... >> "%INSTALL_LOG%"

start /b "" "%OLLAMA_CMD%" serve >> "%INSTALL_LOG%" 2>&1
timeout /t 3 /nobreak >nul

:: Wait for Ollama to be ready
echo [INFO] Waiting for Ollama to start...
set "WAIT_COUNT=0"
:WAIT_OLLAMA
curl -s http://localhost:11434/ >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Ollama service is running
    echo [OK] Ollama service is running >> "%INSTALL_LOG%"
    goto :OLLAMA_READY
)

set /a WAIT_COUNT+=1
if %WAIT_COUNT% geq 30 (
    echo [ERROR] Ollama service did not start
    echo [ERROR] Ollama service did not start >> "%INSTALL_LOG%"
    pause
    exit /b 42
)

timeout /t 1 /nobreak >nul
goto :WAIT_OLLAMA

:OLLAMA_READY
echo.

:: ============================================================================
:: PHASE 7: DOWNLOAD AI MODEL
:: ============================================================================

echo [PHASE 7] Downloading AI model (llama3.2:3b)...
echo [PHASE 7] Downloading AI model... >> "%INSTALL_LOG%"
echo.
echo [INFO] This is a ~2GB download and may take 5-10 minutes
echo [INFO] Please be patient...
echo.

"%OLLAMA_CMD%" list | findstr "llama3.2:3b" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Model already downloaded
    echo [OK] Model already downloaded >> "%INSTALL_LOG%"
) else (
    echo [INFO] Downloading model llama3.2:3b...
    "%OLLAMA_CMD%" pull llama3.2:3b
    
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Model download failed
        echo [ERROR] Check internet connection
        echo [ERROR] Model download failed >> "%INSTALL_LOG%"
        pause
        exit /b 50
    )
    
    echo [OK] Model downloaded successfully
    echo [OK] Model downloaded successfully >> "%INSTALL_LOG%"
)
echo.

:: ============================================================================
:: PHASE 8: FIREWALL CONFIGURATION
:: ============================================================================

echo [PHASE 8] Configuring Windows Firewall...
echo [PHASE 8] Configuring Windows Firewall... >> "%INSTALL_LOG%"

:: Remove existing rule if present
netsh advfirewall firewall delete rule name="TRAINING AI SERVER" >nul 2>&1

:: Add new rule
netsh advfirewall firewall add rule name="TRAINING AI SERVER" dir=in action=allow protocol=TCP localport=5000 profile=private >> "%INSTALL_LOG%" 2>&1

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to configure firewall
    echo [ERROR] Failed to configure firewall >> "%INSTALL_LOG%"
    pause
    exit /b 60
)

echo [OK] Firewall configured
echo [OK] Firewall configured >> "%INSTALL_LOG%"
echo.

:: ============================================================================
:: INSTALLATION COMPLETE
:: ============================================================================

echo ========================================================================
echo                  INSTALLATION COMPLETED SUCCESSFULLY!
echo ========================================================================
echo.
echo Installation Summary:
echo   - Python: %PY_VERSION% at %PYTHON_CMD%
echo   - Ollama: Installed at %OLLAMA_CMD%
echo   - AI Model: llama3.2:3b downloaded
echo   - Dependencies: Installed
echo   - Firewall: Configured
echo.
echo Log file: %INSTALL_LOG%
echo.
echo Next steps:
echo   1. Launch the server from the desktop shortcut
echo   2. Access at: http://localhost:5000
echo   3. Configure your Meta Quest 3
echo.

echo INSTALLATION_SUCCESS >> "%INSTALL_LOG%"
echo ======================================================================== >> "%INSTALL_LOG%"
echo  INSTALLATION COMPLETED >> "%INSTALL_LOG%"
echo  Time: %TIME% >> "%INSTALL_LOG%"
echo ======================================================================== >> "%INSTALL_LOG%"

echo.
echo Installation completed successfully!
echo Instalacion completada exitosamente!

exit /b 0

:: ============================================================================
:: HELPER FUNCTIONS
:: ============================================================================

:RefreshEnv
:: Refresh PATH from registry without restarting
echo [INFO] Refreshing environment variables...
for /f "skip=2 tokens=3*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path') do set "SysPath=%%a %%b"
for /f "skip=2 tokens=3*" %%a in ('reg query "HKCU\Environment" /v Path') do set "UserPath=%%a %%b"
set "PATH=%SysPath%;%UserPath%"
goto :eof
