@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================================
:: TRAINING AI SERVER v5.0 - Silent Installer
:: All output is automatically redirected to the install log.
:: No CMD windows appear during installation.
:: ============================================================================

:: --- Self-logging bootstrap ---
:: On first run (no SELF_LOGGING env var), re-execute this script with all
:: output redirected to the log file, then exit. This hides all console output.
if not defined SELF_LOGGING (
    set "SELF_LOGGING=1"
    if not exist "%~1\logs" mkdir "%~1\logs" 2>nul
    cmd /c "%~f0" %* >> "%~1\logs\install.log" 2>&1
    exit /b %ERRORLEVEL%
)

:: From here, all output goes to %INSTALL_DIR%\logs\install.log

set "INSTALL_DIR=%~1"
set "SETUP_LOG=%~2"
set "MODELS_CFG=%~3"

if "%INSTALL_DIR%"=="" (
    echo [ERROR] No installation directory supplied to smart_installer.bat
    exit /b 1
)

set "LOG_DIR=%INSTALL_DIR%\logs"
set "TEMP_DIR=%INSTALL_DIR%\temp"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul

echo.
echo ========================================================================
echo   TRAINING AI SERVER v5.0 - Installation Engine
echo   %DATE%  %TIME%
echo ========================================================================
echo.

:: ============================================================================
:: PHASE 1/9 - Administrator privilege check
:: ============================================================================
echo [PHASE 1/9] Checking administrator privileges...
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Not running as administrator. Aborting.
    exit /b 1
)
echo [OK] Running as administrator
echo.

:: ============================================================================
:: PHASE 2/9 - Python 3.11+ installation
:: ============================================================================
echo [PHASE 2/9] Locating Python 3.11+...
set "PYTHON_CMD="

:: Check if python already exists AND version is >= 3.11
python --version >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "tokens=2 delims=." %%v in ('python --version 2^>^&1') do set "PY_MINOR=%%v"
    if !PY_MINOR! geq 11 (
        for /f "delims=" %%p in ('where python.exe 2^>nul') do (
            set "PYTHON_CMD=%%p"
            echo [OK] Found compatible Python in PATH: !PYTHON_CMD!
            goto :PYTHON_FOUND
        )
    ) else (
        echo [WARN] Python found but version too old (minor=!PY_MINOR!), need 3.11+
    )
)

:: Scan common install paths before downloading
for %%p in (
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "C:\Python313\python.exe"
    "C:\Python312\python.exe"
    "C:\Python311\python.exe"
) do (
    if exist %%p (
        set "PYTHON_CMD=%%~p"
        echo [OK] Found Python at: !PYTHON_CMD!
        goto :PYTHON_FOUND
    )
)

:: Attempt 1: winget (Windows 10 2004+)
echo [INFO] Python 3.11+ not found. Attempting winget install...
winget install Python.Python.3.11 -e --silent --accept-source-agreements --accept-package-agreements >nul 2>&1
if !ERRORLEVEL! equ 0 (
    echo [INFO] winget install complete. Refreshing PATH...
    call :REFRESH_PATH
    timeout /t 6 /nobreak >nul
    for /f "delims=" %%p in ('where python.exe 2^>nul') do (
        set "PYTHON_CMD=%%p"
        echo [OK] Python ready via winget: !PYTHON_CMD!
        goto :PYTHON_FOUND
    )
    echo [WARN] winget reported success but python.exe not in PATH - scanning paths...
    for %%p in (
        "%LocalAppData%\Programs\Python\Python311\python.exe"
        "C:\Python311\python.exe"
    ) do (
        if exist %%p (
            set "PYTHON_CMD=%%~p"
            echo [OK] Found at: !PYTHON_CMD!
            goto :PYTHON_FOUND
        )
    )
)

:: Attempt 2: Direct MSI download from python.org
echo [WARN] winget failed. Downloading Python 3.11.9 installer directly...
set "PY_MSI=%TEMP_DIR%\python-3.11.9-amd64.exe"
call :DOWNLOAD_WITH_RETRY "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" "%PY_MSI%" 3
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Cannot download Python installer. Check internet connection.
    exit /b 21
)

echo [INFO] Running Python 3.11.9 silent installer...
"%PY_MSI%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_doc=0 Include_launcher=0
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Python silent installer failed (exit code !ERRORLEVEL!)
    exit /b 22
)

call :REFRESH_PATH
timeout /t 6 /nobreak >nul

for /f "delims=" %%p in ('where python.exe 2^>nul') do (
    set "PYTHON_CMD=%%p"
    echo [OK] Python installed and found: !PYTHON_CMD!
    goto :PYTHON_FOUND
)
:: Final path scan after install
for %%p in (
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "C:\Python311\python.exe"
) do (
    if exist %%p (
        set "PYTHON_CMD=%%~p"
        goto :PYTHON_FOUND
    )
)

echo [ERROR] Python installation completed but executable cannot be located.
exit /b 23

:PYTHON_FOUND
echo [OK] Python executable confirmed: %PYTHON_CMD%
echo.

:: ============================================================================
:: PHASE 3/9 - Python dependencies
:: ============================================================================
echo [PHASE 3/9] Installing Python dependencies...
echo [INFO] This step takes 3-8 minutes. Downloading Flask, ChromaDB, Whisper...

set "REQUIREMENTS_FILE=%INSTALL_DIR%\server\requirements.txt"
if not exist "%REQUIREMENTS_FILE%" (
    echo [ERROR] requirements.txt not found: %REQUIREMENTS_FILE%
    exit /b 30
)

echo [INFO] Upgrading pip...
"%PYTHON_CMD%" -m pip install --upgrade pip --quiet 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] pip upgrade failed - continuing with current version
)

:: faster-whisper pins av<13 in its metadata, but av<13 has no Python 3.13 wheel.
:: Fix: install av>=13 first, then install faster-whisper bypassing its av constraint.
echo [INFO] Installing av (Python 3.13 compatible wheel)...
"%PYTHON_CMD%" -m pip install "av>=13.0.0" --quiet 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install av. Check internet connection.
    exit /b 30
)

echo [INFO] Installing faster-whisper (no-deps to keep av>=13)...
"%PYTHON_CMD%" -m pip install "faster-whisper==1.1.1" --no-deps --quiet 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install faster-whisper.
    exit /b 30
)

echo [INFO] Installing faster-whisper runtime deps...
"%PYTHON_CMD%" -m pip install "ctranslate2>=4.0,<5" "huggingface_hub>=0.13" "tokenizers" --quiet 2>&1

echo [INFO] Installing remaining packages from requirements.txt...
"%PYTHON_CMD%" -m pip install -r "%REQUIREMENTS_FILE%" --quiet 2>&1
if %ERRORLEVEL% neq 0 (
    echo [WARN] First attempt failed. Retrying without cache...
    "%PYTHON_CMD%" -m pip install -r "%REQUIREMENTS_FILE%" --no-cache-dir --quiet 2>&1
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Failed to install Python dependencies after two attempts.
        echo [INFO] See log: %LOG_DIR%\install.log
        exit /b 31
    )
)

echo [OK] Python dependencies installed
echo.

:: ============================================================================
:: PHASE 4/9 - Ollama installation
:: ============================================================================
echo [PHASE 4/9] Checking Ollama...
set "OLLAMA_CMD="

where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        echo [OK] Ollama already installed: !OLLAMA_CMD!
        goto :OLLAMA_FOUND
    )
)

echo [INFO] Ollama not found. Downloading installer (~100MB)...
set "OLLAMA_INSTALLER=%TEMP_DIR%\OllamaSetup.exe"
call :DOWNLOAD_WITH_RETRY "https://ollama.com/download/OllamaSetup.exe" "%OLLAMA_INSTALLER%" 3
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to download Ollama installer after 3 attempts.
    exit /b 40
)

echo [INFO] Running Ollama silent installer...
start /wait "" "%OLLAMA_INSTALLER%" /S
timeout /t 10 /nobreak >nul

call :REFRESH_PATH

where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        echo [OK] Ollama installed: !OLLAMA_CMD!
        goto :OLLAMA_FOUND
    )
)

:: Ollama typically installs to LocalAppData
if exist "%LocalAppData%\Programs\Ollama\ollama.exe" (
    set "OLLAMA_CMD=%LocalAppData%\Programs\Ollama\ollama.exe"
    echo [OK] Ollama found at default path: !OLLAMA_CMD!
    goto :OLLAMA_FOUND
)

echo [ERROR] Ollama installation failed - executable not found after install.
exit /b 41

:OLLAMA_FOUND
echo [OK] Ollama confirmed: %OLLAMA_CMD%
echo.

:: ============================================================================
:: PHASE 5/9 - Start Ollama service
:: ============================================================================
echo [PHASE 5/9] Starting Ollama service...
set "OLLAMA_STARTED_HERE=0"

"%OLLAMA_CMD%" list >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Ollama service already running
) else (
    set "OLLAMA_STARTED_HERE=1"
    echo [INFO] Starting Ollama service...
    start /b "" "%OLLAMA_CMD%" serve
    echo [INFO] Waiting for Ollama to be ready (up to 40s)...
    set "OLLAMA_READY=0"
    for /L %%i in (1,1,20) do (
        if "!OLLAMA_READY!"=="0" (
            timeout /t 2 /nobreak >nul
            "%OLLAMA_CMD%" list >nul 2>&1
            if !ERRORLEVEL! equ 0 set "OLLAMA_READY=1"
        )
    )
    if "!OLLAMA_READY!"=="0" (
        echo [ERROR] Ollama service did not become ready within 40 seconds.
        exit /b 42
    )
    echo [OK] Ollama service is ready
)
echo.

:: ============================================================================
:: PHASE 6/9 - Download AI models (driven by GUI selection)
:: ============================================================================
echo [PHASE 6/9] Downloading AI models...

:: Always install the base model
set "BASE_MODEL=qwen3:1.7b"
echo [INFO] Checking base model: %BASE_MODEL%
"%OLLAMA_CMD%" list 2>nul | findstr /l "%BASE_MODEL%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] %BASE_MODEL% already installed
) else (
    echo [INFO] Downloading %BASE_MODEL% (~1.1 GB) - please wait, this may take several minutes...
    "%OLLAMA_CMD%" pull %BASE_MODEL%
    if !ERRORLEVEL! neq 0 (
        echo [WARN] First attempt failed. Retrying in 10 seconds...
        timeout /t 10 /nobreak >nul
        "%OLLAMA_CMD%" pull %BASE_MODEL%
        if !ERRORLEVEL! neq 0 (
            echo [ERROR] Failed to download base model %BASE_MODEL% after 2 attempts.
            echo [ERROR] Check internet connection and try reinstalling.
            exit /b 50
        )
    )
    echo [OK] %BASE_MODEL% downloaded successfully
)
echo.

:: Download additional models selected in the GUI (read from config file)
if exist "%MODELS_CFG%" (
    echo [INFO] Reading optional model selections from installer...
    for /f "usebackq delims=" %%m in ("%MODELS_CFG%") do (
        set "OPT_MODEL=%%m"
        :: Trim spaces
        set "OPT_MODEL=!OPT_MODEL: =!"
        :: Skip blank lines and the base model (already installed)
        if not "!OPT_MODEL!"=="" if not "!OPT_MODEL!"=="%BASE_MODEL%" (
            echo [INFO] Checking optional model: !OPT_MODEL!
            "%OLLAMA_CMD%" list 2>nul | findstr /l "!OPT_MODEL!" >nul 2>&1
            if !ERRORLEVEL! equ 0 (
                echo [OK] !OPT_MODEL! already installed
            ) else (
                echo [INFO] Downloading !OPT_MODEL! - please wait...
                "%OLLAMA_CMD%" pull !OPT_MODEL!
                if !ERRORLEVEL! neq 0 (
                    echo [WARN] Could not download !OPT_MODEL! - skipping.
                    echo [INFO] You can download it later from the launcher.
                ) else (
                    echo [OK] !OPT_MODEL! downloaded successfully
                )
            )
            echo.
        )
    )
) else (
    echo [INFO] No model config found - only base model installed.
)

:: ============================================================================
:: PHASE 7/9 - Determine best installed model for server config
:: ============================================================================
echo [PHASE 7/9] Determining optimal default model...
set "DEFAULT_MODEL=%BASE_MODEL%"

:: phi4-mini is the preferred default Q&A model — check it first
:: If not installed, fall back by quality order (last found wins)
"%OLLAMA_CMD%" list 2>nul | findstr /l "phi4-mini" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    set "DEFAULT_MODEL=phi4-mini"
) else (
    for %%m in ("qwen3:4b" "qwen3:8b" "gemma3:4b") do (
        "%OLLAMA_CMD%" list 2>nul | findstr /l %%m >nul 2>&1
        if !ERRORLEVEL! equ 0 set "DEFAULT_MODEL=%%~m"
    )
)

echo [OK] Default model set to: %DEFAULT_MODEL%
echo.

:: ============================================================================
:: PHASE 8/9 - Firewall and security
:: ============================================================================
echo [PHASE 8/9] Configuring firewall and security...

if exist "%INSTALL_DIR%\installer\configure_security.bat" (
    call "%INSTALL_DIR%\installer\configure_security.bat" "%INSTALL_DIR%"
) else (
    echo [WARN] configure_security.bat not found. Applying minimal firewall rule...
    netsh advfirewall firewall add rule name="TRAINING AI SERVER" ^
        dir=in action=allow protocol=TCP localport=5000-5010 profile=any >nul 2>&1
)

:: Add Defender exclusion for the install directory (speeds up ChromaDB/Whisper)
powershell -NoProfile -Command ^
    "try { Add-MpPreference -ExclusionPath '%INSTALL_DIR%' -ErrorAction Stop } catch {}" >nul 2>&1

echo [OK] Security configured
echo.

:: ============================================================================
:: PHASE 9/9 - Create server configuration
:: ============================================================================
echo [PHASE 9/9] Writing server configuration...
set "CONFIG_FILE=%INSTALL_DIR%\server\server_config.json"

(
    echo {
    echo   "current_model": "%DEFAULT_MODEL%",
    echo   "bilingual_mode": true,
    echo   "primary_language": "es",
    echo   "supported_languages": ["es", "en"]
    echo }
) > "%CONFIG_FILE%"

echo [OK] server_config.json created (default model: %DEFAULT_MODEL%)
echo.

:: Stop the Ollama instance we started during install.
:: The launcher will start its own Ollama on demand.
if "!OLLAMA_STARTED_HERE!"=="1" (
    echo [INFO] Stopping temporary Ollama service...
    taskkill /F /IM ollama.exe >nul 2>&1
)

echo.
echo ========================================================================
echo   INSTALLATION COMPLETE
echo   %DATE%  %TIME%
echo   Default model : %DEFAULT_MODEL%
echo   Install path  : %INSTALL_DIR%
echo   Log file      : %LOG_DIR%\install.log
echo ========================================================================
echo.

exit /b 0

:: ============================================================================
:: SUBROUTINES
:: ============================================================================

:DOWNLOAD_WITH_RETRY
:: Usage: call :DOWNLOAD_WITH_RETRY "URL" "OutputPath" MaxRetries
set "_DL_URL=%~1"
set "_DL_OUT=%~2"
set "_DL_MAX=%~3"
if "%_DL_MAX%"=="" set "_DL_MAX=3"
set "_DL_ATTEMPT=0"

:_DL_LOOP
set /a _DL_ATTEMPT+=1
echo [INFO] Download attempt %_DL_ATTEMPT%/%_DL_MAX%: %_DL_URL%
powershell -NoProfile -Command ^
    "Invoke-WebRequest -Uri '%_DL_URL%' -OutFile '%_DL_OUT%' -UseBasicParsing -TimeoutSec 300" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    if exist "%_DL_OUT%" exit /b 0
)
if %_DL_ATTEMPT% lss %_DL_MAX% (
    echo [WARN] Download failed. Retrying in 5 seconds...
    timeout /t 5 /nobreak >nul
    goto :_DL_LOOP
)
echo [ERROR] Download failed after %_DL_MAX% attempts: %_DL_URL%
exit /b 1

:REFRESH_PATH
:: Reload PATH from registry so newly installed tools are found immediately
for /f "skip=2 tokens=3*" %%a in (
    'reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul'
) do set "_SYS_PATH=%%a %%b"
for /f "skip=2 tokens=3*" %%a in (
    'reg query "HKCU\Environment" /v Path 2^>nul'
) do set "_USR_PATH=%%a %%b"
set "PATH=!_SYS_PATH!;!_USR_PATH!"
exit /b 0
