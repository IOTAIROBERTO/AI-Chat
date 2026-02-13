@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: VR TRAINING AI SERVER - Connection Diagnostic Tool
:: ============================================================================

set "LOG_FILE=%~dp0diagnostic_report.txt"
echo Generating diagnostic report... > "%LOG_FILE%"
echo Date: %DATE% %TIME% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo 1. SYSTEM INFO >> "%LOG_FILE%"
echo -------------- >> "%LOG_FILE%"
hostname >> "%LOG_FILE%"
systeminfo | findstr /B /C:"OS Name" /C:"OS Version" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo 2. NETWORK PROFILES >> "%LOG_FILE%"
echo ------------------- >> "%LOG_FILE%"
netsh advfirewall show allprofiles state >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo 3. FIREWALL RULES >> "%LOG_FILE%"
echo ----------------- >> "%LOG_FILE%"
netsh advfirewall firewall show rule name="TRAINING AI SERVER (Ports)" >> "%LOG_FILE%"
netsh advfirewall firewall show rule name="TRAINING AI SERVER (Python)" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo 4. PORT USAGE (5000-5010) >> "%LOG_FILE%"
echo ------------------------- >> "%LOG_FILE%"
netstat -ano | findstr ":500" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo 5. OLLAMA STATUS >> "%LOG_FILE%"
echo ---------------- >> "%LOG_FILE%"
tasklist | findstr "ollama" >> "%LOG_FILE%"
if %ERRORLEVEL% equ 0 (
    echo Ollama is running. >> "%LOG_FILE%"
    curl -s http://localhost:11434/api/version >> "%LOG_FILE%"
) else (
    echo [ERROR] Ollama NOT running. >> "%LOG_FILE%"
)
echo. >> "%LOG_FILE%"

echo 6. SERVER LOGS (Last 20 lines) >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
:: Try multiple locations for logs
if exist "..\logs\server_console.log" (
    powershell -Command "Get-Content '..\logs\server_console.log' -Tail 20" >> "%LOG_FILE%"
) else if exist "..\..\logs\server_console.log" (
    # Check if run from a subdir of installer
    powershell -Command "Get-Content '..\..\logs\server_console.log' -Tail 20" >> "%LOG_FILE%"
) else if exist "logs\server_console.log" (
    # Check if run from root
    powershell -Command "Get-Content 'logs\server_console.log' -Tail 20" >> "%LOG_FILE%"
) else (
    echo Log file not found in expected locations. >> "%LOG_FILE%"
)

echo.
echo ========================================================
echo Diagnostic report saved to:
echo %LOG_FILE%
echo ========================================================
pause
