@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

title TRAINING AI SERVER - Installation

set "INSTALL_DIR=%~1"
set "SETUP_LOG=%~2"

if "%INSTALL_DIR%"=="" (
    echo ERROR: Installation directory not provided
    pause
    exit /b 1
)

set "LOG_DIR=%INSTALL_DIR%\logs"
set "TEMP_DIR=%INSTALL_DIR%\temp"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" 2>nul
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul

echo.
echo ========================================================================
echo                    TRAINING AI SERVER v4.2
echo                 Bilingual Installation (ES/EN)
echo ========================================================================
echo.

echo [PHASE 1/9] Checking administrator privileges...
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Administrator privileges required!
    pause
    exit /b 1
)
echo [OK] Administrator privileges confirmed
echo.

echo [PHASE 2/9] Checking Python installation...
set "PYTHON_CMD="
where python.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%p in ('where python.exe') do (
        set "PYTHON_CMD=%%p"
        goto :PYTHON_FOUND
    )
)

echo [INFO] Python not found, installing...
echo [INFO] This may take 1-2 minutes...
winget install Python.Python.3.11 -e --silent --accept-source-agreements --accept-package-agreements

if !ERRORLEVEL! equ 0 (
    echo [OK] Python installed
    timeout /t 5 /nobreak >nul
    
    where python.exe >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        for /f "delims=" %%p in ('where python.exe') do (
            set "PYTHON_CMD=%%p"
            goto :PYTHON_FOUND
        )
    ) else (
        echo [ERROR] Python installed but not found in PATH
        pause
        exit /b 20
    )
) else (
    echo [ERROR] Python installation failed
    pause
    exit /b 21
)

:PYTHON_FOUND
echo [OK] Python ready
echo.

echo [PHASE 3/9] Installing Python dependencies...
echo [INFO] This may take 2-5 minutes depending on internet speed...
echo [INFO] Please wait while packages are downloaded and installed...
echo.

set "REQUIREMENTS_FILE=%INSTALL_DIR%\server\requirements.txt"

if not exist "%REQUIREMENTS_FILE%" (
    echo [ERROR] requirements.txt not found
    pause
    exit /b 30
)

echo   Step 1/2: Upgrading pip...
"%PYTHON_CMD%" -m pip install --upgrade pip
if %ERRORLEVEL% neq 0 (
    echo [WARN] Could not upgrade pip, continuing anyway...
)

echo.
echo   Step 2/2: Installing dependencies (Flask, ChromaDB, Ollama, etc.)...
echo   This is the longest step - please be patient...
echo.

"%PYTHON_CMD%" -m pip install -r "%REQUIREMENTS_FILE%"

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install dependencies
    echo [INFO] You can try installing manually with:
    echo        pip install -r "%REQUIREMENTS_FILE%"
    pause
    exit /b 31
)

echo.
echo [OK] Dependencies installed successfully
echo.

echo [PHASE 4/9] Checking Ollama installation...
set "OLLAMA_CMD="
where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        goto :OLLAMA_FOUND
    )
)

echo [INFO] Ollama not found, downloading installer...
set "OLLAMA_INSTALLER=%TEMP_DIR%\OllamaSetup.exe"

powershell -NoProfile -Command "Write-Host '  Downloading Ollama... (~100MB)'; Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '%OLLAMA_INSTALLER%'"

if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed to download Ollama
    pause
    exit /b 40
)

echo [INFO] Installing Ollama...
start /wait "" "%OLLAMA_INSTALLER%" /S
timeout /t 5 /nobreak >nul

where ollama.exe >nul 2>&1
if !ERRORLEVEL! equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        goto :OLLAMA_FOUND
    )
) else (
    echo [ERROR] Ollama installation failed
    pause
    exit /b 41
)

:OLLAMA_FOUND
echo [OK] Ollama ready
echo.

echo [PHASE 5/9] Starting Ollama service...
set "OLLAMA_STARTED_HERE=0"
"%OLLAMA_CMD%" list >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Ollama service already running
) else (
    set "OLLAMA_STARTED_HERE=1"
    start /b "" "%OLLAMA_CMD%" serve
    echo [INFO] Waiting for Ollama to be ready...
    set "OLLAMA_READY=0"
    for /L %%i in (1,1,20) do (
        if "!OLLAMA_READY!"=="0" (
            timeout /t 2 /nobreak >nul
            "%OLLAMA_CMD%" list >nul 2>&1
            if !ERRORLEVEL! equ 0 set "OLLAMA_READY=1"
        )
    )
    if "!OLLAMA_READY!"=="0" (
        echo [ERROR] Ollama service did not respond after 40 seconds
        pause
        exit /b 40
    )
    echo [OK] Ollama service ready
)
echo.

echo [PHASE 6/9] Downloading default AI model (qwen2.5:7b)...
echo [INFO] This is a ~4.7GB download, please wait...
echo [INFO] Progress will be shown below:
echo.

"%OLLAMA_CMD%" list | findstr "qwen2.5:7b" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Default model already downloaded
) else (
    "%OLLAMA_CMD%" pull qwen2.5:7b
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Model download failed
        pause
        exit /b 50
    )
    echo [OK] Default model downloaded
)
echo.

echo [PHASE 7/9] Optional model installation...
echo.
echo You can install additional models now:
echo   1. qwen2.5:3b (1.9GB) - Balanced (lighter than default 7b)
echo   2. llama3.2:1b (1.3GB) - Ultra-fast
echo   3. llama3.2:3b (2.0GB) - Legacy
echo.
echo Note: You can always download more models later from the launcher
echo.

set /p "INSTALL_MODEL_1=Install qwen2.5:3b? (Y/N): "
if /i "%INSTALL_MODEL_1%"=="Y" (
    echo Downloading qwen2.5:3b...
    "%OLLAMA_CMD%" pull qwen2.5:3b
    echo.
)

set /p "INSTALL_MODEL_2=Install llama3.2:1b? (Y/N): "
if /i "%INSTALL_MODEL_2%"=="Y" (
    echo Downloading llama3.2:1b...
    "%OLLAMA_CMD%" pull llama3.2:1b
    echo.
) 

echo [PHASE 8/9] Configuring firewall & security...
if exist "%INSTALL_DIR%\installer\configure_security.bat" (
    call "%INSTALL_DIR%\installer\configure_security.bat" "%INSTALL_DIR%"
) else (
    echo [WARN] Security configuration script not found!
    echo [WARN] Falling back to basic firewall rule...
    netsh advfirewall firewall add rule name="TRAINING AI SERVER" dir=in action=allow protocol=TCP localport=5000-5010 profile=any >nul 2>&1
)
echo [OK] Security configured
echo.

echo [PHASE 9/9] Creating configuration...
set "CONFIG_FILE=%INSTALL_DIR%\server\server_config.json"
(
    echo {
    echo   "current_model": "qwen2.5:7b",
    echo   "bilingual_mode": true,
    echo   "supported_languages": ["es", "en"]
    echo }
) > "%CONFIG_FILE%"
echo [OK] Configuration created
echo.

echo ========================================================================
echo              INSTALLATION COMPLETED SUCCESSFULLY!
echo ========================================================================
echo.
echo Installation completed! / Instalacion completada!
echo.
echo The launcher will start automatically in a few seconds...
echo El launcher se iniciara automaticamente en unos segundos...
echo.
echo If it doesn't start, you can run it manually from the Start Menu
echo Si no inicia, puede ejecutarlo manualmente desde el Menu Inicio
echo.

:: Stop the Ollama instance we started during install so the window closes cleanly.
:: The server launcher will start its own Ollama when the user runs the app.
if "!OLLAMA_STARTED_HERE!"=="1" (
    taskkill /F /IM ollama.exe >nul 2>&1
)

exit /b 0
