@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================================
:: VR TRAINING AI SERVER - COMPLETE UNINSTALLER v2.1
:: Removes everything: app files, Ollama models, databases, configs, registry
:: With progress indicators in title bar
:: ============================================================================

title VR Training AI Server - Complete Uninstaller - Starting...

color 0C
echo.
echo ════════════════════════════════════════════════════════════════════════
echo                   VR TRAINING AI SERVER
echo                   COMPLETE UNINSTALLER v2.1
echo ════════════════════════════════════════════════════════════════════════
echo.
color 0F

:: Check for admin privileges
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    color 0C
    echo [ERROR] Administrator privileges required!
    echo.
    echo Please right-click this script and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo [INFO] This will permanently remove:
echo.
echo   ✓ VR Training AI Server application
echo   ✓ All indexed manuals and PDFs
echo   ✓ ChromaDB vector database
echo   ✓ Server configuration files
echo   ✓ All downloaded Ollama AI models
echo   ✓ Ollama application (optional)
echo   ✓ Desktop shortcuts
echo   ✓ Start Menu entries
echo   ✓ Firewall rules
echo   ✓ Registry entries
echo.
color 0E
echo WARNING: This CANNOT be undone!
color 0F
echo.

set /p CONFIRM="Are you sure you want to continue? (YES/no): "
if /i not "!CONFIRM!"=="YES" (
    echo.
    echo Uninstallation cancelled.
    pause
    exit /b 0
)

echo.
echo ════════════════════════════════════════════════════════════════════════
echo Starting complete uninstallation...
echo ════════════════════════════════════════════════════════════════════════
echo.

:: ============================================================================
:: PHASE 1: Stop running processes
:: ============================================================================

title VR Training AI Server - Uninstalling... [1/8] Stopping processes

echo [PHASE 1/8] Stopping running processes...
echo.

echo   [1.1] Stopping Python launcher...
tasklist | findstr /i "python.exe.*launcher" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM python.exe /FI "WINDOWTITLE eq *launcher*" >nul 2>&1
    echo   [OK] Launcher stopped
) else (
    echo   [SKIP] Launcher not running
)

echo   [1.2] Stopping server processes...
tasklist | findstr /i "python.exe.*offline_server" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM python.exe /FI "WINDOWTITLE eq *offline_server*" >nul 2>&1
    echo   [OK] Server stopped
) else (
    echo   [SKIP] Server not running
)

echo   [1.3] Stopping Ollama service...
tasklist | findstr /i "ollama.exe" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    taskkill /F /IM ollama.exe >nul 2>&1
    timeout /t 2 /nobreak >nul
    echo   [OK] Ollama stopped
) else (
    echo   [SKIP] Ollama not running
)

echo.

:: ============================================================================
:: PHASE 2: Delete Ollama models
:: ============================================================================

title VR Training AI Server - Uninstalling... [2/8] Deleting AI models
echo [PHASE 2/8] Deleting Ollama AI models...
echo.

where ollama.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [INFO] Listing installed models...
    
    :: Get list of models
    set MODEL_COUNT=0
    for /f "skip=1 tokens=1" %%m in ('ollama list 2^>nul') do (
        set /a MODEL_COUNT+=1
        echo   [!MODEL_COUNT!] Deleting: %%m
        ollama rm %%m >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            echo       [OK] Deleted
        ) else (
            echo       [WARN] Could not delete
        )
    )
    
    if !MODEL_COUNT! equ 0 (
        echo   [SKIP] No models found
    ) else (
        echo   [OK] Deleted !MODEL_COUNT! model(s)
    )
) else (
    echo   [SKIP] Ollama not installed
)

echo.

:: ============================================================================
:: PHASE 3: Delete application files
:: ============================================================================

title VR Training AI Server - Uninstalling... [3/8] Removing app files
echo [PHASE 3/8] Deleting application files...
echo.

:: Priority 1: Use the directory passed as argument from the Inno Setup uninstaller
set "INSTALL_DIR=%~1"

:: Priority 2: Read from Inno Setup registry key (AppId-based)
if "%INSTALL_DIR%"=="" (
    for /f "tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}_is1" /v InstallLocation 2^>nul ^| findstr InstallLocation') do (
        set "INSTALL_DIR=%%b"
    )
)

:: Priority 3: Fallback to known folder names in common locations
if "%INSTALL_DIR%"=="" (
    if exist "%ProgramFiles%\TRAINING AI SERVER" (
        set "INSTALL_DIR=%ProgramFiles%\TRAINING AI SERVER"
    ) else if exist "%ProgramFiles(x86)%\TRAINING AI SERVER" (
        set "INSTALL_DIR=%ProgramFiles(x86)%\TRAINING AI SERVER"
    ) else if exist "%LocalAppData%\TRAINING AI SERVER" (
        set "INSTALL_DIR=%LocalAppData%\TRAINING AI SERVER"
    ) else if exist "C:\TRAINING AI SERVER" (
        set "INSTALL_DIR=C:\TRAINING AI SERVER"
    )
)

:: Strip trailing backslash if present
if "%INSTALL_DIR:~-1%"=="\" set "INSTALL_DIR=%INSTALL_DIR:~0,-1%"

if not "%INSTALL_DIR%"=="" (
    if exist "%INSTALL_DIR%" (
        echo   [INFO] Removing: %INSTALL_DIR%

        :: Wait briefly so any running processes have a chance to exit
        timeout /t 3 /nobreak >nul

        :: Try normal deletion first
        rd /s /q "%INSTALL_DIR%" >nul 2>&1

        :: If that fails, take ownership and retry
        if exist "%INSTALL_DIR%" (
            echo   [INFO] Forcing deletion with elevated permissions...
            takeown /f "%INSTALL_DIR%" /r /d y >nul 2>&1
            icacls "%INSTALL_DIR%" /grant administrators:F /t >nul 2>&1
            rd /s /q "%INSTALL_DIR%" >nul 2>&1
        )

        if not exist "%INSTALL_DIR%" (
            echo   [OK] Application files deleted
        ) else (
            echo   [WARN] Could not delete all files - scheduling removal on next reboot...
            :: Schedule deletion on reboot as last resort
            reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v PendingFileRenameOperations /t REG_MULTI_SZ /d "\??\%INSTALL_DIR%\0\0" /f >nul 2>&1
            echo   [INFO] Folder will be removed automatically on next Windows restart.
        )
    ) else (
        echo   [SKIP] Installation directory not found
    )
) else (
    echo   [SKIP] Installation path could not be determined - nothing to remove
)

:: Also remove LocalAppData folder created by the installer
set "LOCALAPP_DIR=%LOCALAPPDATA%\TRAINING AI SERVER"
if exist "%LOCALAPP_DIR%" (
    echo   [INFO] Removing local app data: %LOCALAPP_DIR%
    rd /s /q "%LOCALAPP_DIR%" >nul 2>&1
    if not exist "%LOCALAPP_DIR%" (
        echo   [OK] Local app data deleted
    ) else (
        echo   [WARN] Could not delete local app data
    )
) else (
    echo   [SKIP] Local app data folder not found
)

echo.

:: ============================================================================
:: PHASE 4: Delete user data (manuals, database, configs)
:: ============================================================================

title VR Training AI Server - Uninstalling... [4/8] Cleaning user data
echo [PHASE 4/8] Deleting user data...
echo.

:: ChromaDB data
set "CHROMA_DIR=%USERPROFILE%\.chroma"
if exist "%CHROMA_DIR%" (
    echo   [4.1] Deleting ChromaDB: %CHROMA_DIR%
    rd /s /q "%CHROMA_DIR%" >nul 2>&1
    if not exist "%CHROMA_DIR%" (
        echo   [OK] ChromaDB deleted
    )
) else (
    echo   [SKIP] ChromaDB not found
)

:: Ollama data directory
set "OLLAMA_DIR=%USERPROFILE%\.ollama"
if exist "%OLLAMA_DIR%" (
    echo   [4.2] Deleting Ollama data: %OLLAMA_DIR%
    rd /s /q "%OLLAMA_DIR%" >nul 2>&1
    if not exist "%OLLAMA_DIR%" (
        echo   [OK] Ollama data deleted
    )
) else (
    echo   [SKIP] Ollama data not found
)

:: App data directory
set "APPDATA_DIR=%APPDATA%\VR Training AI Server"
if exist "%APPDATA_DIR%" (
    echo   [4.3] Deleting app data: %APPDATA_DIR%
    rd /s /q "%APPDATA_DIR%" >nul 2>&1
    if not exist "%APPDATA_DIR%" (
        echo   [OK] App data deleted
    )
) else (
    echo   [SKIP] App data not found
)

:: Local app data directory (both possible names)
for %%D in ("%LOCALAPPDATA%\TRAINING AI SERVER" "%LOCALAPPDATA%\VR Training AI Server") do (
    if exist %%D (
        echo   [4.4] Deleting local app data: %%D
        rd /s /q %%D >nul 2>&1
        if not exist %%D (
            echo   [OK] Local app data deleted
        ) else (
            echo   [WARN] Could not delete: %%D
        )
    )
)

echo.

:: ============================================================================
:: PHASE 5: Delete shortcuts and Start Menu entries
:: ============================================================================

title VR Training AI Server - Uninstalling... [5/8] Removing shortcuts
echo [PHASE 5/8] Deleting shortcuts...
echo.

:: Desktop shortcut
set "DESKTOP_SHORTCUT=%USERPROFILE%\Desktop\VR Training AI Server.lnk"
if exist "%DESKTOP_SHORTCUT%" (
    echo   [5.1] Deleting desktop shortcut
    del /f /q "%DESKTOP_SHORTCUT%" >nul 2>&1
    echo   [OK] Desktop shortcut deleted
) else (
    echo   [SKIP] Desktop shortcut not found
)

:: Start Menu folder
set "STARTMENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\VR Training AI Server"
if exist "%STARTMENU_DIR%" (
    echo   [5.2] Deleting Start Menu folder
    rd /s /q "%STARTMENU_DIR%" >nul 2>&1
    echo   [OK] Start Menu folder deleted
) else (
    echo   [SKIP] Start Menu folder not found
)

:: Public Desktop shortcut
set "PUBLIC_DESKTOP=%PUBLIC%\Desktop\VR Training AI Server.lnk"
if exist "%PUBLIC_DESKTOP%" (
    echo   [5.3] Deleting public desktop shortcut
    del /f /q "%PUBLIC_DESKTOP%" >nul 2>&1
    echo   [OK] Public desktop shortcut deleted
) else (
    echo   [SKIP] Public desktop shortcut not found
)

echo.

:: ============================================================================
:: PHASE 6: Remove firewall rules
:: ============================================================================

title VR Training AI Server - Uninstalling... [6/8] Firewall cleanup
echo [PHASE 6/8] Removing firewall rules...
echo.

netsh advfirewall firewall show rule name="VR Manual Server" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [6.1] Removing firewall rule: VR Manual Server
    netsh advfirewall firewall delete rule name="VR Manual Server" >nul 2>&1
    echo   [OK] Firewall rule removed
) else (
    echo   [SKIP] Firewall rule not found
)

netsh advfirewall firewall show rule name="VR Manual Server Out" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [6.2] Removing firewall rule: VR Manual Server Out
    netsh advfirewall firewall delete rule name="VR Manual Server Out" >nul 2>&1
    echo   [OK] Firewall rule removed
) else (
    echo   [SKIP] Outbound firewall rule not found
)

netsh advfirewall firewall show rule name="TRAINING AI SERVER" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [6.3] Removing firewall rule: TRAINING AI SERVER
    netsh advfirewall firewall delete rule name="TRAINING AI SERVER" >nul 2>&1
    echo   [OK] Firewall rule removed
) else (
    echo   [SKIP] TRAINING AI SERVER rule not found
)

echo.

:: ============================================================================
:: PHASE 7: Delete registry entries
:: ============================================================================

title VR Training AI Server - Uninstalling... [7/8] Registry cleanup
echo [PHASE 7/8] Deleting registry entries...
echo.

:: Application registry key
reg query "HKLM\SOFTWARE\VR Training AI Server" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [7.1] Deleting registry key: HKLM\SOFTWARE\VR Training AI Server
    reg delete "HKLM\SOFTWARE\VR Training AI Server" /f >nul 2>&1
    echo   [OK] Registry key deleted
) else (
    echo   [SKIP] Registry key not found
)

:: Uninstall registry key
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VR Training AI Server" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [7.2] Deleting uninstall registry key
    reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VR Training AI Server" /f >nul 2>&1
    echo   [OK] Uninstall key deleted
) else (
    echo   [SKIP] Uninstall key not found
)

:: User registry keys
reg query "HKCU\SOFTWARE\VR Training AI Server" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [7.3] Deleting user registry key
    reg delete "HKCU\SOFTWARE\VR Training AI Server" /f >nul 2>&1
    echo   [OK] User registry key deleted
) else (
    echo   [SKIP] User registry key not found
)

echo.

:: ============================================================================
:: PHASE 8: Optional - Uninstall Ollama
:: ============================================================================

title VR Training AI Server - Uninstalling... [8/8] Optional: Ollama
echo [PHASE 8/8] Uninstall Ollama application?
echo.
echo   Ollama is used by other applications too.
echo   Only uninstall if you're sure you don't need it.
echo.

set /p UNINSTALL_OLLAMA="Uninstall Ollama? (yes/NO): "
if /i "!UNINSTALL_OLLAMA!"=="yes" (
    echo.
    echo   [8.1] Uninstalling Ollama...
    
    :: Try using winget first
    where winget >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        winget uninstall ollama.ollama --silent >nul 2>&1
        if !ERRORLEVEL! equ 0 (
            echo   [OK] Ollama uninstalled via winget
        ) else (
            echo   [WARN] winget uninstall failed, trying manual removal
            
            :: Manual removal
            set "OLLAMA_PATH="
            for /f "delims=" %%p in ('where ollama.exe 2^>nul') do set "OLLAMA_PATH=%%~dp0"
            
            if not "!OLLAMA_PATH!"==" " (
                echo   [INFO] Removing: !OLLAMA_PATH!
                rd /s /q "!OLLAMA_PATH!" >nul 2>&1
                echo   [OK] Ollama directory removed
            )
        )
    ) else (
        echo   [WARN] winget not available, manual removal required
        echo   [INFO] You can uninstall Ollama from Add/Remove Programs
    )
) else (
    echo   [SKIP] Keeping Ollama installed
)

echo.
title VR Training AI Server - Uninstall Complete!
echo ════════════════════════════════════════════════════════════════════════
echo                   UNINSTALLATION COMPLETED!
echo ════════════════════════════════════════════════════════════════════════
echo.

:: Summary
echo [SUMMARY]
echo.
echo The following have been removed:
echo   ✓ Application files
echo   ✓ Indexed manuals and PDFs
echo   ✓ Vector database (ChromaDB)
echo   ✓ Configuration files
echo   ✓ Ollama AI models
echo   ✓ Desktop shortcuts
echo   ✓ Start Menu entries
echo   ✓ Firewall rules
echo   ✓ Registry entries
echo.

if /i "!UNINSTALL_OLLAMA!"=="yes" (
    echo   ✓ Ollama application
    echo.
)

echo VR Training AI Server has been completely uninstalled.
echo.
echo Thank you for using VR Training AI Server!
echo.
pause
exit /b 0
