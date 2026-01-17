@echo off
:: ============================================================================
:: TRAINING AI SERVER - Installer Library Functions
:: Version: 3.0
:: Description: Reusable functions for installation scripts
:: ============================================================================

:: ============================================================================
:: COLOR AND UI FUNCTIONS
:: ============================================================================

:PRINT_BANNER
echo.
echo ========================================================================
echo                    TRAINING AI SERVER v3.0
echo                   Production Installation System
echo ========================================================================
echo.
exit /b 0

:PRINT_SECTION
echo.
echo ------------------------------------------------------------------------
echo  %~1
echo ------------------------------------------------------------------------
exit /b 0

:PRINT_SUCCESS
echo [√] %~1
exit /b 0

:PRINT_ERROR
echo [X] ERROR: %~1
exit /b 0

:PRINT_WARN
echo [!] WARNING: %~1
exit /b 0

:PRINT_INFO
echo [i] %~1
exit /b 0

:: ============================================================================
:: SYSTEM VALIDATION FUNCTIONS
:: ============================================================================

:VALIDATE_ADMIN
:: Check for administrator privileges
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :PRINT_ERROR "Administrator privileges required"
    echo.
    echo Please right-click this script and select "Run as Administrator"
    pause
    exit /b 1
)
exit /b 0

:VALIDATE_WINDOWS_VERSION
:: Check Windows version (Win10 build 19041+ or Win11)
for /f "tokens=4-5 delims=. " %%i in ('ver') do (
    set "WIN_BUILD=%%i"
)
if %WIN_BUILD% lss 19041 (
    call :PRINT_ERROR "Windows 10 build 19041 or newer required"
    exit /b 1
)
exit /b 0

:VALIDATE_ARCHITECTURE
:: Ensure 64-bit Windows
if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    call :PRINT_ERROR "64-bit Windows required"
    exit /b 1
)
exit /b 0

:VALIDATE_DISK_SPACE
:: Validate minimum disk space (parameter: GB required)
set "REQUIRED_GB=%~1"
set "DRIVE=%~2"
if "%DRIVE%"=="" set "DRIVE=%SystemDrive%"

for /f "tokens=3" %%a in ('dir /-c "%DRIVE%\" ^| find "bytes free"') do (
    set "FREE_BYTES=%%a"
)
set /a "FREE_GB=%FREE_BYTES:~0,-9%"

if %FREE_GB% lss %REQUIRED_GB% (
    call :PRINT_ERROR "Insufficient disk space. Required: %REQUIRED_GB%GB, Available: %FREE_GB%GB"
    exit /b 1
)
exit /b 0

:VALIDATE_MEMORY
:: Validate minimum RAM (parameter: GB required)
set "REQUIRED_GB=%~1"

for /f "skip=1 tokens=2 delims==" %%a in ('wmic computersystem get TotalPhysicalMemory /value') do (
    set "TOTAL_MEMORY=%%a"
)
set /a "TOTAL_GB=%TOTAL_MEMORY:~0,-9%"

if %TOTAL_GB% lss %REQUIRED_GB% (
    call :PRINT_WARN "Low RAM detected. Recommended: %REQUIRED_GB%GB, Available: %TOTAL_GB%GB"
    exit /b 1
)
exit /b 0

:: ============================================================================
:: NETWORK VALIDATION FUNCTIONS
:: ============================================================================

:CHECK_INTERNET_CONNECTION
:: Check if internet is available
ping -n 1 8.8.8.8 >nul 2>&1
if %ERRORLEVEL% neq 0 (
    call :PRINT_WARN "No internet connection detected"
    exit /b 1
)
exit /b 0

:VALIDATE_PORT_AVAILABLE
:: Check if port is available (parameter: port number)
set "PORT=%~1"
netstat -ano | findstr ":%PORT% " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    call :PRINT_ERROR "Port %PORT% is already in use"
    exit /b 1
)
exit /b 0

:: ============================================================================
:: DEPENDENCY CHECK FUNCTIONS
:: ============================================================================

:CHECK_DEPENDENCY_PYTHON
:: Check if Python 3.11+ is installed
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    exit /b 1
)

:: Extract version number
for /f "tokens=2 delims=." %%v in ('python --version 2^>^&1') do (
    set "PY_MINOR=%%v"
)

:: Check if version >= 3.11
if %PY_MINOR% lss 11 (
    exit /b 1
)
exit /b 0

:CHECK_DEPENDENCY_OLLAMA
:: Check if Ollama is installed
where ollama >nul 2>&1
exit /b %ERRORLEVEL%

:CHECK_DEPENDENCY_CURL
:: Check if curl is available
where curl >nul 2>&1
exit /b %ERRORLEVEL%

:CHECK_DEPENDENCY_POWERSHELL
:: Check if PowerShell is available
where powershell >nul 2>&1
exit /b %ERRORLEVEL%

:: ============================================================================
:: DOWNLOAD AND INSTALL FUNCTIONS
:: ============================================================================

:DOWNLOAD_FILE
:: Download file with retry (params: URL, output_path, max_retries)
set "URL=%~1"
set "OUTPUT=%~2"
set "MAX_RETRIES=%~3"
if "%MAX_RETRIES%"=="" set "MAX_RETRIES=3"

set "RETRY=0"
:DOWNLOAD_RETRY
set /a RETRY+=1

powershell -NoProfile -Command ^
    "Invoke-WebRequest -Uri '%URL%' -OutFile '%OUTPUT%' -UseBasicParsing" >nul 2>&1

if %ERRORLEVEL% equ 0 (
    exit /b 0
)

if %RETRY% lss %MAX_RETRIES% (
    timeout /t 2 /nobreak >nul
    goto :DOWNLOAD_RETRY
)

exit /b 1

:VERIFY_FILE_HASH
:: Verify file SHA256 hash (params: file_path, expected_hash)
set "FILE=%~1"
set "EXPECTED_HASH=%~2"

if not exist "%FILE%" (
    exit /b 1
)

for /f "skip=1 tokens=1" %%h in ('certutil -hashfile "%FILE%" SHA256') do (
    set "ACTUAL_HASH=%%h"
    goto :HASH_COMPARE
)

:HASH_COMPARE
if /i "%ACTUAL_HASH%"=="%EXPECTED_HASH%" (
    exit /b 0
)
exit /b 1

:: ============================================================================
:: SERVICE MANAGEMENT FUNCTIONS
:: ============================================================================

:STOP_SERVICE_GRACEFULLY
:: Stop service with timeout (params: service_name, timeout_seconds)
set "SERVICE=%~1"
set "TIMEOUT=%~2"
if "%TIMEOUT%"=="" set "TIMEOUT=30"

:: Try graceful stop first
sc stop "%SERVICE%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    exit /b 1
)

:: Wait for service to stop
set "ELAPSED=0"
:WAIT_SERVICE_STOP
sc query "%SERVICE%" | findstr "STOPPED" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    exit /b 0
)

timeout /t 1 /nobreak >nul
set /a ELAPSED+=1

if %ELAPSED% geq %TIMEOUT% (
    :: Force stop if timeout
    sc stop "%SERVICE%" /f >nul 2>&1
    exit /b 1
)
goto :WAIT_SERVICE_STOP

:KILL_PROCESS_BY_NAME
:: Kill process by name with grace period (params: process_name, wait_seconds)
set "PROCESS=%~1"
set "WAIT=%~2"
if "%WAIT%"=="" set "WAIT=5"

:: Check if process exists
tasklist | findstr /I "%PROCESS%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    exit /b 0
)

:: Try graceful termination first
taskkill /IM "%PROCESS%" >nul 2>&1
timeout /t %WAIT% /nobreak >nul

:: Check if still running
tasklist | findstr /I "%PROCESS%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    exit /b 0
)

:: Force kill
taskkill /F /IM "%PROCESS%" /T >nul 2>&1
exit /b %ERRORLEVEL%

:: ============================================================================
:: REGISTRY FUNCTIONS
:: ============================================================================

:SET_REGISTRY_VALUE
:: Set registry value (params: key_path, value_name, value_type, value_data)
set "KEY=%~1"
set "NAME=%~2"
set "TYPE=%~3"
set "DATA=%~4"

reg add "%KEY%" /v "%NAME%" /t %TYPE% /d "%DATA%" /f >nul 2>&1
exit /b %ERRORLEVEL%

:GET_REGISTRY_VALUE
:: Get registry value (params: key_path, value_name, output_var)
set "KEY=%~1"
set "NAME=%~2"

for /f "skip=2 tokens=1,*" %%a in ('reg query "%KEY%" /v "%NAME%" 2^>nul') do (
    set "%~3=%%b"
    exit /b 0
)
exit /b 1

:DELETE_REGISTRY_KEY
:: Delete registry key (params: key_path)
set "KEY=%~1"
reg delete "%KEY%" /f >nul 2>&1
exit /b %ERRORLEVEL%

:: ============================================================================
:: FILE SYSTEM FUNCTIONS
:: ============================================================================

:CREATE_DIRECTORY_SAFE
:: Create directory with permissions (params: dir_path, permissions)
set "DIR=%~1"
set "PERMS=%~2"

if not exist "%DIR%" (
    mkdir "%DIR%" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        exit /b 1
    )
)

if not "%PERMS%"=="" (
    icacls "%DIR%" /grant "%PERMS%" >nul 2>&1
)

exit /b 0

:DELETE_DIRECTORY_SAFE
:: Safely delete directory with retry (params: dir_path, max_retries)
set "DIR=%~1"
set "MAX_RETRIES=%~2"
if "%MAX_RETRIES%"=="" set "MAX_RETRIES=3"

if not exist "%DIR%" (
    exit /b 0
)

set "RETRY=0"
:DELETE_RETRY
set /a RETRY+=1

rd /s /q "%DIR%" >nul 2>&1
if not exist "%DIR%" (
    exit /b 0
)

if %RETRY% lss %MAX_RETRIES% (
    timeout /t 1 /nobreak >nul
    goto :DELETE_RETRY
)

:: Try with takeown if still exists
takeown /f "%DIR%" /r /d y >nul 2>&1
icacls "%DIR%" /grant administrators:F /t >nul 2>&1
rd /s /q "%DIR%" >nul 2>&1

if not exist "%DIR%" (
    exit /b 0
)
exit /b 1

:BACKUP_FILE
:: Backup file with timestamp (params: file_path, backup_dir)
set "FILE=%~1"
set "BACKUP_DIR=%~2"

if not exist "%FILE%" (
    exit /b 1
)

for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,8%_%datetime:~8,6%"

set "FILENAME=%~nx1"
set "BACKUP_FILE=%BACKUP_DIR%\%FILENAME%.%TIMESTAMP%.bak"

copy /y "%FILE%" "%BACKUP_FILE%" >nul 2>&1
exit /b %ERRORLEVEL%

:: ============================================================================
:: LOGGING FUNCTIONS
:: ============================================================================

:INIT_LOG
:: Initialize log file (params: log_path)
set "LOG_FILE=%~1"

(
    echo ========================================================================
    echo TRAINING AI SERVER - Installation Log
    echo Started: %DATE% %TIME%
    echo ========================================================================
    echo.
) > "%LOG_FILE%" 2>&1

exit /b 0

:LOG_MESSAGE
:: Log message with timestamp (params: message, log_file)
set "MESSAGE=%~1"
set "LOG_FILE=%~2"

echo [%TIME%] %MESSAGE% >> "%LOG_FILE%" 2>&1
exit /b 0

:LOG_ERROR
:: Log error with context (params: message, log_file, error_code)
set "MESSAGE=%~1"
set "LOG_FILE=%~2"
set "ERROR_CODE=%~3"

echo [%TIME%] [ERROR %ERROR_CODE%] %MESSAGE% >> "%LOG_FILE%" 2>&1
exit /b 0

:: ============================================================================
:: UTILITY FUNCTIONS
:: ============================================================================

:GET_TIMESTAMP
:: Get timestamp string (output_var)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "%~1=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%"
exit /b 0

:WAIT_FOR_URL
:: Wait for URL to respond (params: url, timeout_seconds)
set "URL=%~1"
set "TIMEOUT=%~2"
if "%TIMEOUT%"=="" set "TIMEOUT=30"

set "ELAPSED=0"
:WAIT_URL_LOOP
curl -s -f "%URL%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    exit /b 0
)

timeout /t 1 /nobreak >nul
set /a ELAPSED+=1

if %ELAPSED% geq %TIMEOUT% (
    exit /b 1
)
goto :WAIT_URL_LOOP

:REFRESH_ENVIRONMENT
:: Refresh environment variables
for /f "skip=2 tokens=3*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path') do (
    set "SYS_PATH=%%a %%b"
)
for /f "skip=2 tokens=3*" %%a in ('reg query "HKCU\Environment" /v Path') do (
    set "USER_PATH=%%a %%b"
)
set "PATH=%SYS_PATH%;%USER_PATH%"
exit /b 0

:CALCULATE_FOLDER_SIZE
:: Calculate folder size in MB (params: folder_path, output_var)
set "FOLDER=%~1"

if not exist "%FOLDER%" (
    set "%~2=0"
    exit /b 1
)

set "TOTAL_SIZE=0"
for /r "%FOLDER%" %%f in (*) do (
    set /a TOTAL_SIZE+=%%~zf
)

set /a "SIZE_MB=%TOTAL_SIZE%/1048576"
set "%~2=%SIZE_MB%"
exit /b 0

:: ============================================================================
:: END OF LIBRARY
:: ============================================================================
