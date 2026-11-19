@echo off
setlocal
title MEMO SISTEMA - Instalador
echo ============================================================
echo   MEMO SISTEMA - Instalacion (Autoloader de AutoCAD)
echo ============================================================
echo.
set "ORIGEN=%~dp0MEMO_SISTEMA.bundle"
if not exist "%ORIGEN%\PackageContents.xml" (
  echo No se encontro la carpeta MEMO_SISTEMA.bundle junto a este archivo.
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
  echo AutoCAD puede preguntar si confia en los archivos: elija "Cargar siempre".
  echo Para evitarlo, cierre esta ventana y use clic derecho ^> Ejecutar como administrador.
)
echo.
echo Cierre AutoCAD antes de continuar.
pause

echo Quitando copias anteriores del MEMO SISTEMA...
set "QUEDAN="
for %%D in ("%APPDATA%\Autodesk\ApplicationPlugins" "%ProgramFiles%\Autodesk\ApplicationPlugins" "%ProgramData%\Autodesk\ApplicationPlugins") do (
  if exist "%%~D\MEMO_SISTEMA.bundle" (
    rmdir /s /q "%%~D\MEMO_SISTEMA.bundle" 2>nul
    if exist "%%~D\MEMO_SISTEMA.bundle" (
      echo   NO se pudo borrar: %%~D\MEMO_SISTEMA.bundle
      set "QUEDAN=1"
    ) else (
      echo   Borrada: %%~D\MEMO_SISTEMA.bundle
    )
  )
)
if defined QUEDAN (
  echo.
  echo   Queda una copia vieja que requiere permisos de administrador.
  echo   Ejecute INSTALAR.bat con clic derecho ^> Ejecutar como administrador.
  echo.
)
if not exist "%DESTINO%" mkdir "%DESTINO%"
xcopy "%ORIGEN%" "%DESTINO%\MEMO_SISTEMA.bundle\" /E /I /Q /Y >nul
if errorlevel 1 (
  echo ERROR al copiar los archivos.
  pause
  exit /b 1
)
echo.
echo Instalado en: %DESTINO%\MEMO_SISTEMA.bundle
echo.
echo Siguientes pasos:
echo   1. Abra AutoCAD. Apareceran las fichas MEMO Estimaciones, MEMO Topografia y MEMO Dibujo.
echo   2. Si tenia el menu anterior Memo.cuix, escriba una sola vez:  MEMO_QUITAR_ANTERIOR
echo   3. Quite los LISP viejos de APPLOAD ^> Conjunto de inicio ^(Startup Suite^) si los tenia ahi.
echo   4. Escriba MEMO_AYUDA para ver todos los comandos.
echo.
pause
