@echo off
rem Startet das Flutter-Frontend im Browser: Spieldaten und Bilder kopieren, dann "flutter run".
rem Aufruf aus dem Projektordner: .\devserver.bat
rem Weitere Optionen werden an flutter run weitergereicht, z. B.:
rem   .\devserver.bat --dart-define=MAPILLARY_TOKEN="MLY|..."

rem In den app-Ordner neben dieser Datei wechseln, egal von wo aus das Skript gestartet wird
cd /d "%~dp0app" || exit /b 1

echo.
echo === Spieldaten und Bilder kopieren (tool/sync_assets.dart) ===
call dart run tool/sync_assets.dart
if errorlevel 1 (
    echo Kopieren der Spieldaten ist fehlgeschlagen.
    exit /b 1
)

echo.
echo === Flutter starten: http://localhost:5173 (beenden mit q) ===
rem Web-Server statt "-d chrome": Die Debug-Verbindung zu Chrome bricht auf diesem Rechner ab
rem (AppConnectionException). Der Browser lädt die Seite, sobald Flutter fertig gebaut hat.
start "" http://localhost:5173
call flutter run -d web-server --web-port 5173 %*
