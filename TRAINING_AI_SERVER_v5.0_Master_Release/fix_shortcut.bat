@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title TRAINING AI SERVER - Fix Desktop Shortcut

REM ============================================================
REM  fix_shortcut.bat
REM  Reescribe el acceso directo del escritorio para que apunte
REM  DIRECTAMENTE a pythonw.exe en lugar de a launch_server.bat.
REM  Asi desaparece el flash de ventana CMD que aparecia al lanzar.
REM
REM  Ejecutar como Administrador (clic-derecho -> Ejecutar como admin).
REM ============================================================

REM ---------- Auto-elevacion ----------
net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Solicitando privilegios de Administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "SERVER_DIR=C:\AI-Server\server"
set "LAUNCHER=%SERVER_DIR%\launcher.py"
set "ICO=%SERVER_DIR%\logo.ico"
set "PNG=%SERVER_DIR%\logo.png"

if not exist "%LAUNCHER%" (
    echo [ERROR] No se encuentra %LAUNCHER%
    echo         Ejecuta primero install_ai_server.bat
    pause
    exit /b 1
)

REM ---------- Localizar pythonw.exe ----------
echo.
echo Buscando pythonw.exe...
set "PYW="
for /f "delims=" %%P in ('py -3.13 -c "import os,sys; print(os.path.join(sys.exec_prefix,'pythonw.exe'))" 2^>nul') do (
    if exist "%%P" if not defined PYW set "PYW=%%P"
)
if not defined PYW for /f "delims=" %%P in ('where pythonw 2^>nul') do (
    if not defined PYW set "PYW=%%P"
)
if not defined PYW for /f "delims=" %%P in ('where pyw 2^>nul') do (
    if not defined PYW set "PYW=%%P"
)
if not defined PYW (
    echo [ERROR] No se encuentra pythonw.exe / pyw.exe en el sistema.
    echo         Instala Python 3.13 con install_ai_server.bat
    pause
    exit /b 1
)
echo   Encontrado: !PYW!

REM ---------- Convertir logo.png a logo.ico si hace falta ----------
echo.
echo Reescribiendo acceso directo...
set "PS1=%TEMP%\tas_fix_shortcut_%RANDOM%.ps1"
> "%PS1%" echo $ErrorActionPreference = 'Stop'
>>"%PS1%" echo $png = '%PNG%'
>>"%PS1%" echo $ico = '%ICO%'
>>"%PS1%" echo if ((Test-Path $png) -and (-not (Test-Path $ico))) {
>>"%PS1%" echo     try {
>>"%PS1%" echo         Add-Type -AssemblyName System.Drawing
>>"%PS1%" echo         $bmp = [System.Drawing.Bitmap]::new($png)
>>"%PS1%" echo         $nb  = [System.Drawing.Bitmap]::new($bmp, 256, 256)
>>"%PS1%" echo         $h   = $nb.GetHicon()
>>"%PS1%" echo         $ic  = [System.Drawing.Icon]::FromHandle($h)
>>"%PS1%" echo         $fs  = [System.IO.FileStream]::new($ico, 'Create')
>>"%PS1%" echo         $ic.Save($fs)
>>"%PS1%" echo         $fs.Close()
>>"%PS1%" echo         $bmp.Dispose(); $nb.Dispose(); $ic.Dispose()
>>"%PS1%" echo     } catch { }
>>"%PS1%" echo }
>>"%PS1%" echo $deskAll = [Environment]::GetFolderPath('CommonDesktopDirectory')
>>"%PS1%" echo $deskUsr = [Environment]::GetFolderPath('Desktop')
>>"%PS1%" echo foreach ($d in @($deskAll, $deskUsr)) {
>>"%PS1%" echo     $lnkPath = Join-Path $d 'TRAINING AI SERVER.lnk'
>>"%PS1%" echo     if (Test-Path $lnkPath) { Remove-Item -Force $lnkPath }
>>"%PS1%" echo }
>>"%PS1%" echo $lnkPath = Join-Path $deskAll 'TRAINING AI SERVER.lnk'
>>"%PS1%" echo $sh = New-Object -ComObject WScript.Shell
>>"%PS1%" echo $lnk = $sh.CreateShortcut($lnkPath)
>>"%PS1%" echo $lnk.TargetPath = '!PYW!'
>>"%PS1%" echo $lnk.Arguments  = '"%LAUNCHER%"'
>>"%PS1%" echo $lnk.WorkingDirectory = '%SERVER_DIR%'
>>"%PS1%" echo $lnk.WindowStyle = 1
>>"%PS1%" echo $lnk.Description = 'TRAINING AI SERVER Launcher'
>>"%PS1%" echo if (Test-Path $ico) { $lnk.IconLocation = $ico }
>>"%PS1%" echo $lnk.Save()
>>"%PS1%" echo Write-Host ('Acceso directo creado: ' + $lnkPath)
>>"%PS1%" echo Write-Host ('  TargetPath  = ' + $lnk.TargetPath)
>>"%PS1%" echo Write-Host ('  Arguments   = ' + $lnk.Arguments)
>>"%PS1%" echo Write-Host ('  WorkingDir  = ' + $lnk.WorkingDirectory)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "PS_RC=!ERRORLEVEL!"
del /q "%PS1%" 2>nul

echo.
if "!PS_RC!"=="0" (
    echo ============================================================
    echo  Acceso directo reparado.
    echo ============================================================
    echo  Doble-clic en el icono del escritorio.
    echo  Ya NO debe aparecer ninguna ventana de CMD,
    echo  solo la ventana del launcher con la GUI.
    echo ============================================================
) else (
    echo [ERROR] No se pudo reescribir el acceso directo.
)
echo.
pause
exit /b 0
