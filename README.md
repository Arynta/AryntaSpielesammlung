# Werwolf

Kleine Webseite für Spieleabende: Jeder öffnet sie auf dem Handy, tritt mit einem
vierstelligen Code einem Raum bei, und der Server verteilt die Rollen. Gesprochen
wird ganz normal am Tisch.

```
werwolf/
├── backend/    Spring Boot 4 (Java 21), WebSocket unter /ws
├── frontend/   Vite + TypeScript, ohne Framework
└── render.yaml Deployment des Backends auf Render (Free)
```

## Was schon geht

- Raum erstellen, Code oder Link teilen, beitreten
- Wer den Raum erstellt, ist Spielleitung. Geht sie in der Lobby, übernimmt der Nächste.
- Ab 4 Spielern starten. Pro angefangene 4 Spieler ein Werwolf, eine Seherin, der Rest Dorfbewohner
- Jeder sieht nur seine eigene Rolle (Karte gedrückt halten). Werwölfe sehen, wer noch Werwolf ist.
- Die Spielleitung schaltet zwischen Nacht und Tag um, das Design wechselt mit
- Seite neu laden oder Handy sperren: man landet wieder im selben Raum
- Wer die Verbindung verliert, wird als "offline" angezeigt
- Räume ohne Aktivität werden nach 6 Stunden gelöscht

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

Dann http://localhost:5173 öffnen. `npm run dev` startet mit `--host`, damit du die
Seite auch vom Handy im selben WLAN aufrufen kannst (Adresse steht im Terminal).
Dafür musst du in `frontend/.env.local` die IP deines Rechners eintragen,
z. B. `VITE_BACKEND_URL=ws://192.168.0.23:8080/ws`, und beim Backend
`ALLOWED_ORIGINS=http://192.168.0.23:5173` setzen.

Zum Testen mit mehreren Spielern reichen mehrere private Browserfenster.

## Kostenlos online stellen

1. Projekt auf GitHub pushen.
2. **Backend auf Render:** render.com → New → Blueprint → Repo wählen. Render baut das
   Dockerfile in `backend/`. Danach hast du eine Adresse wie
   `https://werwolf-backend.onrender.com`.
3. **Frontend auf Cloudflare Pages** (oder Vercel/Netlify, geht genauso):
   - Root directory: `frontend`
   - Build command: `npm run build`
   - Output directory: `dist`
   - Umgebungsvariable: `VITE_BACKEND_URL=wss://werwolf-backend.onrender.com/ws`
4. Bei Render unter Environment `ALLOWED_ORIGINS` auf die Adresse des Frontends
   setzen, z. B. `https://werwolf.pages.dev`, und neu deployen.

Der kostenlose Render-Server schläft nach 15 Minuten ohne Besucher ein. Wer als Erstes
die Seite öffnet, sieht dann "Der Server wird geweckt" und wartet bis zu einer Minute.
Beim Einschlafen gehen offene Räume verloren, während eines Spiels passiert das aber
nicht, weil die Handys die Verbindung aktiv halten.

## Wo du weiterbaust

| Was | Wo |
| --- | --- |
| Neue Rollen (Hexe, Jäger, Amor …) | `Role.java`, `RoleDistribution.java`, im Frontend `types.ts` |
| Abstimmung, Opfer, Siegbedingung | `Room.nextPhase()` und neue Methoden in `Room`, neue Nachrichtentypen in `GameSocketHandler` |
| Nachrichten zwischen Handy und Server | `ClientMessage.java` und `types.ts` (beide Seiten gleich halten) |
| Aussehen | `frontend/src/style.css`, die Farben hängen an `body[data-phase=…]` |

Eine neue Aktion einbauen, z. B. eine Abstimmung:

1. In `Room` eine Methode `vote(String voterId, String targetId)` schreiben und testen
   (`RoomTest.java` zeigt, wie).
2. In `GameSocketHandler.handle()` einen Fall `case "vote" ->` ergänzen.
3. `ClientMessage` um das Feld `targetId` erweitern, in `types.ts` den Typ
   `{ type: "vote"; targetId: string }` ergänzen.
4. Im Frontend einen Knopf mit `data-action` einbauen und in `act()` die Nachricht senden.

Die Ansicht, die jeder Spieler bekommt, baut `Room.viewFor()`. Alles Geheime gehört
dort hinein und nur in das Feld `you`, damit es nie bei anderen Spielern landet.

## Tests

```bash
cd backend && mvn test
```
