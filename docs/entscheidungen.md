# Entscheidungen

Warum Dinge so gebaut sind, wie sie sind. Gedacht für alle, die hier weiterbauen, auch für eine KI,
die das Projekt zum ersten Mal sieht. Was gebaut ist, steht im [README](../README.md); hier steht das
Warum und was bewusst offen geblieben ist.

Jeder Abschnitt hat dieselbe Form: **Entscheidung**, **Grund**, **Wo im Code**, **Achtung**.

---

## 1. Zweisprachigkeit (Deutsch und Englisch)

Oben rechts in der Kopfleiste schaltet eine Flagge zwischen Deutsch (Standard) und Englisch um.
Die Wahl bleibt im Browser gespeichert. „Komplett auf Englisch“ heißt: App-Texte, Meldungen des
Servers, Spielinhalte und die Rechtsseiten.

### 1.1 Texte der App: Flutters gen-l10n mit ARB-Dateien

- **Entscheidung:** Alle Texte stehen in `app/lib/l10n/app_de.arb` (Vorlage) und `app_en.arb`.
  Flutter erzeugt daraus `app_localizations*.dart`.
- **Grund:** Flutter-Standard, kann Platzhalter und Mehrzahl (`{count, plural, =1{…} other{…}}`)
  und übersetzt die eingebauten Material-Texte gleich mit. Eine eigene Lösung hätte das nachbauen müssen.
- **Wo im Code:** `app/l10n.yaml`, `app/pubspec.yaml` (`generate: true`, `flutter_localizations`, `intl`).
- **Achtung:**
  - Die erzeugten Dateien stehen in `app/.gitignore` und in `analysis_options.yaml` unter `exclude`.
    Sie entstehen bei `flutter pub get`, `run`, `test` und `build` neu.
  - Die Material-Delegates kommen aus `material_ui` (`GlobalMaterialLocalizations.delegates`),
    **nicht** aus `flutter_localizations`. Die Typen der beiden Pakete passen nicht zusammen
    (siehe `app/lib/ui/core/app.dart`).
  - Die Reihenfolge der Platzhalter in der `@key`-Beschreibung bestimmt die Reihenfolge der
    Parameter in Dart. Neue Texte mit mehreren Platzhaltern danach prüfen.

### 1.2 Zugriff auf Texte: globales `texts` statt nur `context`

- **Entscheidung:** `texts` in `app/lib/l10n/l10n.dart` liefert die Texte der aktuellen Sprache, auch
  ohne `BuildContext`. Die aktuelle Sprache steht in `appLanguage`; nur der `AppController` setzt sie.
- **Grund:** Viele Ansichten sind Funktionen ohne `context` (`werwolfView(controller, room, …)`), und
  Controller und Spielregeln (`domain/rules/`) brauchen Texte für Rückfragen, Toasts und Fehler.
- **Wo im Code:** `l10n.dart`, `AppController.toggleLanguage()`.
- **Achtung:** Damit beim Umschalten auch `const`-Widgets neu bauen, baut `GameScreen` den Inhalt
  über `KeyedSubtree(key: ValueKey(language))` komplett neu. Scrollposition geht dabei verloren, das
  ist gewollt. `MaterialApp` hängt an einem eigenen `ValueNotifier` (`controller.language`), damit
  nicht jede Zustandsänderung die ganze App neu baut.

### 1.3 Sprache pro Handy, nicht pro Raum

- **Entscheidung:** Jeder Spieler hat seine eigene Sprache. Das Handy schickt sie bei `create`,
  `join` und `rejoin` mit und bei jedem Umschalten mit `setLanguage`. Fehlt sie, gilt Deutsch.
- **Grund:** In einer Runde können deutsch- und englischsprachige Leute sitzen. Ältere Handys ohne
  das Feld funktionieren weiter.
- **Wo im Code:** `backend/.../i18n/Language.java`, `Player.language()`, `GameSocketHandler`
  (`languagesBySession` für Fehler, die vor dem Beitritt passieren), `app/lib/domain/models/messages.dart`.

### 1.4 Spielinhalte in der Sprache der Spielleitung

- **Entscheidung:** Wörter, Tabu-Karten, Nobody-is-Perfect-Fragen und Geo-Bingo-Motive und -Orte
  kommen beim Spielstart in der Sprache des Hosts. Oberfläche, Hinweise und Werwolf-Rollen folgen
  dagegen dem eigenen Handy.
- **Grund:** Beim Impostor müssen alle dasselbe Wort haben, und bei Tabu wird am Tisch in einer Sprache
  geraten. Rollen sind nur eine ID, die kann jedes Handy in seiner Sprache anzeigen.
- **Wo im Code:** `Room.contentLanguage()`, `GameData.perLanguage()`, Dateien
  `backend/src/main/resources/games/*.json` (Deutsch) und `*-en.json` (Englisch).
- **Achtung:** Die englischen Dateien sind **Übersetzungen** der deutschen, keine neuen Inhalte. Bei
  Nobody is Perfect blieben typisch deutsche Wörter („Kalauer“, „Muckefuck“) stehen und werden als
  deutsche Wörter abgefragt, damit die Antworten weiterhin stimmen. Neue Karten in **beiden** Dateien
  anlegen; die Tests prüfen Vollständigkeit pro Sprache.

### 1.5 Impostor-Kategorien über feste IDs

- **Entscheidung:** Jede Kategorie hat eine `id` (`animals`, `food`, …). Über die Leitung gehen IDs,
  `ImpostorSettings.categoryNames` liefert die Namen in der Sprache des Empfängers.
- **Grund:** Namen sind je Sprache verschieden; die Auswahl des Hosts muss den Sprachwechsel überleben.
- **Achtung:** Lokal gespeicherte Einstellungen von vorher (Namen statt IDs) fallen einmalig auf „alle
  Kategorien“ zurück. Das alte Frontend `frontend/` zeigt online `categoryNames` an.

### 1.6 Meldungen des Servers: Schlüssel statt fertiger Text

- **Entscheidung:** `GameException` trägt einen Schlüssel und Argumente (`Text`). Der Text entsteht erst
  beim Empfänger in dessen Sprache. Vorlagen stehen in `backend/src/main/resources/i18n/messages.properties`
  (Deutsch) und `messages_en.properties`. Platzhalter wie bei `String.format` (`%s`, `%d`).
- **Grund für `ResourceBundle` statt Spring `MessageSource`:** Die Spielklassen sind keine
  Spring-Beans. `Text` ist eine kleine Klasse ohne Abhängigkeiten. `String.format` statt
  `MessageFormat`, weil `MessageFormat` Apostrophe verschluckt („don't“).
- **Achtung:**
  - `GameException.getMessage()` bleibt deutsch, deshalb prüfen viele Tests weiter deutsche Texte.
  - Der Test `beideSprachdateienHabenDieselbenSchluessel` schlägt fehl, wenn ein Schlüssel nur in
    einer Datei steht.
  - Fehler gehen mit `key` an das Handy (`{"type":"error","message":…,"key":…}`), damit die App
    gezielt reagieren kann (siehe 3.).

### 1.7 Impressum und Datenschutz als eigene Dateien je Sprache

- **Entscheidung:** `app/lib/ui/legal/content/impressum_de.dart`, `impressum_en.dart`,
  `datenschutz_de.dart`, `datenschutz_en.dart`. Die englischen Seiten tragen oben den Hinweis, dass die
  deutsche Fassung maßgeblich ist.
- **Grund:** Rechtstexte sind Dokumente; zerlegt in ARB-Schnipsel kann man sie nicht mehr am Stück prüfen.
- **Achtung:** Änderungen immer in **beiden** Dateien. Der Datenschutz nennt die gespeicherte Sprache
  (localStorage `arynta.language`) und dass der Server sie kennt. „Meine Daten löschen“ löscht sie mit.

### 1.8 Flagge selbst gezeichnet

- **Entscheidung:** `FlagPainter` zeichnet die Deutschland-Flagge und den Union Jack (für „englische
  Flagge“). Die Flagge zeigt die **aktuelle** Sprache.
- **Grund:** Die Seite lädt keine Bilder oder Schriften von Dritten, und Flaggen-Emoji fehlen in der
  Schrift (sie erscheinen als Kästchen).
- **Wo im Code:** `app/lib/ui/core/widgets/language/`. In der breiten Ansicht steht sie in der
  `ShowcaseBar`, in Spielansichten oben rechts über dem Inhalt.
- **Achtung:** Unter 360 px Breite blendet die Kopfleiste das WLAN-Symbol aus, sonst passt die Flagge
  nicht. Offline zeigt es dann die Statuszeile.

### 1.9 Bewusst nicht übersetzt

- Spielnamen, die Eigennamen sind („Impostor“, „Nobody is Perfect“, „Buzzer“).
- `frontend/` (die alte TypeScript-Seite) bleibt deutsch.
- `debugPrint`- und Log-Meldungen bleiben deutsch.

---

## 2. Kopf der Spielauswahl hat immer dieselbe Höhe

- **Entscheidung:** In `GameHero` steht der Titel immer in **einer** Zeile und wird bei Bedarf kleiner
  (`FittedBox`). Die Beschreibung hält immer zwei Zeilen frei (`_TwoLines`).
- **Grund:** Vorher sprang die Spielereihe beim Durchblättern nach unten, und „WEREWOLF“ brach wegen
  des großen Buchstabenabstands mitten im Wort um.
- **Wo im Code:** `app/lib/ui/core/widgets/showcase/game_hero.dart`.

---

## 3. Unbekannter Raumcode: Feld leuchtet rot und schüttelt sich

- **Entscheidung:** Kommt ein Fehler mit `key == "error.rooms.unknown"`, wird das Raumcode-Feld rot
  (`AppField.invalid`) und wackelt einmal (`Shake`). Neue Eingabe nimmt das Rot weg.
- **Grund:** Der Toast allein war leicht zu übersehen.
- **Wo im Code:** `AppController.codeInvalid` und `codeRejections`,
  `app/lib/ui/core/widgets/basics/shake.dart`, `app/lib/ui/home/widgets/home.dart`.
- **Achtung:** Andere Fehler (Raum voll, Name vergeben) und ein fehlgeschlagener Wiedereinstieg nach
  dem Neuladen lösen das nicht aus. Sind Animationen im System abgeschaltet, bleibt nur der rote Rand.

---

## 4. Schutz gegen Skripte (Sicherheitsprüfung November 2026)

Geprüft wurden Backend, Flutter-App, `frontend/`, Docker, Workflows und Render. Kritische Lücken gab
es nicht: Eingaben werden bereinigt und begrenzt, das alte Frontend escaped Spielertexte, die App hat
eine Content-Security-Policy, Logs enthalten keine Namen, Docker läuft ohne Root. Ergänzt wurden
Grenzen gegen Missbrauch durch Skripte.

| Grenze | Wert | Einstellung | Was passiert |
|---|---|---|---|
| Nachrichten pro Verbindung | 20 pro Sekunde | `app.limits.messages-per-second` (Umgebung `MAX_MESSAGES_PER_SECOND`) | Verbindung wird geschlossen (Code 1008), die App verbindet neu |
| Unbekannte Raumcodes hintereinander | 10 | `app.limits.unknown-codes` | Verbindung wird geschlossen; ein Treffer setzt den Zähler zurück |
| Offene Räume pro Adresse | 10 | `app.limits.rooms-per-address` | Fehler `error.rooms.tooManyFromAddress` |
| Größe einer Nachricht | 8 KB | `app.limits.max-message-bytes` | Server beendet die Verbindung |
| Stille Verbindung | 2 Minuten | `app.limits.idle-timeout` | Server beendet die Verbindung (die App pingt alle 25 s) |

- **Wo im Code:** `backend/.../ws/ConnectionGuard.java`, `GameSocketHandler` (`closeForAbuse`,
  `clientAddress`), `RoomRegistry.createRoom(address)`, `AppConfig.webSocketContainer()`,
  `application.properties`.

### 4.1 Warum 20 Nachrichten pro Sekunde

Ein Mensch schafft das nicht, auch nicht beim schnellen Drücken von „Richtig“ oder beim Buzzer.
`app/tool/record_states.dart` schickt dagegen viel schneller. Dafür das Backend mit
`MAX_MESSAGES_PER_SECOND=1000` starten (steht im Kopf des Skripts und im README).

### 4.2 Raumcodes raten

4 Zeichen aus 31 ergeben rund 920.000 Codes. Ohne Grenze findet ein Skript offene Lobbys schnell.
Die Grenze pro Verbindung stoppt einfache Skripte. Wer immer neue Verbindungen öffnet, wird nur
gebremst. Längere Codes wären sicherer, sind am Tisch aber schlechter vorzulesen.

### 4.3 Räume pro Adresse

- Es zählen nur Räume, in denen **noch jemand verbunden** ist. Grund: Verlassene Räume bleiben bis zu
  6 Stunden stehen, und hinter Mobilfunk-Anbietern teilen sich viele Menschen eine Adresse.
- **Adresse hinter Render:** Render steht als Proxy davor. `render.yaml` setzt
  `CLIENT_IP_HEADER=X-Forwarded-For`, genommen wird der **erste** Eintrag. Ist er gefälscht, greift nur
  das Raumlimit nicht. Der letzte Eintrag könnte dagegen die Adresse eines Proxys sein, dann teilten
  sich alle Spieler ein Limit, und echte Leute würden gesperrt.
- **Lücke:** Renders Dokumentation sagt nicht, welche Kopfzeile die echte Adresse enthält. Nach dem
  ersten Deploy prüfen (z. B. Logs oder ein kurzer Test-Endpunkt, der die Kopfzeilen ausgibt) und
  `CLIENT_IP_HEADER` notfalls anpassen.

### 4.4 Bewusst offen gelassen

| Punkt | Warum offen |
|---|---|
| Ähnlich aussehende Buchstaben in Namen („Аnna“ mit kyrillischem А) | Niedriges Risiko, der Host sieht alle Spieler und kann entfernen. |
| CSP erlaubt `connect-src` zu jedem Server | Greift nur, wenn trotz CSP fremder Code liefe. Die Backend-Adresse ist in `flutter_bootstrap.js` nicht bekannt. |
| Verbindungen ohne `Origin`-Kopfzeile sind erlaubt | Gewollt für die spätere Android- und iOS-App. Gegen Skripte hilft `Origin` ohnehin nicht. |

---

## 5. Arbeitsweise in diesem Projekt

- **Commits** nur unter dem Namen des Besitzers, **ohne** `Co-Authored-By`-Zeile für eine KI.
  Commit-Nachrichten auf Deutsch.
- **Java und Maven** sind nicht im PATH: Java 21 unter `C:\Users\Richa\.jdks\temurin-21.0.12.1`,
  Maven unter `C:\Program Files\JetBrains\IntelliJ IDEA 2026.2.3\plugins\maven-plugin\lib\maven3\bin\mvn.cmd`.
- **Port 5173** gehört oft dem eigenen `flutter run` des Besitzers; nicht beenden. Für eigene Tests ein
  Backend auf einem anderen Port starten (z. B. `PORT=8099`) und die gebaute App über die
  Konfiguration `app-build` (Port 5180) aus `.claude/launch.json` ansehen.
- **Prüfen vor dem Abschluss:** `flutter analyze` und `flutter test` in `app/`, `mvn test` in `backend/`,
  `npx tsc --noEmit` und `npm test` in `frontend/`. Ändert sich das Protokoll, die Fixtures mit
  `dart run tool/record_states.dart` neu aufnehmen (siehe 4.1).
- **Neue Texte:** In beide ARB-Dateien (App) bzw. beide `messages*.properties` (Server) und bei
  Spielinhalten in beide JSON-Dateien. Die Tests prüfen das.
- **Geo-Bingo** ist mit `app.locked-games` (`LOCKED_GAMES`) als „Bald verfügbar“ gesperrt.
