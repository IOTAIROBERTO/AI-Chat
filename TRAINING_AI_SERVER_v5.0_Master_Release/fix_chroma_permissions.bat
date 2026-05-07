@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title TRAINING AI SERVER - Fix ChromaDB Cache

REM ============================================================
REM  fix_chroma_permissions.bat
REM  Soluciona el error "Errno 13 Permission denied" al indexar
REM  manuales en chromadb. Causa: Windows Defender bloquea
REM  tokenizer_config.json mientras chromadb lo escribe/lee.
REM
REM  Que hace:
REM    1) Detiene servidor (launcher.py / offline_server.py)
REM    2) Borra cache corrupto de chromadb (~80MB, se re-descarga)
REM    3) Agrega exclusiones a Windows Defender
REM    4) Restaura permisos sobre la carpeta cache
REM    5) Establece HF_HUB_DISABLE_SYMLINKS_WARNING=1
REM
REM  Despues vuelve a iniciar el servidor desde el icono y reintenta
REM  el indexado. Chromadb descargara el embedding (~80MB) en el
REM  primer "Index" - eso es normal y solo pasa una vez.
REM ============================================================

REM ---------- Auto-elevacion ----------
net session >nul 2>&1
if errorlevel 1 (
    echo [INFO] Solicitando privilegios de Administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "CACHE=%USERPROFILE%\.cache\chroma"
set "WHISPER=C:\AI-Server\server\whisper_cache"
set "HF=%USERPROFILE%\.cache\huggingface"

echo.
echo ============================================================
echo  Reparando permisos de cache de ChromaDB / Whisper
echo ============================================================
echo  Cache chromadb : %CACHE%
echo  Cache whisper  : %WHISPER%
echo  Cache HF       : %HF%
echo ============================================================
echo.

echo [1/5] Deteniendo servidor...
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'launcher\.py|offline_server\.py' } | ForEach-Object { Write-Host ('  kill PID ' + $_.ProcessId); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
echo   OK

echo [2/5] Borrando cache corrupto de chromadb...
if exist "%CACHE%" (
    rd /s /q "%CACHE%" 2>nul
    if exist "%CACHE%" (
        takeown /f "%CACHE%" /r /d y >nul 2>&1
        icacls  "%CACHE%" /grant "%USERNAME%":F /T >nul 2>&1
        rd /s /q "%CACHE%" 2>nul
    )
    if exist "%CACHE%" ( echo   FAIL %CACHE% sigue presente ) else ( echo   OK cache eliminado )
) else (
    echo   SKIP no existia
)

echo [3/5] Agregando exclusiones a Windows Defender...
powershell -NoProfile -Command "Add-MpPreference -ExclusionPath '%CACHE%' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath '%USERPROFILE%\.cache' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath '%WHISPER%' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath '%HF%' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath 'C:\AI-Server' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'python.exe' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'pythonw.exe' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'ollama.exe' -ErrorAction SilentlyContinue; Write-Host '  OK exclusiones aplicadas'"

echo [4/5] Restaurando permisos en carpeta cache...
mkdir "%CACHE%"           >nul 2>&1
mkdir "%USERPROFILE%\.cache" >nul 2>&1
icacls "%USERPROFILE%\.cache" /grant "%USERNAME%":(OI)(CI)F /T >nul 2>&1
echo   OK ACL aplicada

echo [5/5] Estableciendo HF_HUB_DISABLE_SYMLINKS_WARNING=1...
setx HF_HUB_DISABLE_SYMLINKS_WARNING 1 /M >nul 2>&1
echo   OK variable de entorno

echo.
echo ============================================================
echo  Reparacion completa.
echo ============================================================
echo  Pasos siguientes:
echo    1) Inicia el servidor desde el icono del escritorio.
echo    2) En el primer "Index", ChromaDB descargara el modelo
echo       de embeddings (~80MB) - puede tardar 30-60 segundos.
echo    3) Indexados posteriores seran inmediatos.
echo ============================================================
echo.
pause
exit /b 0
