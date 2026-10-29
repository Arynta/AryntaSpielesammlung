@echo off
rem Startet den Frontend-Dev-Server: Abhaengigkeiten aktualisieren, dann "npm run dev".
rem Aufruf aus dem Projektordner: .\devserver.bat

rem In den frontend-Ordner neben dieser Datei wechseln, egal von wo aus das Skript gestartet wird
cd /d "%~dp0frontend" || exit /b 1

echo.
echo === Abhaengigkeiten aktualisieren (npm install) ===
call npm install --no-audit --no-fund
if errorlevel 1 (
    echo npm install ist fehlgeschlagen.
    exit /b 1
)

echo.
echo === Dev-Server starten: http://localhost:5173 (beenden mit Strg+C) ===
call npm run dev
