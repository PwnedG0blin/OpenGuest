# Run only inside the Stratovo Windows VM, as Administrator.
$ErrorActionPreference = 'Stop'
$driver = Join-Path $PSScriptRoot 'drivers\viogpu3d\viogpu3d.inf'
if (-not (Test-Path -LiteralPath $driver)) { throw 'Grafiktreiber fehlt auf dieser DVD.' }
Write-Host 'Installiere den experimentellen ARM64-Grafiktreiber in diesem Windows.'
& pnputil.exe /add-driver $driver /install
if ($LASTEXITCODE -notin @(0, 3010)) { throw "Treiberinstallation fehlgeschlagen: $LASTEXITCODE" }
Write-Host 'Windows jetzt vollständig herunterfahren und erneut über das Stratovo starten.'
Write-Host 'Secure Boot bleibt eingeschaltet. Keine Signaturprüfung oder Testsicherheitsoption wird geändert.'
