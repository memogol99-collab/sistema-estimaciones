@echo off
setlocal
title MemoPRO - Instalador
echo ============================================================
echo   MemoPRO - Instalacion (Autoloader de AutoCAD)
echo ============================================================
echo.
set "ORIGEN=%~dp0MemoPRO.bundle"
if not exist "%ORIGEN%\PackageContents.xml" (
  echo No se encontro la carpeta MemoPRO.bundle junto a este archivo.
  echo Descomprima TODO el ZIP antes de ejecutar INSTALAR.bat
  pause
  exit /b 1
)

net session >nul 2>&1
if %errorlevel%==0 (
  set "DESTINO=%ProgramFiles%\Autodesk\ApplicationPlugins"
  echo Ejecutando como administrador: se instala en Program Files
  echo ^(ubicacion de confianza: AutoCAD no mostrara avisos de seguridad^).
) else (
  set "DESTINO=%APPDATA%\Autodesk\ApplicationPlugins"
  echo Sin permisos de administrador: se instala en su perfil de usuario.
  echo Si hay una copia anterior en Program Files NO se podra borrar.
  echo Recomendado: cierre esta ventana y use clic derecho ^> Ejecutar como administrador.
)
echo.
echo Cierre AutoCAD antes de continuar.
pause

echo Quitando copias anteriores (MemoPRO y MEMO_SISTEMA)...
set "QUEDAN="
for %%D in ("%APPDATA%\Autodesk\ApplicationPlugins" "%ProgramFiles%\Autodesk\ApplicationPlugins" "%ProgramData%\Autodesk\ApplicationPlugins") do (
  for %%B in ("MemoPRO.bundle" "MEMO_SISTEMA.bundle") do (
    if exist "%%~D\%%~B" (
      rmdir /s /q "%%~D\%%~B" 2>nul
      if exist "%%~D\%%~B" (
        echo   NO se pudo borrar: %%~D\%%~B
        set "QUEDAN=1"
      ) else (
        echo   Borrada: %%~D\%%~B
      )
    )
  )
)
if defined QUEDAN (
  echo.
  echo   Queda una copia anterior que requiere permisos de administrador.
  echo   Ejecute INSTALAR.bat con clic derecho ^> Ejecutar como administrador.
  echo.
)
if not exist "%DESTINO%" mkdir "%DESTINO%"
xcopy "%ORIGEN%" "%DESTINO%\MemoPRO.bundle\" /E /I /Q /Y >nul
if errorlevel 1 (
  echo ERROR al copiar los archivos.
  pause
  exit /b 1
)
echo.
echo Instalado en: %DESTINO%\MemoPRO.bundle
echo.
echo Siguientes pasos:
echo   1. Abra AutoCAD. Apareceran las fichas MemoPRO Estimaciones, MemoPRO Topografia y MemoPRO Dibujo.
echo   2. Escriba una sola vez:  MEMO_QUITAR_ANTERIOR   (descarga los menus viejos MEMO y MEMO_SISTEMA)
echo   3. Quite los LISP viejos de APPLOAD ^> Conjunto de inicio ^(Startup Suite^) si los tenia ahi.
echo   4. En un dibujo nuevo escriba MEMO_VERIFICAR: debe decir "Todo correcto".
echo.
pause
