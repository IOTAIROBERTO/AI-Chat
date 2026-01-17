@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

:: ============================================================================
:: TRAINING AI SERVER - Production Uninstallation Script
:: Version: 3.0
:: Description: Enterprise-grade uninstaller with data preservation options
:: ============================================================================

:: ============================================================================
:: CONFIGURATION
:: ============================================================================
set "SCRIPT_VERSION=3.0.0"
set "APP_NAME=TRAINING AI SERVER"
set "INSTALL_DIR=%~1"
set "SILENT_MODE=%~2"

:: Validate parameters
if "%INSTALL_DIR%"=="" (
    set "INSTALL_DIR=C:\Program Files\TRAINING AI SERVER"
)

:: Set paths
set "LOG_DIR=%INSTALL_DIR%\logs"
set "BACKUP_DIR=%USERPROFILE%\TrainingAIServer_Backup"

:: Create timestamp
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set "TIMESTAMP=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%_%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%"
set "UNINSTALL_LOG=%TEMP%\training_ai_server_uninstall_%TIMESTAMP%.log"

:: ============================================================================
:: INITIALIZE LOGGING
:: ============================================================================
echo ======================================================================== > "%UNINSTALL_LOG%"
echo  %APP_NAME% - UNINSTALLATION STARTED >> "%UNINSTALL_LOG%"
echo  Version: %SCRIPT_VERSION% >> "%UNINSTALL_LOG%"
echo  Timestamp: %TIMESTAMP% >> "%UNINSTALL_LOG%"
echo ======================================================================== >> "%UNINSTALL_LOG%"
echo. >> "%UNINSTALL_LOG%"

call :LOG "Uninstallation initiated"

:: ============================================================================
:: CONFIRMATION DIALOG
:: ============================================================================

if not "%SILENT_MODE%"=="/SILENT" (
    call :LOG "Showing confirmation dialog to user"
    
    :: Show graphical confirmation using PowerShell
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$result = [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); ^
     $result = [System.Windows.Forms.MessageBox]::Show( ^
         'This will completely remove TRAINING AI SERVER and ALL associated data including:' + [Environment]::NewLine + [Environment]::NewLine + ^
         '• AI models and cached data (~2GB)' + [Environment]::NewLine + ^
         '• All configuration files' + [Environment]::NewLine + ^
         '• Indexed manuals database' + [Environment]::NewLine + ^
         '• Firewall rules' + [Environment]::NewLine + ^
         '• All logs and temporary files' + [Environment]::NewLine + ^
         '• Desktop shortcuts' + [Environment]::NewLine + [Environment]::NewLine + ^
         'This action cannot be undone!' + [Environment]::NewLine + [Environment]::NewLine + ^
         'Would you like to create a backup of your data before uninstalling?', ^
         'TRAINING AI SERVER - Confirm Uninstall', ^
         'YesNoCancel', ^
         'Warning' ^
     ); ^
     if ($result -eq 'Cancel') { exit 2 } ^
     elseif ($result -eq 'Yes') { exit 0 } ^
     else { exit 1 }"
    
    set "DIALOG_RESULT=!ERRORLEVEL!"
    
    if !DIALOG_RESULT! equ 2 (
        call :LOG "User cancelled uninstallation"
        echo Uninstallation cancelled by user. >> "%UNINSTALL_LOG%"
        exit /b 0
    )
    
    if !DIALOG_RESULT! equ 0 (
        call :LOG "User requested data backup"
        set "CREATE_BACKUP=1"
    ) else (
        call :LOG "User declined data backup"
        set "CREATE_BACKUP=0"
    )
) else (
    call :LOG "Silent mode - no confirmation dialog"
    set "CREATE_BACKUP=0"
)

:: ============================================================================
:: DATA BACKUP (if requested)
:: ============================================================================

if !CREATE_BACKUP! equ 1 (
    call :LOG "Creating data backup..."
    call :BACKUP_USER_DATA
    if !ERRORLEVEL! equ 0 (
        call :LOG "Backup completed successfully: %BACKUP_DIR%"
    ) else (
        call :LOG "WARNING: Backup failed but continuing with uninstall"
    )
)

:: ============================================================================
:: PHASE 1: STOP ALL PROCESSES
:: ============================================================================

call :LOG "[PHASE 1] Stopping running processes"
call :LOG "--------------------------------------"

:: Stop Python processes (offline_server.py, launcher.py)
call :LOG "Stopping Python server processes..."
taskkill /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq *offline_server*" /T /F >> "%UNINSTALL_LOG%" 2>&1
timeout /t 2 /nobreak >nul

taskkill /IM python.exe /F >> "%UNINSTALL_LOG%" 2>&1
taskkill /IM pythonw.exe /F >> "%UNINSTALL_LOG%" 2>&1
timeout /t 2 /nobreak >nul

:: Stop Ollama processes
call :LOG "Stopping Ollama service..."
taskkill /IM ollama.exe /F >> "%UNINSTALL_LOG%" 2>&1
taskkill /IM ollama_llama_server.exe /F >> "%UNINSTALL_LOG%" 2>&1
timeout /t 2 /nobreak >nul

:: Wait for processes to fully terminate
call :LOG "Waiting for processes to terminate..."
timeout /t 3 /nobreak >nul

:: Verify processes are stopped
tasklist | findstr /I "python.exe ollama.exe" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    call :LOG "WARNING: Some processes still running, forcing termination..."
    taskkill /F /IM python.exe /T >> "%UNINSTALL_LOG%" 2>&1
    taskkill /F /IM ollama.exe /T >> "%UNINSTALL_LOG%" 2>&1
    timeout /t 3 /nobreak >nul
)

call :LOG "All processes stopped"

:: ============================================================================
:: PHASE 2: REMOVE FIREWALL RULES
:: ============================================================================

call :LOG "[PHASE 2] Removing firewall rules"
call :LOG "-----------------------------------"

:: Remove all firewall rules for the application
call :LOG "Removing inbound rule..."
netsh advfirewall firewall delete rule name="TRAINING AI SERVER" >> "%UNINSTALL_LOG%" 2>&1

call :LOG "Removing outbound rule (if exists)..."
netsh advfirewall firewall delete rule name="TRAINING AI SERVER Out" >> "%UNINSTALL_LOG%" 2>&1

:: Verify removal
netsh advfirewall firewall show rule name="TRAINING AI SERVER" >nul 2>&1
if !ERRORLEVEL! neq 0 (
    call :LOG "Firewall rules removed successfully"
) else (
    call :LOG "WARNING: Some firewall rules may still exist"
)

:: ============================================================================
:: PHASE 3: REMOVE SHORTCUTS
:: ============================================================================

call :LOG "[PHASE 3] Removing shortcuts"
call :LOG "-----------------------------"

:: Remove desktop shortcut
set "DESKTOP=%USERPROFILE%\Desktop"
if exist "%DESKTOP%\TRAINING AI SERVER.lnk" (
    del /f /q "%DESKTOP%\TRAINING AI SERVER.lnk" >> "%UNINSTALL_LOG%" 2>&1
    call :LOG "Desktop shortcut removed"
)

:: Remove Start Menu shortcuts
set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if exist "%STARTMENU%\TRAINING AI SERVER" (
    rd /s /q "%STARTMENU%\TRAINING AI SERVER" >> "%UNINSTALL_LOG%" 2>&1
    call :LOG "Start Menu shortcuts removed"
)

:: Remove Quick Launch (if exists)
set "QUICKLAUNCH=%APPDATA%\Microsoft\Internet Explorer\Quick Launch"
if exist "%QUICKLAUNCH%\TRAINING AI SERVER.lnk" (
    del /f /q "%QUICKLAUNCH%\TRAINING AI SERVER.lnk" >> "%UNINSTALL_LOG%" 2>&1
    call :LOG "Quick Launch shortcut removed"
)

:: Remove Taskbar pin (Windows 10/11)
powershell -NoProfile -Command ^
    "$shell = New-Object -ComObject Shell.Application; ^
     $folder = $shell.Namespace('%DESKTOP%'); ^
     $item = $folder.ParseName('TRAINING AI SERVER.lnk'); ^
     if ($item) { $item.InvokeVerb('taskbarunpin') }" >> "%UNINSTALL_LOG%" 2>&1

call :LOG "All shortcuts processed"

:: ============================================================================
:: PHASE 4: REMOVE OLLAMA COMPLETELY
:: ============================================================================

call :LOG "[PHASE 4] Removing Ollama installation"
call :LOG "---------------------------------------"

:: Remove Ollama user data
if exist "%USERPROFILE%\.ollama" (
    call :LOG "Removing Ollama user data: %USERPROFILE%\.ollama"
    rd /s /q "%USERPROFILE%\.ollama" >> "%UNINSTALL_LOG%" 2>&1
    if exist "%USERPROFILE%\.ollama" (
        call :LOG "WARNING: Failed to remove some Ollama user data"
    ) else (
        call :LOG "Ollama user data removed"
    )
)

:: Remove Ollama program files
if exist "C:\Program Files\Ollama" (
    call :LOG "Removing Ollama from Program Files"
    rd /s /q "C:\Program Files\Ollama" >> "%UNINSTALL_LOG%" 2>&1
    if exist "C:\Program Files\Ollama" (
        call :LOG "WARNING: Failed to remove Ollama Program Files"
    ) else (
        call :LOG "Ollama Program Files removed"
    )
)

:: Remove Ollama (x86) if exists
if exist "C:\Program Files (x86)\Ollama" (
    call :LOG "Removing Ollama from Program Files (x86)"
    rd /s /q "C:\Program Files (x86)\Ollama" >> "%UNINSTALL_LOG%" 2>&1
)

:: Remove Ollama ProgramData
if exist "C:\ProgramData\Ollama" (
    call :LOG "Removing Ollama ProgramData"
    rd /s /q "C:\ProgramData\Ollama" >> "%UNINSTALL_LOG%" 2>&1
)

:: Remove Ollama from PATH (if present)
call :LOG "Cleaning Ollama from PATH environment variable"
call :REMOVE_FROM_PATH "Ollama"

:: Remove Ollama registry keys
call :LOG "Removing Ollama registry entries"
reg delete "HKCU\Software\Ollama" /f >> "%UNINSTALL_LOG%" 2>&1
reg delete "HKLM\Software\Ollama" /f >> "%UNINSTALL_LOG%" 2>&1

call :LOG "Ollama completely removed"

:: ============================================================================
:: PHASE 5: REMOVE APPLICATION FILES
:: ============================================================================

call :LOG "[PHASE 5] Removing application files"
call :LOG "--------------------------------------"

:: Remove main installation directory
if exist "%INSTALL_DIR%" (
    call :LOG "Removing: %INSTALL_DIR%"
    
    :: First try normal deletion
    rd /s /q "%INSTALL_DIR%" >> "%UNINSTALL_LOG%" 2>&1
    
    :: If still exists, try with takeown
    if exist "%INSTALL_DIR%" (
        call :LOG "Attempting forced removal with takeown..."
        takeown /f "%INSTALL_DIR%" /r /d y >> "%UNINSTALL_LOG%" 2>&1
        icacls "%INSTALL_DIR%" /grant administrators:F /t >> "%UNINSTALL_LOG%" 2>&1
        rd /s /q "%INSTALL_DIR%" >> "%UNINSTALL_LOG%" 2>&1
    )
    
    :: Final check
    if exist "%INSTALL_DIR%" (
        call :LOG "WARNING: Some files could not be removed. They may be in use."
        call :LOG "         Manual cleanup may be required: %INSTALL_DIR%"
    ) else (
        call :LOG "Application files removed successfully"
    )
) else (
    call :LOG "Installation directory not found, skipping"
)

:: ============================================================================
:: PHASE 6: REMOVE REGISTRY ENTRIES
:: ============================================================================

call :LOG "[PHASE 6] Removing registry entries"
call :LOG "------------------------------------"

:: Remove application registry keys
call :LOG "Removing application registry keys..."
reg delete "HKLM\Software\TrainingAIServer" /f >> "%UNINSTALL_LOG%" 2>&1
reg delete "HKCU\Software\TrainingAIServer" /f >> "%UNINSTALL_LOG%" 2>&1

:: Remove uninstall entry
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\{B4F8D7E3-9A2C-4E1D-8F3B-7C6D5E4F3A2B}_is1" /f >> "%UNINSTALL_LOG%" 2>&1

call :LOG "Registry entries removed"

:: ============================================================================
:: PHASE 7: CLEANUP TEMP FILES
:: ============================================================================

call :LOG "[PHASE 7] Cleaning temporary files"
call :LOG "-----------------------------------"

:: Remove temp files
if exist "%TEMP%\training_ai_*" (
    del /f /q "%TEMP%\training_ai_*" >> "%UNINSTALL_LOG%" 2>&1
)

:: Remove Python cache
if exist "%LOCALAPPDATA%\Temp\pip-*" (
    rd /s /q "%LOCALAPPDATA%\Temp\pip-*" >> "%UNINSTALL_LOG%" 2>&1
)

call :LOG "Temporary files cleaned"

:: ============================================================================
:: PHASE 8: VERIFICATION
:: ============================================================================

call :LOG "[PHASE 8] Verifying uninstallation"
call :LOG "-----------------------------------"

set "ISSUES=0"

:: Check if processes are still running
tasklist | findstr /I "python.exe ollama.exe" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    call :LOG "WARNING: Some processes are still running"
    set /a ISSUES+=1
)

:: Check if installation directory still exists
if exist "%INSTALL_DIR%" (
    call :LOG "WARNING: Installation directory still exists"
    set /a ISSUES+=1
)

:: Check if Ollama directory still exists
if exist "%USERPROFILE%\.ollama" (
    call :LOG "WARNING: Ollama user directory still exists"
    set /a ISSUES+=1
)

:: Check if registry keys still exist
reg query "HKLM\Software\TrainingAIServer" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    call :LOG "WARNING: Registry keys still exist"
    set /a ISSUES+=1
)

:: Check if firewall rules still exist
netsh advfirewall firewall show rule name="TRAINING AI SERVER" >nul 2>&1
if !ERRORLEVEL! equ 0 (
    call :LOG "WARNING: Firewall rules still exist"
    set /a ISSUES+=1
)

if !ISSUES! equ 0 (
    call :LOG "Verification passed - clean uninstallation"
) else (
    call :LOG "WARNING: Verification found !ISSUES! issue(s)"
    call :LOG "         Some manual cleanup may be required"
)

:: ============================================================================
:: COMPLETION
:: ============================================================================

call :LOG ""
call :LOG "========================================================================"
call :LOG " UNINSTALLATION COMPLETED"
call :LOG " Time: %TIME%"
call :LOG " Log: %UNINSTALL_LOG%"
if !CREATE_BACKUP! equ 1 (
    call :LOG " Backup: %BACKUP_DIR%"
)
call :LOG "========================================================================"

:: Copy log to user-accessible location
if exist "%USERPROFILE%\Desktop" (
    copy /y "%UNINSTALL_LOG%" "%USERPROFILE%\Desktop\uninstall_log_%TIMESTAMP%.txt" >nul 2>&1
    call :LOG "Log copied to desktop for reference"
)

:: Show completion message (non-silent mode)
if not "%SILENT_MODE%"=="/SILENT" (
    powershell -NoProfile -Command ^
    "$message = 'TRAINING AI SERVER has been uninstalled.' + [Environment]::NewLine + [Environment]::NewLine; ^
     if (!ISSUES! -gt 0) { ^
         $message += 'Note: Some components could not be removed automatically.' + [Environment]::NewLine + ^
                     'Please check the log file on your desktop for details.' + [Environment]::NewLine + [Environment]::NewLine; ^
     } ^
     if (!CREATE_BACKUP! -eq 1) { ^
         $message += 'Your data has been backed up to:' + [Environment]::NewLine + ^
                     '%BACKUP_DIR%' + [Environment]::NewLine + [Environment]::NewLine; ^
     } ^
     $message += 'Log file: %UNINSTALL_LOG%'; ^
     [System.Windows.Forms.MessageBox]::Show($message, 'Uninstallation Complete', 'OK', 'Information')" >> "%UNINSTALL_LOG%" 2>&1
)

exit /b 0

:: ============================================================================
:: FUNCTIONS
:: ============================================================================

:LOG
:: Log message with timestamp
echo [%TIME%] %~1 >> "%UNINSTALL_LOG%"
exit /b 0

:BACKUP_USER_DATA
:: Backup user configuration and data
call :LOG "Creating backup directory: %BACKUP_DIR%"

if not exist "%BACKUP_DIR%" (
    mkdir "%BACKUP_DIR%" >> "%UNINSTALL_LOG%" 2>&1
)

:: Backup configuration files
if exist "%INSTALL_DIR%\config" (
    call :LOG "Backing up configuration files..."
    xcopy "%INSTALL_DIR%\config\*.*" "%BACKUP_DIR%\config\" /E /I /Y >> "%UNINSTALL_LOG%" 2>&1
)

:: Backup manuals (if not too large)
if exist "%INSTALL_DIR%\manuals" (
    call :LOG "Backing up PDF manuals..."
    xcopy "%INSTALL_DIR%\manuals\*.pdf" "%BACKUP_DIR%\manuals\" /I /Y >> "%UNINSTALL_LOG%" 2>&1
)

:: Backup database
if exist "%INSTALL_DIR%\server\chroma_db" (
    call :LOG "Backing up indexed database..."
    xcopy "%INSTALL_DIR%\server\chroma_db\*.*" "%BACKUP_DIR%\database\" /E /I /Y >> "%UNINSTALL_LOG%" 2>&1
)

:: Backup logs (last 10 most recent)
if exist "%INSTALL_DIR%\logs\*.log" (
    call :LOG "Backing up recent logs..."
    for /f "tokens=*" %%f in ('dir /b /o-d "%INSTALL_DIR%\logs\*.log" ^| more +10') do (
        xcopy "%%f" "%BACKUP_DIR%\logs\" /I /Y >> "%UNINSTALL_LOG%" 2>&1
    )
)

:: Create backup info file
(
    echo TRAINING AI SERVER - Backup Information
    echo =======================================
    echo Backup Date: %DATE% %TIME%
    echo Original Location: %INSTALL_DIR%
    echo.
    echo Contents:
    echo - Configuration files
    echo - PDF Manuals
    echo - Indexed database
    echo - Recent logs
    echo.
    echo To restore, copy these files to your new installation
) > "%BACKUP_DIR%\BACKUP_INFO.txt"

call :LOG "Backup completed: %BACKUP_DIR%"
exit /b 0

:REMOVE_FROM_PATH
:: Remove a path component from PATH environment variable
set "SEARCH_PATH=%~1"
setlocal enabledelayedexpansion

:: Get current PATH
for /f "skip=2 tokens=1,*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USER_PATH=%%b"
for /f "skip=2 tokens=1,*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYSTEM_PATH=%%b"

:: Remove from user PATH
set "NEW_USER_PATH="
for %%p in ("%USER_PATH:;=" "%") do (
    set "PART=%%~p"
    echo !PART! | findstr /I /C:"%SEARCH_PATH%" >nul 2>&1
    if !ERRORLEVEL! neq 0 (
        if defined NEW_USER_PATH (
            set "NEW_USER_PATH=!NEW_USER_PATH!;!PART!"
        ) else (
            set "NEW_USER_PATH=!PART!"
        )
    )
)

:: Update registry if changed
if not "!NEW_USER_PATH!"=="!USER_PATH!" (
    reg add "HKCU\Environment" /v Path /t REG_EXPAND_SZ /d "!NEW_USER_PATH!" /f >> "%UNINSTALL_LOG%" 2>&1
    call :LOG "PATH updated - Ollama removed"
)

endlocal
exit /b 0
