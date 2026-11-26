# Arynta als Flutter-App

Hier liegt dieselbe Seite wie in `frontend/`, nur in Flutter geschrieben. Sie läuft im
Browser und soll später auch als App für Android und iOS gebaut werden. Starten, testen
und bauen steht im [README im Projektordner](../README.md#flutter-version-app).

## Ordner

Die Struktur folgt dem Architektur-Leitfaden von Flutter
(docs.flutter.dev/app-architecture): Daten, Regeln und Oberfläche liegen getrennt, die
Oberfläche ist nach Bereichen geordnet, und `test/` spiegelt `lib/`.

```
lib/
├── main.dart                 Startpunkt: lädt die Spieldaten, liest BACKEND_URL, startet die App
├── data/                     Alles, was von außen kommt
│   ├── repositories/         game_data.dart: Rollen, Wörter, Bildpfade
│   └── services/             connection.dart (WebSocket), device/ und storage/
├── domain/                   Datenmodelle und Spielregeln, ohne Oberfläche
│   ├── models/               models.dart: Nachrichten und Zustand, wie im Backend
│   └── rules/                local_games.dart: Regeln des lokalen Modus
└── ui/
    ├── core/                 Was mehrere Bereiche brauchen
    │   ├── app.dart          Rahmen der App und Wahl der Ansicht
    │   ├── themes/           Farben und Schriften
    │   ├── view_model/       AppController für die Online-Seite
    │   └── widgets/          Gemeinsame Bausteine
    ├── home/widgets/         Startseite
    ├── lobby/widgets/        Lobby
    ├── games/widgets/        Online-Ansichten pro Spiel
    ├── local/                Lokaler Modus: view_model/ und widgets/
    └── legal/widgets/        Impressum und Datenschutz
test/                         gleicher Aufbau wie lib/, dazu helpers/ und fixtures/
tool/                         Hilfsskripte (Daten kopieren, Server-Antworten aufzeichnen)
web/                          index.html, Ladebildschirm, Impressum und Datenschutz als HTML
assets/fonts/                 Schriften und ihre Lizenzen
assets/game/                  Kopien der Spieldaten und Bilder, nicht im Git
```

Ein View-Model (hier `AppController` und `LocalController`) hält den Zustand eines
Bereichs und bietet die Aktionen an. Die Dateien unter `widgets/` zeigen nur an und rufen
beim Tippen das View-Model auf. Im Code innerhalb von `lib/` sind die Imports relativ,
Tests und Skripte importieren über `package:arynta/…`.

## Wie die Teile zusammenspielen

`main.dart` baut einen `AppController` und übergibt ihm die Verbindung zum Backend. Der
Controller hält alles, was die Online-Seite weiß: Verbindungsstatus, den eigenen Raum, die
Eingabefelder und gemeldete Fehler. Jede Aktion der Oberfläche ist eine Methode am
Controller (`create()`, `join()`, `selectGame()`, `startGame()` und so weiter). Sie
schickt eine `ClientMessage` an den Server. Der Server antwortet mit dem neuen Zustand des
Raums, der Controller merkt ihn sich und die Oberfläche baut sich neu auf.

Die Ansichten rechnen also selbst nichts aus. Sie lesen `controller.room` und rufen beim
Tippen eine Methode auf. Welche Ansicht gerade zu sehen ist, entscheidet
`GameScreen._body()` in `ui/core/app.dart` anhand von Raum und Spielphase.

Der lokale Modus läuft ohne Server. Ihn steuert ein eigener `LocalController`, den der
`AppController` anlegt, sobald jemand auf „Lokal“ tippt. Die Regeln dafür stehen in
`domain/rules/local_games.dart` und entsprechen denen im Backend.

## data/, domain/ und die View-Models

| Datei | Inhalt |
| --- | --- |
| `ui/core/view_model/app_controller.dart` | Zustand der Online-Seite und alle Aktionen. Merkt sich Name und Raum im Gerät, damit man nach dem Neuladen wieder im Raum landet. |
| `data/services/connection.dart` | Hält die WebSocket-Verbindung offen, schickt alle 25 Sekunden ein Ping und baut abgebrochene Verbindungen nach 1 bis 10 Sekunden neu auf. Weckt den schlafenden Render-Server über `/health`. |
| `domain/models/models.dart` | Datenmodelle für die Nachrichten von und an den Server. Spiegelt `RoomView`, `GameType` und `Phase` aus dem Backend. |
| `data/repositories/game_data.dart` | Lädt Rollen und Wörter aus `assets/game/`. Hier stehen auch die Bildpfade (siehe unten). |
| `ui/local/view_model/local_controller.dart` | Lokaler Modus: Einrichtung, Handy weitergeben, Karte zeigen, Spielende. |
| `domain/rules/local_games.dart` | Regeln des lokalen Modus, mit eigenen Tests. Entsprechen den Regeln im Backend. |

## data/services/device und storage

Browser und App brauchen an ein paar Stellen unterschiedlichen Code. `storage.dart` und
`device.dart` wählen über bedingte Exporte die passende Datei: `*_web.dart` für den
Browser, `*_io.dart` für Android und iOS.

`storage.dart` speichert kleine Werte wie den Namen. Im Browser landet das im
localStorage, unter denselben Schlüsseln wie bei der alten Seite. Wer von `frontend/`
auf die Flutter-Seite wechselt, behält also seinen Namen. `device.dart` kümmert sich um
die Adresszeile, das Teilen des Raumlinks und E-Mail-Links.

## ui/

| Datei | Inhalt |
| --- | --- |
| `core/app.dart` | Rahmen der App: Thema je nach Phase, Statuszeile, Meldungen, Rückfragen und die Wahl der Ansicht. |
| `core/themes/theme.dart` | Farben und Schriften. Dunkelrot für Start und Lobby, eigene Farben für Nacht und Tag bei Werwolf. |
| `core/widgets/widgets.dart` | Allgemeine Bausteine: Knöpfe, Felder, Häkchen, Stepper, Überschriften, Aufklappbereiche. |
| `core/widgets/shared.dart` | Bausteine, die online und lokal gleich aussehen, etwa Spieleinstellungen, Rollenkarte und Abstimmung. |
| `core/widgets/showcase.dart` | Startseite, Lobby und lokale Einrichtung im Stil einer TV-Oberfläche (siehe unten). |
| `home/widgets/home.dart` | Startseite und die Ansicht beim Wiedereinstieg in einen Raum. |
| `lobby/widgets/lobby.dart` | Lobby mit Raumcode, Spielauswahl und Einstellungen. |
| `local/widgets/local.dart` | Alle Ansichten des lokalen Modus. |
| `core/widgets/players.dart` | Mitspielerliste und Bereit-Knopf. |
| `legal/widgets/legal.dart` | Impressum und Datenschutz. Der Text steht auch in `frontend/` und in `web/`, Änderungen also an allen Stellen machen. |
| `games/widgets/` | Je eine Datei pro Spiel mit den Online-Ansichten während des Spiels. |

### Startseite im TV-Stil

Start, Lobby und lokale Einrichtung nutzen die ganze Breite des Fensters. Oben steht die
Kopfleiste (`ShowcaseBar`) mit den Tabs „Multiplayer“ und „Lokal“, darunter der große
Titel (`GameHero`) und die Reihe der Spielkarten (`GameRow`). Alle anderen Ansichten,
also die laufenden Spiele, stehen in einer schmalen Spalte in der Mitte. Welche Form gilt,
entscheidet `GameScreen._isShowcase`.

Hinter Kopfleiste und Titel liegt rechts ein großes Bild (`ShowcaseBackdrop`). Es reicht
bis an den oberen und rechten Fensterrand und läuft nach links und unten in den
Hintergrund aus. Auf Handys liegt es blass hinter dem Text. Auf der Startseite ist es das
Startbild, in Lobby und lokaler Einrichtung das Bild des gewählten Spiels. Hat das Spiel
keins, zeigt der Titel einen Farbschein in der Farbe des Spiels.

Impressum und Datenschutz stehen am unteren Fensterrand, solange die Seite kürzer ist als
das Fenster. Ist sie länger, kommen sie nach dem Inhalt.

## Bilder

Die Originale liegen im Projektordner unter `assets/images/`. `tool/sync_assets.dart`
kopiert sie nach `app/assets/game/`. Eingetragen werden sie in `lib/data/repositories/game_data.dart`:

| Konstante | Wofür | Format |
| --- | --- | --- |
| `homeImage` | Großes Bild auf der Startseite | Querformat, das Motiv rechts, die linke Hälfte dunkel |
| `gameHeroes` | Großes Bild pro Spiel in Lobby und lokaler Einrichtung | wie das Startbild |
| `gamePosters` | Spielkarte in der Spielereihe | Hochformat, etwa 2 zu 3 |
| `roleImages` | Kartenbild einer Werwolf-Rolle | Hochformat |

Ein neues Bild einbauen:

1. Die Datei unter `assets/images/` ablegen, zum Beispiel `assets/images/Tabu/tabu-karte.jpg`.
2. Den Pfad in `tool/sync_assets.dart` bei `sources` ergänzen.
3. In `game_data.dart` den Eintrag ergänzen, mit dem Pfad unter `assets/game/` und nur dem
   Dateinamen, also `GameType.tabu: 'assets/game/tabu-karte.jpg'`.
4. `dart run tool/sync_assets.dart` aufrufen und die App neu starten. Neu laden reicht
   nicht, weil eine neue Datei dazugekommen ist.

Eine Spielkarte mit Bild zeigt den Spielnamen nicht mehr darauf. Er muss also im Bild
stehen. Das große Bild sollte links Platz für den Titel lassen, weil der darüberliegt.

## Schriften

Die Schriften liegen in `assets/fonts/` und sind in `pubspec.yaml` eingetragen. Atkinson
Hyperlegible ist die Schrift für Fließtext, Grenze die für Titel und Knöpfe. Die
latin-ext-Dateien sind eigene Familien und springen für Zeichen wie ł oder š ein.

Flutter Web würde sonst Roboto und seine Zeichen-Engine von Google nachladen. Das
widerspräche der Datenschutzerklärung. Deshalb ist Roboto in `pubspec.yaml` auf Atkinson
umgeleitet, und der Release-Build läuft mit `--no-web-resources-cdn`. Eine neue Schrift
also immer als Datei einbinden, nie über ein Paket wie google_fonts.

## Tests

| Datei | Was sie prüft |
| --- | --- |
| `ui/app_flow_test.dart` | Startseite, Wiedereinstieg, gespeicherte Daten, Impressum und Datenschutz, lokaler Modus |
| `ui/views_test.dart` | Jede Ansicht aus `fixtures/states.json` auf 320 × 640, 390 × 844 und 1280 × 800, ohne Überlauf |
| `data/services/connection_test.dart` | Verbindung, Ping und Wiederaufbau gegen einen kleinen WebSocket-Server auf dem Rechner |
| `domain/rules/local_games_test.dart` | Regeln des lokalen Modus, übertragen aus `frontend/src/localGames.test.ts` |
| `helpers/harness.dart` | Gemeinsames: Nachbau der Verbindung (`FakeLink`), echte Schriften, Handygröße |

Die Tests laden die echten Schriften. Kommt eine neue Schrift dazu, gehört sie auch in
`loadFonts()` in `test/helpers/harness.dart`, sonst messen die Überlauf-Tests mit falschen Breiten.

## Vorschau in Claude Code

In `.claude/launch.json` stehen zwei Einträge für die App. `app-web` startet
`flutter run -d web-server` auf Port 5173. `app-build` zeigt den letzten Release-Build
aus `app/build/web` auf Port 5180, vorher also `flutter build web` aufrufen.

## Wo du weiterbaust

| Was | Wo |
| --- | --- |
| Neue Aktion für ein Online-Spiel | Methode im `AppController`, Nachricht in `ClientMessage` in `models.dart`, Ansicht in `ui/games/widgets/` |
| Neues Feld vom Server | `models.dart`, danach `tool/record_states.dart` laufen lassen und die Fixtures neu schreiben |
| Neues Spiel | Eintrag in `GameType` in `models.dart`, Ansicht in `ui/games/widgets/`, Fall in `GameScreen._body()`, Farbe in `_tints` in `showcase.dart` |
| Regeln im lokalen Modus | `local_games.dart` mit Tests in `test/domain/rules/local_games_test.dart`, Ansicht in `local.dart` |
| Farben | `Palette` in `ui/core/themes/theme.dart`, Hintergrund der Startseite in `showcaseBackground` in `showcase.dart` |
| Bilder | siehe Abschnitt „Bilder“ |
| Texte von Impressum und Datenschutz | `legal.dart`, `web/impressum.html`, `web/datenschutz.html` und die Dateien in `frontend/` |
