@echo off
chcp 65001 >nul 2>&1

:: VR Manual Server - Firewall Configuration
:: Version 2.0

echo ============================================================
echo          VR MANUAL SERVER - FIREWALL CONFIG
echo ============================================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges.
    echo Please right-click and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo This script will configure Windows Firewall to allow
echo VR Manual Server to accept connections on port 5000.
echo.

set /p CONFIRM="Continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Operation cancelled.
    pause
    exit /b 0
)

echo.
echo Configuring firewall...
echo.

:: Remove existing rule if it exists
echo [1/3] Removing old rule (if exists)...
netsh advfirewall firewall delete rule name="VR Manual Server" >nul 2>&1
echo [OK] Old rule removed

:: Add inbound rule for TCP port 5000
echo [2/3] Adding inbound rule for TCP port 5000...
netsh advfirewall firewall add rule name="VR Manual Server" dir=in action=allow protocol=TCP localport=5000 profile=private,public

if %errorLevel% equ 0 (
    echo [OK] Inbound rule added successfully
) else (
    echo [ERROR] Failed to add inbound rule
    pause
    exit /b 1
)

:: Add outbound rule (optional, usually not needed)
echo [3/3] Adding outbound rule (optional)...
netsh advfirewall firewall add rule name="VR Manual Server Out" dir=out action=allow protocol=TCP localport=5000 profile=private,public >nul 2>&1

if %errorLevel% equ 0 (
    echo [OK] Outbound rule added successfully
) else (
    echo [WARN] Outbound rule may not be needed
)

echo.
echo ============================================================
echo          FIREWALL CONFIGURATION COMPLETED
echo ============================================================
echo.

:: Verify rules
echo Verifying firewall rules...
echo.

netsh advfirewall firewall show rule name="VR Manual Server" >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Firewall rules are active
    echo.
    echo Rule details:
    echo --------------
    netsh advfirewall firewall show rule name="VR Manual Server"
) else (
    echo [ERROR] Could not verify firewall rules
)

echo.
echo ============================================================
echo.
echo Port 5000 is now open for VR Manual Server.
echo Your Quest 3 should be able to connect to the server.
echo.
echo If you still have connection issues:
echo 1. Check that PC and Quest 3 are on same WiFi
echo 2. Verify server is running (http://localhost:5000/health)
echo 3. Try temporarily disabling firewall to test
echo 4. Check your router settings (some block device-to-device)
echo.
pause
