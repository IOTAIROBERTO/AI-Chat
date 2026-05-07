@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
title TRAINING AI SERVER - Desinstalador

REM ============================================================
REM  uninstall_ai_server.bat
REM  Desinstalador del TRAINING AI SERVER (Windows)
REM  Uso:
REM     uninstall_ai_server.bat              (interactivo, con confirmacion)
REM     uninstall_ai_server.bat /yes         (sin confirmaciones)
REM     uninstall_ai_server.bat /keep-models (conserva modelos Ollama)
REM     uninstall_ai_server.bat /clean-pip   (tambien desinstala paquetes pip)
REM     uninstall_ai_server.bat /full        (tambien Ollama, Python y paquetes pip)
REM     uninstall_ai_server.bat /yes /full   (totalmente limpio, sin pausas)
REM ============================================================

set "MODE_FULL=0"
set "MODE_KEEP=0"
set "MODE_YES=0"
set "MODE_CLEAN_PIP=0"
for %%A in (%*) do (
    if /I "%%~A"=="/full"        set "MODE_FULL=1"
    if /I "%%~A"=="/keep-models" set "MODE_KEEP=1"
    if /I "%%~A"=="/yes"         set "MODE_YES=1"
    if /I "%%~A"=="/clean-pip"   set "MODE_CLEAN_PIP=1"
)
REM /full implica /clean-pip (Python se desinstala despues, pero limpiamos antes por si falla)
if "%MODE_FULL%"=="1" set "MODE_CLEAN_PIP=1"

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
        echo  Este desinstalador NO puede continuar sin privilegios de
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

REM ---------- Rutas ----------
set "INSTALL_ROOT=C:\AI-Server"
set "USER_DATA=%LOCALAPPDATA%\TRAINING AI SERVER"
set "OLLAMA_DIR=%USERPROFILE%\.ollama"
set "DESK_ALL=%PUBLIC%\Desktop"
set "DESK_USR=%USERPROFILE%\Desktop"
set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs\TRAINING AI SERVER"

REM ---------- Contadores ----------
set /a CNT_OK=0
set /a CNT_SKIP=0
set /a CNT_FAIL=0

REM ---------- Total de secciones ----------
REM    Base 8 secciones + LIMPIEZA RESIDUAL final.
REM    +1 si /clean-pip (paquetes pip)
REM    +2 si /full (Ollama + Python)
set /a TOTAL_SECTIONS=8
if "%MODE_CLEAN_PIP%"=="1" set /a TOTAL_SECTIONS=9
if "%MODE_FULL%"=="1"      set /a TOTAL_SECTIONS=11
set /a SEC=0

REM ---------- Log ----------
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
set "TS=%DATE:/=-%_%TIME::=-%"
set "TS=%TS: =0%"
set "TS=%TS:,=.%"
set "LOG=%TEMP%\tas_uninstall_%TS%.log"
echo ============================================================ > "%LOG%"
echo  TRAINING AI SERVER - Uninstall Log %DATE% %TIME%             >> "%LOG%"
echo  MODE_FULL=%MODE_FULL%  MODE_KEEP=%MODE_KEEP%  MODE_YES=%MODE_YES% >> "%LOG%"
echo ============================================================ >> "%LOG%"

REM ---------- Confirmacion ----------
if "%MODE_YES%"=="0" (
    echo.
    echo ============================================================
    echo  TRAINING AI SERVER - DESINSTALACION
    echo ============================================================
    echo  Se eliminara:
    echo    [X] Aplicacion en %INSTALL_ROOT%
    echo    [X] Datos de usuario en %USER_DATA% ^(incluye chroma_db^)
    echo    [X] Acceso directo del escritorio
    echo    [X] Reglas de firewall puerto 5000
    echo    [X] Entradas del registro
    if "%MODE_KEEP%"=="0" (
        echo    [X] Modelos Ollama en %OLLAMA_DIR%
    ) else (
        echo    [-] Modelos Ollama: SE CONSERVAN ^(/keep-models^)
    )
    if "%MODE_CLEAN_PIP%"=="1" (
        echo    [X] Paquetes pip ^(chromadb, faster-whisper, flask, etc.^)
    ) else (
        echo    [-] Paquetes pip: SE CONSERVAN ^(usa /clean-pip o /full para borrarlos^)
    )
    if "%MODE_FULL%"=="1" (
        echo    [X] Aplicacion Ollama
        echo    [X] Python 3.13
    ) else (
        echo    [-] Ollama y Python: SE CONSERVAN ^(usa /full para borrarlos^)
    )
    echo.
    set /p "CONFIRM=Continuar? (S/N): "
    if /I not "!CONFIRM!"=="S" if /I not "!CONFIRM!"=="Y" (
        echo Cancelado por el usuario.
        pause
        exit /b 0
    )
)

REM ============================================================
set /a SEC+=1
call :sec "DETENER PROCESOS"
REM ============================================================
REM    Filtramos por linea de comando (no solo titulo de ventana) para
REM    cazar launcher.py / offline_server.py aunque se hayan lanzado
REM    desde un venv o sin titulo. Solo matamos procesos que claramente
REM    pertenecen a TRAINING AI SERVER.
call :info "Buscando procesos relacionados..."
powershell -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name='python.exe' OR Name='pythonw.exe'\" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'AI-Server|launcher\.py|offline_server\.py' } | ForEach-Object { Write-Host ('  kill PID ' + $_.ProcessId + ' ' + $_.Name); Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >> "%LOG%" 2>&1
call :ok "Procesos python/pythonw del servidor detenidos"

taskkill /F /IM ollama.exe >nul 2>&1
call :ok "ollama.exe detenido (si estaba activo)"

REM Liberar puerto 5000 si algo aun escucha
for /f "tokens=5" %%P in ('netstat -ano 2^>nul ^| findstr /R /C:":5000 .*LISTENING"') do (
    taskkill /F /PID %%P >nul 2>&1
    call :ok "PID %%P liberado de puerto 5000"
)
call :bar 1 1 "Procesos detenidos"

REM ============================================================
set /a SEC+=1
call :sec "MODELOS OLLAMA"
REM ============================================================
if "%MODE_KEEP%"=="1" (
    call :skip "Modelos conservados (/keep-models)"
    call :bar 1 1 "Modelos (conservados)"
) else (
    where ollama >nul 2>&1
    if errorlevel 1 (
        call :skip "Ollama no disponible (saltando rm de modelos)"
        call :bar 1 1 "Modelos"
    ) else (
        call :info "Listando modelos instalados..."
        REM Contar modelos para mostrar progreso
        set /a OLA_TOTAL=0
        for /f "skip=1 tokens=1" %%M in ('ollama list 2^>nul') do (
            if not "%%M"=="" set /a OLA_TOTAL+=1
        )
        if !OLA_TOTAL!==0 (
            call :skip "Sin modelos para eliminar"
            call :bar 1 1 "Modelos"
        ) else (
            set /a OLA_STEP=0
            for /f "skip=1 tokens=1" %%M in ('ollama list 2^>nul') do (
                if not "%%M"=="" (
                    set /a OLA_STEP+=1
                    call :info "[!OLA_STEP!/!OLA_TOTAL!] Eliminando %%M..."
                    ollama rm %%M >> "%LOG%" 2>&1
                    if errorlevel 1 ( call :fail "ollama rm %%M" ) else ( call :ok "Modelo %%M eliminado" )
                    call :bar !OLA_STEP! !OLA_TOTAL! "%%M"
                )
            )
        )
    )
)

REM ============================================================
set /a SEC+=1
call :sec "ACCESOS DIRECTOS Y MENU INICIO"
REM ============================================================
set /a STEP=0
set /a STEPS=4
call :delfile "%DESK_ALL%\TRAINING AI SERVER.lnk"
call :delfile "%DESK_USR%\TRAINING AI SERVER.lnk"
call :delfile "%DESK_ALL%\VR Training AI Server.lnk"
call :deldir  "%STARTMENU%"

REM ============================================================
set /a SEC+=1
call :sec "REGLAS DE FIREWALL"
REM ============================================================
set /a STEP=0
set /a STEPS=4
call :delfw "TRAINING AI SERVER"
call :delfw "TRAINING AI SERVER In"
call :delfw "VR Manual Server"
call :delfw "VR Manual Server Out"

REM ============================================================
set /a SEC+=1
call :sec "REGISTRO Y EXCLUSIONES DEFENDER"
REM ============================================================
reg delete "HKLM\SOFTWARE\VR Training AI Server" /f                                                  >nul 2>&1 & call :ok "HKLM\SOFTWARE\VR Training AI Server"
reg delete "HKCU\SOFTWARE\VR Training AI Server" /f                                                  >nul 2>&1 & call :ok "HKCU\SOFTWARE\VR Training AI Server"
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VR Training AI Server" /f       >nul 2>&1 & call :ok "Uninstall key"
powershell -NoProfile -Command "try { Remove-MpPreference -ExclusionPath 'C:\AI-Server' -ErrorAction SilentlyContinue; Remove-MpPreference -ExclusionProcess 'python.exe' -ErrorAction SilentlyContinue; Remove-MpPreference -ExclusionProcess 'ollama.exe' -ErrorAction SilentlyContinue } catch {}" >> "%LOG%" 2>&1
call :ok "Exclusiones Defender removidas (si existian)"
call :bar 1 1 "Registro y Defender"

REM ============================================================
set /a SEC+=1
call :sec "DATOS DE USUARIO (chroma_db)"
REM ============================================================
set /a STEP=0
set /a STEPS=2
call :rmtree "%USER_DATA%"
if "%MODE_KEEP%"=="1" (
    call :skip "[!STEP!/!STEPS!] %OLLAMA_DIR% conservado (/keep-models)"
    set /a STEP+=1
    call :bar !STEP! !STEPS! "Datos de usuario"
) else (
    call :rmtree "%OLLAMA_DIR%"
)

REM ============================================================
set /a SEC+=1
call :sec "ARCHIVOS DE LA APLICACION"
REM ============================================================
if exist "%INSTALL_ROOT%" (
    rd /s /q "%INSTALL_ROOT%" >> "%LOG%" 2>&1
    if exist "%INSTALL_ROOT%" (
        call :info "Algunos archivos estan bloqueados. Forzando permisos..."
        takeown /f "%INSTALL_ROOT%" /r /d y           >nul 2>&1
        icacls  "%INSTALL_ROOT%" /grant administrators:F /t >nul 2>&1
        rd /s /q "%INSTALL_ROOT%" >> "%LOG%" 2>&1
    )
    if exist "%INSTALL_ROOT%" (
        call :fail "%INSTALL_ROOT% no se pudo eliminar (reinicia y vuelve a intentar)"
    ) else (
        call :ok "%INSTALL_ROOT% eliminado"
    )
) else (
    call :skip "%INSTALL_ROOT% no existe"
)
call :bar 1 1 "Archivos de aplicacion"

REM ============================================================
if "%MODE_CLEAN_PIP%"=="1" (
    set /a SEC+=1
    call :sec "PAQUETES PIP DEL SERVIDOR"
    py -3.13 --version >nul 2>&1
    if errorlevel 1 (
        call :skip "Python 3.13 no disponible (omitiendo pip uninstall)"
        call :bar 1 1 "Pip"
    ) else (
        set /a PIP_TOTAL=14
        set /a PIP_STEP=0
        call :pip_uninstall "chromadb"
        call :pip_uninstall "faster-whisper"
        call :pip_uninstall "ctranslate2"
        call :pip_uninstall "tokenizers"
        call :pip_uninstall "huggingface-hub"
        call :pip_uninstall "av"
        call :pip_uninstall "ollama"
        call :pip_uninstall "flask-cors"
        call :pip_uninstall "flask"
        call :pip_uninstall "PyPDF2"
        call :pip_uninstall "colorama"
        call :pip_uninstall "requests"
        call :pip_uninstall "cryptography"
        call :pip_uninstall "numpy"
    )
)

REM ============================================================
if "%MODE_FULL%"=="1" (
    set /a SEC+=1
    call :sec "DESINSTALAR OLLAMA"
    where winget >nul 2>&1
    if errorlevel 1 (
        call :skip "winget no disponible (omitiendo Ollama)"
    ) else (
        call :info "Ejecutando winget uninstall Ollama.Ollama..."
        winget uninstall -e --id Ollama.Ollama --silent >> "%LOG%" 2>&1
        where ollama >nul 2>&1
        if errorlevel 1 ( call :ok "Ollama desinstalado" ) else ( call :fail "Ollama sigue presente" )
    )
    call :bar 1 1 "Ollama"
)

REM ============================================================
if "%MODE_FULL%"=="1" (
    set /a SEC+=1
    call :sec "DESINSTALAR PYTHON 3.13"
    where winget >nul 2>&1
    if errorlevel 1 (
        call :skip "winget no disponible (omitiendo Python)"
    ) else (
        call :info "Ejecutando winget uninstall Python.Python.3.13..."
        winget uninstall -e --id Python.Python.3.13 --silent >> "%LOG%" 2>&1
        py -3.13 --version >nul 2>&1
        if errorlevel 1 ( call :ok "Python 3.13 desinstalado" ) else ( call :fail "Python 3.13 sigue presente" )
    )
    call :bar 1 1 "Python"
)

REM ============================================================
set /a SEC+=1
call :sec "LIMPIEZA RESIDUAL"
REM ============================================================
REM    Pasada final: borra rutas heredadas (variantes antiguas del
REM    nombre del producto), residuos en %APPDATA%/%LOCALAPPDATA%, y
REM    vuelve a intentar la raiz por si quedo algo bloqueado antes.
REM    Asi el disco queda LIMPIO sin importar de que version se venga.
set /a STEP=0
set /a STEPS=8
call :rmtree "%ProgramFiles%\TRAINING AI SERVER"
call :rmtree "%ProgramFiles(x86)%\TRAINING AI SERVER"
call :rmtree "%APPDATA%\TRAINING AI SERVER"
call :rmtree "%APPDATA%\VR Training AI Server"
call :rmtree "%LOCALAPPDATA%\VR Training AI Server"
call :rmtree "%PUBLIC%\TRAINING AI SERVER"
call :rmtree "%INSTALL_ROOT%"
call :clean_temp_files

REM ============================================================
call :hdr "VERIFICACION FINAL"
REM ============================================================
if exist "%INSTALL_ROOT%"                                                  ( echo   [FAIL] %INSTALL_ROOT% sigue presente )         else ( echo   [ OK ] %INSTALL_ROOT% eliminado )
if exist "%USER_DATA%"                                                     ( echo   [FAIL] %USER_DATA% sigue presente )            else ( echo   [ OK ] %USER_DATA% eliminado )
if exist "%ProgramFiles%\TRAINING AI SERVER"                               ( echo   [FAIL] %ProgramFiles%\TRAINING AI SERVER persiste ) else ( echo   [ OK ] %ProgramFiles%\TRAINING AI SERVER eliminado )
if exist "%APPDATA%\TRAINING AI SERVER"                                    ( echo   [FAIL] %APPDATA%\TRAINING AI SERVER persiste )      else ( echo   [ OK ] %APPDATA%\TRAINING AI SERVER eliminado )
if exist "%APPDATA%\VR Training AI Server"                                 ( echo   [FAIL] %APPDATA%\VR Training AI Server persiste )   else ( echo   [ OK ] %APPDATA%\VR Training AI Server eliminado )
if exist "%LOCALAPPDATA%\VR Training AI Server"                            ( echo   [FAIL] %LOCALAPPDATA%\VR Training AI Server persiste ) else ( echo   [ OK ] %LOCALAPPDATA%\VR Training AI Server eliminado )
if exist "%DESK_ALL%\TRAINING AI SERVER.lnk"                               ( echo   [FAIL] Acceso directo persiste )               else ( echo   [ OK ] Acceso directo eliminado )
if exist "%DESK_USR%\TRAINING AI SERVER.lnk"                               ( echo   [FAIL] Acceso directo de usuario persiste )    else ( echo   [ OK ] Acceso directo de usuario eliminado )
if exist "%STARTMENU%"                                                     ( echo   [FAIL] Carpeta Start Menu persiste )           else ( echo   [ OK ] Start Menu eliminado )
netstat -ano | findstr :5000 >nul                                          && echo   [FAIL] Puerto 5000 aun en uso                  || echo   [ OK ] Puerto 5000 libre
netsh advfirewall firewall show rule name="TRAINING AI SERVER" >nul 2>&1   && echo   [FAIL] Regla firewall persiste                  || echo   [ OK ] Regla firewall eliminada
reg query "HKLM\SOFTWARE\VR Training AI Server" >nul 2>&1                  && echo   [FAIL] Clave registro persiste                  || echo   [ OK ] Clave registro eliminada
if "%MODE_KEEP%"=="0" (
    if exist "%OLLAMA_DIR%"                                                ( echo   [FAIL] %OLLAMA_DIR% sigue presente )           else ( echo   [ OK ] %OLLAMA_DIR% eliminado )
)
if "%MODE_CLEAN_PIP%"=="1" (
    py -3.13 -m pip show chromadb >nul 2>&1                                && echo   [FAIL] chromadb pip aun presente                || echo   [ OK ] chromadb pip eliminado
)

:end
echo.
echo ============================================================
echo  RESUMEN DESINSTALACION
echo    OK     : !CNT_OK!
echo    SKIP   : !CNT_SKIP!
echo    FAIL   : !CNT_FAIL!
echo  Log: %LOG%
echo ============================================================
echo.
if "%MODE_YES%"=="0" pause
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

:delfile
set /a STEP+=1
if exist "%~1" (
    del /F /Q "%~1" >nul 2>&1
    if exist "%~1" ( call :fail "[!STEP!/!STEPS!] No se pudo borrar %~1" ) else ( call :ok "[!STEP!/!STEPS!] %~1 eliminado" )
) else (
    call :skip "[!STEP!/!STEPS!] %~1 no existe"
)
call :bar !STEP! !STEPS! "%~nx1"
goto :eof

:deldir
set /a STEP+=1
if exist "%~1" (
    rd /s /q "%~1" >nul 2>&1
    if exist "%~1" ( call :fail "[!STEP!/!STEPS!] No se pudo borrar %~1" ) else ( call :ok "[!STEP!/!STEPS!] %~1 eliminado" )
) else (
    call :skip "[!STEP!/!STEPS!] %~1 no existe"
)
call :bar !STEP! !STEPS! "%~nx1"
goto :eof

:rmtree
set /a STEP+=1
if exist "%~1" (
    rd /s /q "%~1" >> "%LOG%" 2>&1
    if exist "%~1" (
        takeown /f "%~1" /r /d y          >nul 2>&1
        icacls  "%~1" /grant administrators:F /t >nul 2>&1
        rd /s /q "%~1" >> "%LOG%" 2>&1
    )
    if exist "%~1" ( call :fail "[!STEP!/!STEPS!] %~1 sigue presente" ) else ( call :ok "[!STEP!/!STEPS!] %~1 eliminado" )
) else (
    call :skip "[!STEP!/!STEPS!] %~1 no existe"
)
call :bar !STEP! !STEPS! "%~nx1"
goto :eof

:delfw
set /a STEP+=1
netsh advfirewall firewall show rule name="%~1" >nul 2>&1
if errorlevel 1 (
    call :skip "[!STEP!/!STEPS!] Regla %~1 no existe"
) else (
    netsh advfirewall firewall delete rule name="%~1" >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "[!STEP!/!STEPS!] No se pudo borrar regla %~1" ) else ( call :ok "[!STEP!/!STEPS!] Regla %~1 eliminada" )
)
call :bar !STEP! !STEPS! "%~1"
goto :eof

:pip_uninstall
REM %1 = paquete (nombre tal como aparece en 'pip show')
set /a PIP_STEP+=1
py -3.13 -m pip show %~1 >nul 2>&1
if errorlevel 1 (
    call :skip "[!PIP_STEP!/!PIP_TOTAL!] %~1 no instalado"
) else (
    py -3.13 -m pip uninstall -y %~1 >> "%LOG%" 2>&1
    if errorlevel 1 ( call :fail "[!PIP_STEP!/!PIP_TOTAL!] pip uninstall %~1" ) else ( call :ok "[!PIP_STEP!/!PIP_TOTAL!] %~1 desinstalado" )
)
call :bar !PIP_STEP! !PIP_TOTAL! "%~1"
goto :eof

:clean_temp_files
REM Limpia archivos temporales que el instalador/desinstalador pudieran
REM dejar (scripts ps1, .ico de fallback, etc.). NO toca el log activo
REM del desinstalador (tas_uninstall_*.log) para preservar diagnostico.
set /a STEP+=1
del /F /Q "%TEMP%\tas_make_shortcut_*.ps1" >nul 2>&1
del /F /Q "%TEMP%\tas_*.ps1"                >nul 2>&1
del /F /Q "%TEMP%\tas_install_*.log"        >nul 2>&1
call :ok "[!STEP!/!STEPS!] Temporales tas_*.ps1 / tas_install_*.log eliminados"
call :bar !STEP! !STEPS! "tas_*"
goto :eof
