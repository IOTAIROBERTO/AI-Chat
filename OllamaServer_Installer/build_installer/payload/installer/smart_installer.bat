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
echo                    TRAINING AI SERVER v4.1
echo                 Bilingual Installation (ES/EN)
echo ========================================================================
echo.

echo [PHASE 1] Checking administrator privileges...
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Administrator privileges required!
    pause
    exit /b 1
)
echo [OK] Administrator privileges confirmed
echo.

echo [PHASE 2] Checking Python installation...
set "PYTHON_CMD="
where python.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%p in ('where python.exe') do (
        set "PYTHON_CMD=%%p"
        goto :PYTHON_FOUND
    )
)

echo [INFO] Python not found, installing...
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

echo [PHASE 3] Installing Python dependencies...
set "REQUIREMENTS_FILE=%INSTALL_DIR%\server\requirements.txt"

if not exist "%REQUIREMENTS_FILE%" (
    echo [ERROR] requirements.txt not found
    pause
    exit /b 30
)

"%PYTHON_CMD%" -m pip install --upgrade pip >nul 2>&1
"%PYTHON_CMD%" -m pip install -r "%REQUIREMENTS_FILE%" >nul 2>&1

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 31
)
echo [OK] Dependencies installed
echo.

echo [PHASE 4] Checking Ollama installation...
set "OLLAMA_CMD="
where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%o in ('where ollama.exe') do (
        set "OLLAMA_CMD=%%o"
        goto :OLLAMA_FOUND
    )
)

echo [INFO] Ollama not found, installing...
set "OLLAMA_INSTALLER=%TEMP_DIR%\OllamaSetup.exe"

powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://ollama.com/download/OllamaSetup.exe' -OutFile '%OLLAMA_INSTALLER%'"

if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed to download Ollama
    pause
    exit /b 40
)

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

echo [PHASE 5] Starting Ollama service...
start /b "" "%OLLAMA_CMD%" serve
timeout /t 3 /nobreak >nul

echo [PHASE 6] Downloading default AI model (qwen2.5:1.5b)...
echo [INFO] This is a 1GB download, please wait...
echo.

"%OLLAMA_CMD%" list | findstr "qwen2.5:1.5b" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Default model already downloaded
) else (
    "%OLLAMA_CMD%" pull qwen2.5:1.5b
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Model download failed
        pause
        exit /b 50
    )
    echo [OK] Default model downloaded
)
echo.

echo [PHASE 7] Model selection (optional)...
echo.
echo You can install additional models:
echo   1. qwen2.5:3b (1.9GB) - Best quality
echo   2. llama3.2:1b (1.3GB) - Ultra-fast
echo   3. llama3.2:3b (2.0GB) - Legacy
echo.

set /p "INSTALL_MODEL_1=Install qwen2.5:3b? (Y/N): "
if /i "%INSTALL_MODEL_1%"=="Y" (
    echo Downloading qwen2.5:3b...
    "%OLLAMA_CMD%" pull qwen2.5:3b
)

set /p "INSTALL_MODEL_2=Install llama3.2:1b? (Y/N): "
if /i "%INSTALL_MODEL_2%"=="Y" (
    echo Downloading llama3.2:1b...
    "%OLLAMA_CMD%" pull llama3.2:1b
)

set /p "INSTALL_MODEL_3=Install llama3.2:3b? (Y/N): "
if /i "%INSTALL_MODEL_3%"=="Y" (
    echo Downloading llama3.2:3b...
    "%OLLAMA_CMD%" pull llama3.2:3b
)

echo.
echo [PHASE 8] Configuring firewall...
netsh advfirewall firewall delete rule name="TRAINING AI SERVER" >nul 2>&1
netsh advfirewall firewall add rule name="TRAINING AI SERVER" dir=in action=allow protocol=TCP localport=5000 profile=private >nul 2>&1
echo [OK] Firewall configured
echo.

echo [PHASE 9] Creating configuration...
set "CONFIG_FILE=%INSTALL_DIR%\server\server_config.json"
(
    echo {
    echo   "current_model": "qwen2.5:1.5b",
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
echo Installation completed!
echo Instalacion completada!
echo.
pause

exit /b 0