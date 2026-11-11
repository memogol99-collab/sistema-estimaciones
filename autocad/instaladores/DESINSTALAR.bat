@echo off
setlocal
title MEMO SISTEMA - Desinstalar
echo Cierre AutoCAD antes de continuar.
pause
for %%D in ("%ProgramFiles%\Autodesk\ApplicationPlugins" "%APPDATA%\Autodesk\ApplicationPlugins") do (
  if exist "%%~D\MEMO_SISTEMA.bundle" (
    rmdir /s /q "%%~D\MEMO_SISTEMA.bundle" && echo Eliminado de %%~D
  )
)
echo Listo.
pause
