@echo off
fltmc >nul 2>&1
if errorlevel 1 (
  powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
echo Stratovo: Experimenteller Grafiktreiber fuer die Windows-TESTKOPIE
pnputil.exe /add-driver "%~dp0drivers\viogpu3d\viogpu3d.inf" /install
set "pk_code=%errorlevel%"
if "%pk_code%"=="0" goto ready
if "%pk_code%"=="3010" goto ready
echo Treiberinstallation fehlgeschlagen: %pk_code%
echo Secure Boot und Signaturpruefung bleiben unveraendert.
pause
exit /b %pk_code%
:ready
echo Fertig. Test-Windows herunterfahren und danach in Stratovo erneut starten.
pause
