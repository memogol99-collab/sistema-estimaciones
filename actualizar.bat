@echo off
rem Actualiza los reportes con los chats de la carpeta whatsapp\ (doble clic para ejecutar)
cd /d "%~dp0"
python whatsapp_resumen.py whatsapp\ --nombre "Barrio V"
if errorlevel 1 (
  echo.
  echo Hubo un error. Revisa que Python este instalado y que hayas corrido una vez: pip install -r requirements.txt
  pause
  exit /b 1
)
start "" "reportes_whatsapp\resumen_Barrio V.html"
start "" "reportes_whatsapp"
pause
