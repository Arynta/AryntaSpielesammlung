# Arynta Spielesammlung

Kleine Webseite für Spieleabende: Jeder öffnet sie auf dem Handy, tritt mit einem
vierstelligen Code einem Raum bei, und die Spielleitung wählt ein Spiel aus. Der Server
verteilt Rollen, Wörter und Karten. Gesprochen wird ganz normal am Tisch.

Wer keinen Server braucht, spielt im lokalen Modus: ein Handy, das reihum weitergegeben
wird. Der läuft komplett im Browser.

```
├── backend/     Spring Boot 4 (Java 21), WebSocket unter /ws
│   └── src/main/resources/games/   Rollen, Wörter, Tabu-Karten, Fragen (JSON)
├── frontend/    Vite + TypeScript, ohne Framework (ist online)
├── app/         Dieselbe Oberfläche in Flutter (noch nicht online, siehe app/README.md)
├── assets/      Bilder: Werwolf-Karte, Startbild, Bilder für Impostor
├── render.yaml  Deployment des Backends auf Render (Free)
└── devserver.bat  Startet den Frontend-Dev-Server unter Windows
```

## Spiele

| Spiel | ab Spielern | Worum es geht |
| --- | --- | --- |
| Werwolf | 4 | Rollen werden geheim verteilt, die Spielleitung schaltet zwischen Nacht und Tag um. Anzahl der Werwölfe und Sonderrollen sind einstellbar. |
| Impostor | 3 | Alle kennen dasselbe Wort, nur der Impostor nicht. Danach wird abgestimmt. |
| Tabu | 4 | Zwei Teams, Begriffe erklären ohne die verbotenen Wörter, mit Zeitlimit und Buzzer. |
| Nobody is Perfect | 3 | Jeder erfindet eine Antwort auf eine kuriose Frage, dann wird die echte gesucht. |
| Buzzer | 2 | Werkzeug fürs Quiz: Wer zuerst drückt, ist dran. |

Was für alle Spiele gilt:

- Wer den Raum erstellt, ist Spielleitung. Geht sie in der Lobby, übernimmt der Nächste.
- Die Spielleitung kann in der Lobby Spieler entfernen und ein Spielerlimit setzen (höchstens 20).
- Jeder sieht nur seine eigenen geheimen Infos.
- Seite neu laden oder Handy sperren: man landet wieder im selben Raum.
- Wer die Verbindung verliert, wird als "offline" angezeigt.
- Räume ohne Aktivität werden nach 6 Stunden gelöscht.

## Lokal starten

Backend (braucht Java 21 und Maven, oder einfach in IntelliJ öffnen):

```bash
cd backend
mvn spring-boot:run
```

Frontend:

```bash
cd frontend
npm install
npm run dev
```

Unter Windows erledigt `.\devserver.bat` im Projektordner beide Frontend-Schritte.

Dann http://localhost:5173 öffnen. `npm run dev` startet mit `--host`, damit du die
Seite auch vom Handy im selben WLAN aufrufen kannst (Adresse steht im Terminal).
Dafür musst du in `frontend/.env.local` die IP deines Rechners eintragen,
z. B. `VITE_BACKEND_URL=ws://192.168.0.23:8080/ws`, und beim Backend
`ALLOWED_ORIGINS=http://192.168.0.23:5173` setzen.

Zum Testen mit mehreren Spielern reichen mehrere private Browserfenster.

## Flutter-Version (`app/`)

Die Seite wird gerade nach Flutter übertragen. Online ist weiterhin `frontend/`. Bis zur
Umstellung gehören Änderungen an der Oberfläche in beide Ordner. Wie die App aufgebaut ist
und wo du dort weiterbaust, steht in [app/README.md](app/README.md).

Spieldaten und Bilder bleiben, wo sie sind. Ein Skript kopiert sie vor dem
Starten, Testen und Bauen nach `app/assets/game/` (steht in `.gitignore`). Nach einer
Änderung an den JSON-Dateien oder Bildern also erneut aufrufen:

```bash
cd app
flutter pub get
dart run tool/sync_assets.dart
flutter run -d chrome --web-port 5173
```

Das Backend muss laufen. Mit `--web-port 5173` passt die Adresse zur Voreinstellung von
`ALLOWED_ORIGINS`. Eine andere Backend-Adresse setzt du mit
`--dart-define=BACKEND_URL=wss://…/ws`.

Geo-Bingo braucht für die Straßenbilder einen kostenlosen Client-Schlüssel von
[mapillary.com/developer](https://www.mapillary.com/developer):
`--dart-define=MAPILLARY_TOKEN=MLY|…`. Ohne Schlüssel läuft alles andere, Geo-Bingo
zeigt dann nur einen Hinweis. Der Viewer (MapillaryJS 4.1.2, MIT-Lizenz) liegt in
`app/web/mapillary/` und wird erst geladen, wenn jemand Geo-Bingo spielt.

Optional kommen die Bilder von Google Street View, solange Googles Freikontingent reicht.
Dafür braucht die App `--dart-define=GOOGLE_MAPS_KEY=…` und das Backend
`STREET_VIEW_DAILY_LIMIT=150`. Ohne Limit (Vorgabe 0) bleibt alles bei Mapillary.
Einrichtung und Grenzen stehen in [docs/entscheidungen.md](docs/entscheidungen.md), Abschnitt 5.

Release für den Browser:

```bash
flutter build web --release --no-web-resources-cdn --dart-define=BACKEND_URL=wss://…/ws
```

`--no-web-resources-cdn` legt Flutters Zeichen-Engine mit in den Build, damit die Seite
nichts von Google nachlädt. Liegt sie in einem Unterordner (GitHub Pages), kommt noch
`--base-href /Ordnername/` dazu.

Tests:

```bash
flutter test
```

`test/ui/views_test.dart` arbeitet mit Server-Antworten aus `test/fixtures/states.json`.
Ändert sich das Protokoll, erzeugst du sie bei laufendem Backend neu. Das Skript spielt
dabei alle Spiele einmal durch. Es schickt viel schneller als ein Mensch, deshalb das Backend
dafür mit `MAX_MESSAGES_PER_SECOND=1000` und `LOCKED_GAMES=` (leer, sonst fehlt Geo-Bingo) starten:

```bash
dart run tool/record_states.dart ws://localhost:8080/ws
```

Noch offen: Emoji und nicht-lateinische Schriften (z. B. Kyrillisch) erscheinen als
Kästchen, weil die Seite keine Ersatzschriften von Google nachlädt. Screenreader müssen
bei Flutter Web die Bedienhilfen erst über den unsichtbaren Knopf der Seite einschalten.

## Kostenlos online stellen

1. Projekt auf GitHub pushen.
2. **Backend auf Render:** render.com → New → Blueprint → Repo wählen. Render baut das
   Dockerfile in `backend/`. Danach hast du eine Adresse wie
   `https://arynta-spielesammlung.onrender.com`. Neue Versionen deployt Render erst,
   wenn die Tests auf GitHub grün sind.
3. **Frontend auf GitHub Pages:** Unter Settings → Pages als Quelle "GitHub Actions"
   wählen. Unter Settings → Secrets and variables → Actions → Variables die Variable
   `VITE_BACKEND_URL` anlegen, z. B. `wss://arynta-spielesammlung.onrender.com/ws`.
   Für Geo-Bingo dort auch `MAPILLARY_TOKEN` mit dem Mapillary-Client-Schlüssel anlegen,
   für Google Street View zusätzlich `GOOGLE_MAPS_KEY` (siehe Schritt 6).
   Der Workflow `.github/workflows/pages.yml` baut und veröffentlicht das Frontend bei
   jedem Push auf `main`, der das Frontend, die Spieldaten oder die Bilder ändert.
4. Bei Render unter Environment `ALLOWED_ORIGINS` auf die Adresse des Frontends
   setzen (die steht nach dem ersten Lauf unter Settings → Pages) und neu deployen.
   Mehrere Adressen gehen kommagetrennt.
5. Geo-Bingo ist in der Lobby vorerst mit „Bald verfügbar“ gesperrt
   (`app.locked-games=GEO_BINGO`). Zum Freischalten bei Render unter Environment
   `LOCKED_GAMES` mit leerem Wert anlegen und neu deployen.
6. **Google Street View für Geo-Bingo (optional, bleibt kostenlos):**
   1. In der [Google Cloud Console](https://console.cloud.google.com/) ein Projekt anlegen und
      ein Rechnungskonto verknüpfen (Google verlangt eine Karte, berechnet wird aber nichts,
      solange die Grenzen unten stehen).
   2. Unter APIs & Services nur **Maps JavaScript API** und **Street View Static API**
      aktivieren.
   3. Ein eigenes Tageskontingent für Dynamic Street View bietet Google nicht an (Stand
      November 2026, Google Maps Platform → Quotas zeigt keins). Im 90-tägigen Testzeitraum
      bucht Google ohnehin nichts ab. Vor dem Upgrade auf ein normales Konto eine automatische
      Abschaltung der Abrechnung über das Budget einrichten (siehe docs/entscheidungen.md, 5.2).
   4. Unter Credentials einen API-Schlüssel anlegen, auf **Websites** mit der Adresse von
      GitHub Pages beschränken (`https://arynta.github.io/AryntaSpielesammlung/*`) und nur die
      beiden APIs oben erlauben. Für lokale Tests zusätzlich `http://localhost:5173/*`.
   5. Unter Billing → Budgets & alerts ein Budget von 1 € mit Alarm anlegen.
   6. Den Schlüssel in GitHub als Variable `GOOGLE_MAPS_KEY` anlegen und bei Render
      `STREET_VIEW_DAILY_LIMIT=150` setzen.

Der kostenlose Render-Server schläft nach 15 Minuten ohne Besucher ein. Wer als Erstes
die Seite öffnet, sieht dann "Der Server wird geweckt" und wartet bis zu einer Minute.
Beim Einschlafen gehen offene Räume verloren, während eines Spiels passiert das aber
nicht, weil die Handys die Verbindung aktiv halten.

## Wo du weiterbaust

Warum Dinge so gebaut sind (Sprachen, Sicherheitsgrenzen, Layout) und was bewusst offen ist, steht in
[docs/entscheidungen.md](docs/entscheidungen.md).

| Was | Wo |
| --- | --- |
| Rollen, Impostor-Wörter, Tabu-Karten, Fragen | JSON-Dateien in `backend/src/main/resources/games/`. Das Frontend liest dieselben Dateien (`gameData.ts`), es gibt also nur eine Liste. |
| Englische Fassung | Spieldaten: dieselben Dateien mit `-en` (`tabu-cards-en.json` usw.). Texte der Flutter-App: `app/lib/l10n/app_de.arb` und `app_en.arb`. Meldungen des Servers: `backend/src/main/resources/i18n/messages*.properties`. Impressum und Datenschutz: `app/lib/ui/legal/content/`, maßgeblich ist die deutsche Fassung. Die Flagge oben rechts schaltet um. |
| Regeln der Werwolf-Verteilung | `RoleDistribution.java`, `WerwolfRoles.java` |
| Ablauf eines Spiels | die Klasse des Spiels, z. B. `TabuGame.java`, und die passenden Methoden in `Room` |
| Nachrichten zwischen Handy und Server | `ClientMessage.java`, `GameSocketHandler.handle()` und `types.ts` (beide Seiten gleich halten) |
| Lokaler Modus | `localGames.ts` (Regeln, mit Tests) und `localMode.ts` (Ansicht) |
| Aussehen | `frontend/src/style.css`, die Farben hängen an `body[data-phase=…]` |

Ein neues Spiel einbauen:

1. In `GameType` einen Eintrag mit Name, Mindestzahl an Spielern und Beschreibung anlegen.
2. Eine Klasse schreiben, die `Game` implementiert, und sie in `Game` bei `permits`
   ergänzen. In `Room.start()` den neuen Fall einbauen.
3. Für jede Aktion eine Methode in `Room` schreiben und testen (`TabuTest.java` oder
   `BuzzerTest.java` zeigen, wie), dann in `GameSocketHandler.handle()` einen Fall
   `case "…" ->` ergänzen. Neue Felder kommen in `ClientMessage` und in `types.ts`.
4. Die Ansicht pro Spieler in `RoomView` und `Room.viewFor()` ergänzen.
5. Im Frontend eine Datei wie `onlineBuzzer.ts` anlegen, Knöpfe mit `data-action`
   einbauen und in `act()` in `main.ts` die Nachricht senden.

`Room.viewFor()` baut die Ansicht für jeden Spieler einzeln. Alles Geheime gehört nur
in die Teile, die für genau diesen Spieler gebaut werden (das Feld `you` und das
`viewFor(playerId)` des jeweiligen Spiels), damit es nie bei anderen Spielern landet.

## Tests

```bash
cd backend && mvn test
cd frontend && npm test
```

Beide laufen auch auf GitHub bei jedem Push (`.github/workflows/tests.yml`).
