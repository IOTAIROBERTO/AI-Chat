@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title TRAINING AI SERVER - Instalador

REM ============================================================
REM  install_ai_server.bat
REM  Instalador automatizado del TRAINING AI SERVER (Windows)
REM  Uso:
REM     install_ai_server.bat           (instalar lo faltante)
REM     install_ai_server.bat /update   (actualizar todo)
REM     install_ai_server.bat /defender (incluir exclusiones Defender)
REM ============================================================

set "MODE_UPDATE=0"
set "MODE_DEFENDER=0"
for %%A in (%*) do (
    if /I "%%~A"=="/update"   set "MODE_UPDATE=1"
    if /I "%%~A"=="/defender" set "MODE_DEFENDER=1"
)

REM ============================================================
REM  FORZAR PRIVILEGIOS DE ADMINISTRADOR (3 capas)
REM   1) net session                 -> el comando estandar para detectar admin
REM   2) Re-lanzamiento via UAC      -> con captura de cancelacion
REM   3) Verificacion de SID         -> S-1-5-32-544 ACTIVO en el token
REM  Sin admin no hay forma de continuar (exit /b 1).
REM ============================================================
net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo ============================================================
    echo  Se requieren PRIVILEGIOS DE ADMINISTRADOR
    echo ============================================================
    echo  Solicitando elevacion via UAC...
    echo  Por favor haz clic en SI cuando aparezca la ventana.
    echo.
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }"
    if errorlevel 1 (
        echo.
        echo ============================================================
        echo  [ERROR] La elevacion fue CANCELADA o RECHAZADA.
        echo ============================================================
        echo  Este instalador NO puede continuar sin privilegios de
        echo  Administrador. Causas posibles:
        echo    - Hiciste clic en NO en la ventana de UAC.
        echo    - Tu cuenta no tiene permisos de Administrador.
        echo    - UAC esta deshabilitado en este equipo.
        echo.
        echo  Soluciones:
        echo    - Vuelve a ejecutar y acepta el prompt de UAC.
        echo    - Inicia sesion con una cuenta de Administrador.
        echo    - Clic-derecho sobre este .bat - "Ejecutar como Administrador".
        echo ============================================================
        echo.
        pause
    )
    exit /b
)

REM ---------- Confirmacion explicita de privilegios ----------
REM    Verifica que el grupo BUILTIN\Administrators (S-1-5-32-544) este
REM    ACTIVO en el token actual (no solo presente como "deny only").
echo.
echo ============================================================
echo  Ejecutando como : %USERNAME%
whoami /groups 2>nul | findstr /C:"S-1-5-32-544" | findstr /I /C:"Enabled group" >nul
if errorlevel 1 (
    REM Fallback: aceptar si net session paso pero el SID no aparece "Enabled group"
    REM (algunas configuraciones AAD/dominio reportan el grupo de otra forma).
    whoami /groups 2>nul | findstr /C:"S-1-5-32-544" >nul
    if errorlevel 1 (
        echo  Privilegios    : USUARIO NORMAL ^(grupo Administrators ausente^)
        echo ============================================================
        echo  [ERROR] No estas en el grupo de Administradores. Abortando.
        pause
        exit /b 1
    )
    echo  Privilegios    : ADMINISTRADOR [OK] ^(via net session^)
) else (
    echo  Privilegios    : ADMINISTRADOR [OK] ^(SID activo^)
)
echo ============================================================

REM ---------- Flags globales de pip ----------
REM   --prefer-binary           usa wheels precompilados (evita compilar chroma-hnswlib, etc.)
REM   --default-timeout=120     redes lentas no abortan
REM   --no-warn-script-location silencia warning de PATH cuando se instala como admin
REM   --disable-pip-version-check  evita aviso de version
set "PIP_OPTS=--prefer-binary --default-timeout=120 --no-warn-script-location --disable-pip-version-check"

REM ---------- Rutas ----------
set "SRC_DIR=%~dp0"
if "%SRC_DIR:~-1%"=="\" set "SRC_DIR=%SRC_DIR:~0,-1%"
set "INSTALL_ROOT=C:\AI-Server"
set "SERVER_DIR=%INSTALL_ROOT%\server"
set "USER_DATA=%LOCALAPPDATA%\TRAINING AI SERVER"
set "LAUNCH=%INSTALL_ROOT%\launch_server.bat"

REM ---------- Contadores ----------
set /a CNT_OK=0
set /a CNT_SKIP=0
set /a CNT_INSTALL=0
set /a CNT_UPDATE=0
set /a CNT_FAIL=0

REM ---------- Total de secciones (para indicador de progreso) ----------
REM    11 secciones base + 1 EXCLUSIONES DEFENDER (ahora obligatoria
REM    para evitar el error "Permission denied" en chromadb durante el
REM    indexado de PDFs) = 12 secciones siempre.
set /a TOTAL_SECTIONS=12
set /a SEC=0

REM ---------- Log ----------
if not exist "%INSTALL_ROOT%\logs" mkdir "%INSTALL_ROOT%\logs" >nul 2>&1
set "TS=%DATE:/=-%_%TIME::=-%"
set "TS=%TS: =0%"
set "TS=%TS:,=.%"
set "LOG=%INSTALL_ROOT%\logs\install_%TS%.log"
echo ============================================================ > "%LOG%"
echo  TRAINING AI SERVER - Install Log %DATE% %TIME%             >> "%LOG%"
echo  MODE_UPDATE=%MODE_UPDATE%  MODE_DEFENDER=%MODE_DEFENDER%   >> "%LOG%"
echo  SRC_DIR=%SRC_DIR%                                          >> "%LOG%"
echo ============================================================ >> "%LOG%"

REM ============================================================
REM  PRE-FLIGHT
REM ============================================================
call :hdr "PRE-FLIGHT"

ping -n 1 8.8.8.8 >nul 2>&1
if errorlevel 1 (
    call :fail "Sin conectividad a Internet. Abortando."
    goto :end
) else (
    call :ok "Conectividad a Internet"
)

where winget >nul 2>&1
if errorlevel 1 (
    call :fail "winget no esta disponible. Instala 'App Installer' desde Microsoft Store."
    goto :end
) else (
    call :ok "winget disponible"
)

REM ============================================================
set /a SEC+=1
call :sec "PYTHON 3.13"
REM ============================================================
py -3.13 --version >nul 2>&1
if errorlevel 1 (
    call :info "Python 3.13 no encontrado. Instalando..."
    winget install -e --id Python.Python.3.13 --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "Fallo al instalar Python 3.13" ) else ( call :installed "Python 3.13" )
    py -3.13 --version >nul 2>&1
    if errorlevel 1 (
        call :fail "Python 3.13 sigue sin estar disponible. Reinicia CMD o instala manualmente desde python.org."
        goto :end
    )
) else (
    if "%MODE_UPDATE%"=="1" (
        call :info "Actualizando Python 3.13..."
        winget upgrade -e --id Python.Python.3.13 --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
        call :updated "Python 3.13"
    ) else (
        for /f "tokens=*" %%V in ('py -3.13 --version 2^>^&1') do call :skip "%%V ya instalado"
    )
)
call :bar 1 1 "Python 3.13"

REM ============================================================
set /a SEC+=1
call :sec "OLLAMA"
REM ============================================================
where ollama >nul 2>&1
if errorlevel 1 (
    call :info "Ollama no encontrado. Instalando..."
    winget install -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "Fallo al instalar Ollama" ) else ( call :installed "Ollama" )
    where ollama >nul 2>&1
    if errorlevel 1 (
        call :info "Agregando Ollama al PATH del sistema..."
        setx PATH "%PATH%;%LOCALAPPDATA%\Programs\Ollama" /M >> "%LOG%" 2>&1
        set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Ollama"
        call :info "PATH actualizado. Algunas verificaciones podrian requerir reabrir CMD."
    )
) else (
    if "%MODE_UPDATE%"=="1" (
        call :info "Actualizando Ollama..."
        winget upgrade -e --id Ollama.Ollama --accept-source-agreements --accept-package-agreements >> "%LOG%" 2>&1
        call :updated "Ollama"
    ) else (
        call :skip "Ollama ya instalado"
    )
)
call :bar 1 1 "Ollama"

REM ============================================================
set /a SEC+=1
call :sec "VARIABLES DE ENTORNO"
REM ============================================================
set /a STEP=0
set /a STEPS=2

REM ANONYMIZED_TELEMETRY: silencia warnings de chromadb
set /a STEP+=1
if /I "%ANONYMIZED_TELEMETRY%"=="False" (
    call :skip "[!STEP!/!STEPS!] ANONYMIZED_TELEMETRY ya = False"
) else (
    setx ANONYMIZED_TELEMETRY False /M >> "%LOG%" 2>&1
    set "ANONYMIZED_TELEMETRY=False"
    call :installed "[!STEP!/!STEPS!] ANONYMIZED_TELEMETRY=False (sistema)"
)
call :bar !STEP! !STEPS! "ANONYMIZED_TELEMETRY"

REM HF_HUB_DISABLE_SYMLINKS_WARNING: silencia warning de symlinks de huggingface
REM (Windows no permite symlinks sin Developer Mode o admin permanente)
set /a STEP+=1
if "%HF_HUB_DISABLE_SYMLINKS_WARNING%"=="1" (
    call :skip "[!STEP!/!STEPS!] HF_HUB_DISABLE_SYMLINKS_WARNING ya = 1"
) else (
    setx HF_HUB_DISABLE_SYMLINKS_WARNING 1 /M >> "%LOG%" 2>&1
    set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"
    call :installed "[!STEP!/!STEPS!] HF_HUB_DISABLE_SYMLINKS_WARNING=1 (sistema)"
)
call :bar !STEP! !STEPS! "HF_HUB_DISABLE_SYMLINKS_WARNING"

REM ============================================================
set /a SEC+=1
call :sec "ESTRUCTURA DE CARPETAS"
REM ============================================================
set /a STEP=0
set /a STEPS=8
call :mkd "%SERVER_DIR%"
call :mkd "%INSTALL_ROOT%\installer"
call :mkd "%INSTALL_ROOT%\manuals"
call :mkd "%INSTALL_ROOT%\docs"
call :mkd "%INSTALL_ROOT%\logs"
call :mkd "%INSTALL_ROOT%\temp"
call :mkd "%USER_DATA%"
call :mkd "%USER_DATA%\chroma_db"
call :bar !STEPS! !STEPS! "Carpetas listas"

REM ============================================================
set /a SEC+=1
call :sec "COPIA DE ARCHIVOS Y CONTENIDO"
REM ============================================================
REM    Copia: 4 archivos del servidor + tester HTML + docs/*.html + manuals/*.pdf
REM    El total se calcula dinamicamente para soportar cualquier cantidad
REM    de PDFs en la carpeta de manuales del paquete fuente.
set /a STEPS=0
for %%F in ("offline_server.py" "launcher.py" "requirements.txt" "logo.png") do (
    if exist "%SRC_DIR%\server\%%~F" set /a STEPS+=1
)
if exist "%SRC_DIR%\AI_Server_Tester.html" set /a STEPS+=1
for %%F in ("%SRC_DIR%\docs\*.html") do set /a STEPS+=1
for %%F in ("%SRC_DIR%\manuals\*.pdf")   do set /a STEPS+=1

if !STEPS!==0 (
    call :fail "No se encontraron archivos a copiar en %SRC_DIR%"
) else (
    set /a STEP=0
    REM 1) Servidor (Python)
    call :copy_to "%SRC_DIR%\server\offline_server.py" "%SERVER_DIR%\offline_server.py"
    call :copy_to "%SRC_DIR%\server\launcher.py"        "%SERVER_DIR%\launcher.py"
    call :copy_to "%SRC_DIR%\server\requirements.txt"   "%SERVER_DIR%\requirements.txt"
    call :copy_to "%SRC_DIR%\server\logo.png"           "%SERVER_DIR%\logo.png"
    REM 2) Tester HTML (raiz de la instalacion)
    if exist "%SRC_DIR%\AI_Server_Tester.html" call :copy_to "%SRC_DIR%\AI_Server_Tester.html" "%INSTALL_ROOT%\AI_Server_Tester.html"
    REM 3) Documentacion HTML
    for %%F in ("%SRC_DIR%\docs\*.html") do call :copy_to "%%~fF" "%INSTALL_ROOT%\docs\%%~nxF"
    REM 4) Manuales PDF (todos los que existan en el paquete fuente)
    for %%F in ("%SRC_DIR%\manuals\*.pdf") do call :copy_to "%%~fF" "%INSTALL_ROOT%\manuals\%%~nxF"
)

REM ============================================================
set /a SEC+=1
call :sec "PAQUETES PYTHON 3.13"
REM ============================================================

REM ---- Bootstrap: pip + setuptools + wheel + numpy ----
REM    Necesarios ANTES de chromadb. Sin numpy/wheel, chroma-hnswlib y
REM    onnxruntime intentaran compilar desde fuente y fallaran.
call :info "Bootstrap: actualizando pip, setuptools, wheel..."
py -3.13 -m pip install %PIP_OPTS% --upgrade pip setuptools wheel >> "%LOG%" 2>&1
if errorlevel 1 ( call :fail "Bootstrap pip/setuptools/wheel" ) else ( call :ok "Bootstrap pip/setuptools/wheel" )

call :info "Bootstrap: numpy (prerequisito de chromadb)..."
py -3.13 -m pip install %PIP_OPTS% numpy >> "%LOG%" 2>&1
if errorlevel 1 ( call :fail "Bootstrap numpy" ) else ( call :ok "Bootstrap numpy" )

set /a PIP_TOTAL=13
set /a PIP_STEP=0
call :pip_install "av"             "av>=13.0.0"             ""
call :pip_install "faster-whisper" "faster-whisper==1.1.1"  "--no-deps"
call :pip_install "ctranslate2"    "ctranslate2"            ""
call :pip_install "huggingface-hub" "huggingface_hub>=0.13" ""
call :pip_install "tokenizers"     "tokenizers"             ""
call :pip_install "flask"          "flask==3.1.0"           ""
call :pip_install "flask-cors"     "flask-cors==5.0.0"      ""
call :pip_install "ollama"         "ollama==0.4.4"          ""
call :pip_install "chromadb"       "chromadb==0.5.23"       ""
call :pip_install "PyPDF2"         "PyPDF2==3.0.1"          ""
call :pip_install "colorama"       "colorama==0.4.6"        ""
call :pip_install "requests"       "requests==2.32.3"       ""
call :pip_install "cryptography"   "cryptography>=45.0.1"   ""

REM ============================================================
set /a SEC+=1
call :sec "MODELO OLLAMA POR DEFECTO"
REM ============================================================
REM    Solo se descarga el modelo predeterminado (qwen3:4b ~2.6 GB).
REM    Los demas modelos (qwen3:1.7b, phi4-mini, qwen3:8b) se pueden
REM    descargar despues desde la GUI del launcher en el dropdown
REM    "Download" -> "Descargar". No demoramos la instalacion con eso.
set /a OLA_TOTAL=1
set /a OLA_STEP=0
call :ollama_pull "qwen3:4b"

REM ============================================================
set /a SEC+=1
call :sec "CONFIGURACION DEL SERVIDOR"
REM ============================================================
set "CFG=%SERVER_DIR%\server_config.json"
if exist "%CFG%" (
    call :skip "server_config.json ya existe (no se sobreescribe)"
) else (
    (
        echo {
        echo   "current_model": "qwen3:4b",
        echo   "bilingual_mode": true,
        echo   "primary_language": "es",
        echo   "supported_languages": ["es", "en"]
        echo }
    ) > "%CFG%"
    if exist "%CFG%" ( call :installed "server_config.json creado" ) else ( call :fail "No se pudo crear server_config.json" )
)
call :bar 1 1 "server_config.json"

REM ============================================================
set /a SEC+=1
call :sec "SCRIPT DE LANZAMIENTO (launch_server.bat)"
REM ============================================================
call :write_launch
if exist "%LAUNCH%" ( call :installed "launch_server.bat creado" ) else ( call :fail "No se pudo crear launch_server.bat" )
call :bar 1 1 "launch_server.bat"

REM ============================================================
set /a SEC+=1
call :sec "FIREWALL"
REM ============================================================
netsh advfirewall firewall show rule name="TRAINING AI SERVER" >nul 2>&1
if errorlevel 1 (
    netsh advfirewall firewall add rule name="TRAINING AI SERVER" dir=in action=allow protocol=TCP localport=5000-5010 profile=any >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "Fallo al crear regla de firewall" ) else ( call :installed "Regla de firewall TCP 5000-5010" )
) else (
    call :skip "Regla de firewall ya existe"
)
call :bar 1 1 "Firewall"

REM ============================================================
set /a SEC+=1
call :sec "EXCLUSIONES WINDOWS DEFENDER"
REM ============================================================
REM    Estas exclusiones son OBLIGATORIAS (no opcionales) porque sin
REM    ellas Defender bloquea tokenizer_config.json mientras chromadb
REM    lo escribe -> error "Errno 13 Permission denied" al indexar PDFs.
REM    Tambien excluye el cache de Whisper para evitar lentitud.
call :info "Aplicando exclusiones (rutas + procesos)..."
powershell -NoProfile -Command "try { Add-MpPreference -ExclusionPath 'C:\AI-Server' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath ($env:USERPROFILE + '\.cache') -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath ($env:USERPROFILE + '\.cache\chroma') -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath ($env:USERPROFILE + '\.cache\huggingface') -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionPath 'C:\AI-Server\server\whisper_cache' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'python.exe' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'pythonw.exe' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'ollama.exe' -ErrorAction SilentlyContinue; Write-Host 'OK exclusiones aplicadas' } catch { Write-Host ('AVISO: ' + $_.Exception.Message) }" >> "%LOG%" 2>&1
call :installed "Exclusiones aplicadas (Defender)"

REM Pre-crea el cache de chromadb con permisos correctos del usuario actual
REM para que la primera escritura no falle.
call :info "Pre-creando carpeta de cache con ACL del usuario..."
mkdir "%USERPROFILE%\.cache\chroma" >nul 2>&1
icacls "%USERPROFILE%\.cache" /grant "%USERNAME%":(OI)(CI)F /T >nul 2>&1
call :ok "Cache pre-creado con permisos correctos"
call :bar 1 1 "Defender + cache"

REM ============================================================
set /a SEC+=1
call :sec "ACCESO DIRECTO EN ESCRITORIO"
REM ============================================================
call :make_shortcut
call :bar 1 1 "Acceso directo"

REM ============================================================
call :hdr "VERIFICACION DE IMPORTS PYTHON"
REM ============================================================
REM    Confirmar que cada paquete realmente carga (no solo que pip show
REM    diga que esta presente). Detecta wheels corruptos y deps perdidas.
set "VERIFY_FAIL=0"
for %%P in (flask flask_cors ollama chromadb faster_whisper PyPDF2 cryptography colorama requests) do call :verify_import "%%P"
if "!VERIFY_FAIL!"=="1" (
    echo.
    echo [AVISO] Hay paquetes que no se pueden importar. Revisa %LOG%
    echo         Reintenta con: install_ai_server.bat /update
    echo         O instala manual:  py -3.13 -m pip install %PIP_OPTS% chromadb==0.5.23
)

REM ============================================================
call :hdr "VERIFICACION FINAL"
REM ============================================================
echo.
echo --- Python ---
py -3.13 --version
echo.
echo --- Ollama ---
ollama --version
ollama list
echo.
echo --- Paquetes Python clave ---
py -3.13 -m pip show flask chromadb faster-whisper ollama 2>nul | findstr /B /C:"Name:" /C:"Version:"
echo.
echo --- Carpeta del servidor ---
dir /B "%SERVER_DIR%" 2>nul
echo.
echo --- Acceso directo ---
if exist "%PUBLIC%\Desktop\TRAINING AI SERVER.lnk" ( echo OK   "%PUBLIC%\Desktop\TRAINING AI SERVER.lnk" ) else ( echo MISS "%PUBLIC%\Desktop\TRAINING AI SERVER.lnk" )
echo.

REM ---------- Aviso de archivos faltantes ----------
set "MISSING_FILES=0"
for %%F in (offline_server.py launcher.py requirements.txt logo.png) do (
    if not exist "%SERVER_DIR%\%%F" set /a MISSING_FILES+=1
)
if not exist "%LAUNCH%" set /a MISSING_FILES+=1
if !MISSING_FILES! GTR 0 (
    echo.
    echo [AVISO] Hay archivos del servidor que no se pudieron copiar
    echo         desde "%SRC_DIR%\server\".
    echo         Verifica que el paquete original incluya estos archivos.
)

:end
echo.
echo ============================================================
echo  RESUMEN
echo    OK         : !CNT_OK!
echo    SKIP       : !CNT_SKIP!
echo    INSTALADO  : !CNT_INSTALL!
echo    ACTUALIZADO: !CNT_UPDATE!
echo    FALLOS     : !CNT_FAIL!
echo  Log: %LOG%
echo ============================================================
echo.
pause
exit /b 0


REM ============================================================
REM  SUBRUTINAS
REM ============================================================

:hdr
echo.
echo ============================================================
echo  %~1
echo ============================================================
echo. >> "%LOG%"
echo === %~1 === >> "%LOG%"
goto :eof

:sec
echo.
echo ============================================================
echo  [!SEC!/!TOTAL_SECTIONS!] %~1
echo ============================================================
echo. >> "%LOG%"
echo === [!SEC!/!TOTAL_SECTIONS!] %~1 === >> "%LOG%"
goto :eof

:ok
echo [ OK    ] %~1
echo [OK] %~1 >> "%LOG%"
set /a CNT_OK+=1
goto :eof

:skip
echo [ SKIP  ] %~1
echo [SKIP] %~1 >> "%LOG%"
set /a CNT_SKIP+=1
goto :eof

:installed
echo [INSTALL] %~1
echo [INSTALL] %~1 >> "%LOG%"
set /a CNT_INSTALL+=1
goto :eof

:updated
echo [UPDATE ] %~1
echo [UPDATE] %~1 >> "%LOG%"
set /a CNT_UPDATE+=1
goto :eof

:fail
echo [ FAIL  ] %~1
echo [FAIL] %~1 >> "%LOG%"
set /a CNT_FAIL+=1
goto :eof

:info
echo [ INFO  ] %~1
echo [INFO] %~1 >> "%LOG%"
goto :eof

:bar
REM Barra de progreso ASCII de 25 caracteres.  %1=actual %2=total %3=etiqueta
setlocal EnableDelayedExpansion
set /a "PCT=(%~1*100)/%~2"
set /a "FILLED=PCT*25/100"
if !FILLED! GTR 25 set /a "FILLED=25"
set /a "EMPTY=25-FILLED"
set "B="
if !FILLED! GTR 0 for /L %%i in (1,1,!FILLED!) do set "B=!B!#"
if !EMPTY!  GTR 0 for /L %%i in (1,1,!EMPTY!)  do set "B=!B!."
echo   [!B!] !PCT!%%  ^(%~1/%~2^) %~3
endlocal
goto :eof

:mkd
set /a STEP+=1
if exist "%~1" (
    call :skip "[!STEP!/!STEPS!] Carpeta ya existe: %~1"
) else (
    mkdir "%~1" >nul 2>&1
    if exist "%~1" ( call :installed "[!STEP!/!STEPS!] Carpeta creada: %~1" ) else ( call :fail "[!STEP!/!STEPS!] No se pudo crear: %~1" )
)
goto :eof

:copyfile
REM Wrapper de retro-compatibilidad: copia desde server/<archivo> al servidor.
set /a STEP+=1
set "SRC=%SRC_DIR%\server\%~1"
set "DST=%SERVER_DIR%\%~1"
if not exist "%SRC%" (
    call :fail "[!STEP!/!STEPS!] Origen no encontrado: %SRC%"
    call :bar !STEP! !STEPS! "%~1"
    goto :eof
)
copy /Y "%SRC%" "%DST%" >> "%LOG%" 2>&1
if exist "%DST%" (
    call :installed "[!STEP!/!STEPS!] Copiado: %~1"
) else (
    call :fail "[!STEP!/!STEPS!] No se pudo copiar: %~1"
)
call :bar !STEP! !STEPS! "%~1"
goto :eof

:copy_to
REM Copia generica.  %1 = ruta absoluta de origen   %2 = ruta absoluta de destino.
set /a STEP+=1
if not exist "%~1" (
    call :fail "[!STEP!/!STEPS!] Origen no encontrado: %~nx1"
    call :bar !STEP! !STEPS! "%~nx1"
    goto :eof
)
copy /Y "%~1" "%~2" >> "%LOG%" 2>&1
if exist "%~2" (
    call :installed "[!STEP!/!STEPS!] %~nx1"
) else (
    call :fail "[!STEP!/!STEPS!] No se pudo copiar: %~nx1"
)
call :bar !STEP! !STEPS! "%~nx1"
goto :eof

:pip_install
REM %1 = nombre para 'pip show'   %2 = spec a instalar   %3 = flags extra
set /a PIP_STEP+=1
py -3.13 -m pip show %~1 >nul 2>&1
if errorlevel 1 goto :pip_do_install

REM Ya instalado: actualizar o saltar
if "%MODE_UPDATE%"=="1" (
    call :info "[!PIP_STEP!/!PIP_TOTAL!] Actualizando %~2 %~3"
    py -3.13 -m pip install %PIP_OPTS% --upgrade %~2 %~3 >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "[!PIP_STEP!/!PIP_TOTAL!] pip upgrade %~2" ) else ( call :updated "[!PIP_STEP!/!PIP_TOTAL!] %~1" )
) else (
    call :skip "[!PIP_STEP!/!PIP_TOTAL!] %~1 ya instalado"
)
call :bar !PIP_STEP! !PIP_TOTAL! "%~1"
goto :eof

:pip_do_install
REM Primer intento (con cache, prefer-binary)
call :info "[!PIP_STEP!/!PIP_TOTAL!] Instalando %~2 %~3"
py -3.13 -m pip install %PIP_OPTS% %~2 %~3 >> "%LOG%" 2>&1
if not errorlevel 1 goto :pip_install_ok

REM Segundo intento: --no-cache-dir --force-reinstall (limpia wheels corruptos)
call :info "[!PIP_STEP!/!PIP_TOTAL!] Reintentando %~1 (sin cache, forzar reinstalacion)..."
py -3.13 -m pip install %PIP_OPTS% --no-cache-dir --force-reinstall %~2 %~3 >> "%LOG%" 2>&1
if errorlevel 1 (
    call :fail "[!PIP_STEP!/!PIP_TOTAL!] pip install %~1 (2 intentos fallidos - ver %LOG%)"
) else (
    call :installed "[!PIP_STEP!/!PIP_TOTAL!] %~1 (reintento)"
)
call :bar !PIP_STEP! !PIP_TOTAL! "%~1"
goto :eof

:pip_install_ok
call :installed "[!PIP_STEP!/!PIP_TOTAL!] %~1"
call :bar !PIP_STEP! !PIP_TOTAL! "%~1"
goto :eof

:ollama_pull
REM %1 = modelo
set /a OLA_STEP+=1
ollama list 2>nul | findstr /I /C:"%~1" >nul
if errorlevel 1 (
    call :info "[!OLA_STEP!/!OLA_TOTAL!] Descargando modelo %~1 (puede tardar varios minutos)..."
    ollama pull %~1 >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "[!OLA_STEP!/!OLA_TOTAL!] ollama pull %~1" ) else ( call :installed "[!OLA_STEP!/!OLA_TOTAL!] Modelo %~1" )
) else (
    if "%MODE_UPDATE%"=="1" (
        call :info "[!OLA_STEP!/!OLA_TOTAL!] Actualizando modelo %~1..."
        ollama pull %~1 >> "%LOG%" 2>&1
        call :updated "[!OLA_STEP!/!OLA_TOTAL!] Modelo %~1"
    ) else (
        call :skip "[!OLA_STEP!/!OLA_TOTAL!] Modelo %~1 ya descargado"
    )
)
call :bar !OLA_STEP! !OLA_TOTAL! "%~1"
goto :eof

:write_launch
REM Escribe C:\AI-Server\launch_server.bat (sin ventana de consola).
REM  Usar %%~dp0 para que el archivo destino contenga %~dp0.
REM  Escapar redirecciones: ^>nul 2^>^&1
> "%LAUNCH%" echo @echo off
>>"%LAUNCH%" echo cd /d "%%~dp0"
>>"%LAUNCH%" echo if exist "venv\Scripts\pythonw.exe" goto :venv
>>"%LAUNCH%" echo where pythonw 1^>nul 2^>^&1
>>"%LAUNCH%" echo if not errorlevel 1 goto :sys_pyw
>>"%LAUNCH%" echo where pyw 1^>nul 2^>^&1
>>"%LAUNCH%" echo if not errorlevel 1 goto :sys_pyw_l
>>"%LAUNCH%" echo where py 1^>nul 2^>^&1
>>"%LAUNCH%" echo if not errorlevel 1 goto :sys_py
>>"%LAUNCH%" echo goto :no_py
>>"%LAUNCH%" echo :venv
>>"%LAUNCH%" echo start "" "venv\Scripts\pythonw.exe" "server\launcher.py"
>>"%LAUNCH%" echo exit /b 0
>>"%LAUNCH%" echo :sys_pyw
>>"%LAUNCH%" echo start "" pythonw "server\launcher.py"
>>"%LAUNCH%" echo exit /b 0
>>"%LAUNCH%" echo :sys_pyw_l
>>"%LAUNCH%" echo start "" pyw -3.13 "server\launcher.py"
>>"%LAUNCH%" echo exit /b 0
>>"%LAUNCH%" echo :sys_py
>>"%LAUNCH%" echo start "" py -3.13 "server\launcher.py"
>>"%LAUNCH%" echo exit /b 0
>>"%LAUNCH%" echo :no_py
>>"%LAUNCH%" echo echo [ERROR] Python 3.13 no encontrado. Reinstala con install_ai_server.bat
>>"%LAUNCH%" echo pause
>>"%LAUNCH%" echo exit /b 1
goto :eof

:make_shortcut
REM Crea logo.ico desde logo.png y acceso directo en escritorio publico.
REM Apunta DIRECTAMENTE a pythonw.exe (sin ventana de consola) en lugar de
REM al .bat - asi NO aparece ningun flash de CMD al lanzar el servidor.
REM Estrategia para localizar pythonw.exe:
REM   1) Preguntar a Python 3.13 su sys.exec_prefix (mas confiable)
REM   2) where pythonw    (fallback)
REM   3) where pyw        (fallback - el launcher de Python)
REM   4) C:\AI-Server\launch_server.bat (ultimo recurso, mostrara flash)
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
if defined PYW (
    set "TGT=!PYW!"
    set "ARGS=\"%SERVER_DIR%\launcher.py\""
    call :info "Acceso directo apuntara a: !PYW!"
) else (
    set "TGT=%LAUNCH%"
    set "ARGS="
    call :info "pythonw.exe no encontrado - usando launch_server.bat (mostrara flash de CMD)"
)

set "PS1=%TEMP%\tas_make_shortcut_%RANDOM%.ps1"
> "%PS1%" echo $ErrorActionPreference = 'Stop'
>>"%PS1%" echo $png = 'C:\AI-Server\server\logo.png'
>>"%PS1%" echo $ico = 'C:\AI-Server\server\logo.ico'
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
>>"%PS1%" echo         Write-Host ('Icono creado: ' + $ico)
>>"%PS1%" echo     } catch { Write-Host ('AVISO: no se pudo convertir logo.png a .ico: ' + $_.Exception.Message) }
>>"%PS1%" echo }
>>"%PS1%" echo $deskAll  = [Environment]::GetFolderPath('CommonDesktopDirectory')
>>"%PS1%" echo $lnkPath  = Join-Path $deskAll 'TRAINING AI SERVER.lnk'
>>"%PS1%" echo $sh = New-Object -ComObject WScript.Shell
>>"%PS1%" echo $lnk = $sh.CreateShortcut($lnkPath)
>>"%PS1%" echo $lnk.TargetPath = '!TGT!'
>>"%PS1%" echo $lnk.Arguments  = '!ARGS!'
>>"%PS1%" echo $lnk.WorkingDirectory = 'C:\AI-Server\server'
>>"%PS1%" echo $lnk.WindowStyle = 1
>>"%PS1%" echo $lnk.Description = 'TRAINING AI SERVER Launcher'
>>"%PS1%" echo if (Test-Path $ico) { $lnk.IconLocation = $ico }
>>"%PS1%" echo $lnk.Save()
>>"%PS1%" echo Write-Host ('Acceso directo creado: ' + $lnkPath)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" >> "%LOG%" 2>&1
set "PS_RC=!ERRORLEVEL!"
del /q "%PS1%" 2>nul
if "!PS_RC!"=="0" ( call :installed "Acceso directo en escritorio" ) else ( call :fail "No se pudo crear el acceso directo (ver log)" )
goto :eof

:verify_import
REM Importa el modulo y reporta resultado.  %1 = nombre de import (ej. chromadb)
py -3.13 -c "import %~1, sys; sys.stdout.write('OK')" >> "%LOG%" 2>&1
if errorlevel 1 (
    echo   [FAIL] %~1   ^(no se puede importar^)
    set "VERIFY_FAIL=1"
) else (
    echo   [ OK ] %~1
)
goto :eof
