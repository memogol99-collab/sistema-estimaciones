@echo off
setlocal
title MemoPRO - Desinstalar
echo Cierre AutoCAD antes de continuar.
pause
for %%D in ("%ProgramFiles%\Autodesk\ApplicationPlugins" "%APPDATA%\Autodesk\ApplicationPlugins" "%ProgramData%\Autodesk\ApplicationPlugins") do (
  for %%B in ("MemoPRO.bundle" "MEMO_SISTEMA.bundle") do (
    if exist "%%~D\%%~B" (
      rmdir /s /q "%%~D\%%~B" && echo Eliminado: %%~D\%%~B
    )
  )
)
echo Listo.
pause
