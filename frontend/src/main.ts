import "./fonts";
import "./style.css";
import { GameConnection, type ConnectionStatus } from "./connection";
import type { RoomView, ServerMessage } from "./types";

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "ws://localhost:8080/ws";
const MIN_PLAYERS = 4; // muss zu Room.MIN_PLAYERS im Backend passen

// ---------------------------------------------------------------------------
// Zustand

interface Session {
  code: string;
  secret: string;
}

const state = {
  status: "waking" as ConnectionStatus,
  session: load<Session>("werwolf.session"),
  room: null as RoomView | null,
  name: load<string>("werwolf.name") ?? "",
  codeInput: new URLSearchParams(location.search).get("raum")?.toUpperCase() ?? "",
  toast: null as string | null,
  revealing: false,
  waitingForRejoin: false,
};

let toastTimer: number | undefined;

const app = document.querySelector<HTMLDivElement>("#app")!;

const connection = new GameConnection(
  BACKEND_URL,
  handleMessage,
  (status) => {
    state.status = status;
    render();
  },
  () => {
    if (state.session) {
      state.waitingForRejoin = true;
      connection.send({ type: "rejoin", code: state.session.code, secret: state.session.secret });
    }
  },
);

function handleMessage(msg: ServerMessage): void {
  switch (msg.type) {
    case "joined":
      state.session = { code: msg.code, secret: msg.secret };
      state.waitingForRejoin = false;
      save("werwolf.session", state.session);
      history.replaceState(null, "", `?raum=${msg.code}`);
      break;
    case "state":
      state.room = msg.state;
      break;
    case "left":
      forgetRoom();
      break;
    case "error":
      if (state.waitingForRejoin) {
        // Raum gibt es nach einem Server-Neustart nicht mehr
        forgetRoom();
      }
      showToast(msg.message);
      break;
    case "pong":
      return;
  }
  render();
}

function forgetRoom(): void {
  state.session = null;
  state.room = null;
  state.revealing = false;
  state.waitingForRejoin = false;
  save("werwolf.session", null);
  history.replaceState(null, "", location.pathname);
}

// ---------------------------------------------------------------------------
// Aktionen (über data-action im HTML)

function act(action: string): void {
  switch (action) {
    case "create":
      if (!requireName()) return;
      sendOrComplain({ type: "create", name: state.name });
      break;
    case "join":
      if (!requireName()) return;
      if (state.codeInput.trim().length === 0) {
        showToast("Gib den Raumcode ein, den dir deine Freunde geschickt haben.");
        return;
      }
      sendOrComplain({ type: "join", code: state.codeInput.trim(), name: state.name });
      break;
    case "start":
      sendOrComplain({ type: "start" });
      break;
    case "nextPhase":
      sendOrComplain({ type: "nextPhase" });
      break;
    case "backToLobby":
      if (confirm("Spiel beenden und alle zurück in die Lobby schicken?")) {
        sendOrComplain({ type: "backToLobby" });
      }
      break;
    case "leave":
      if (confirm("Raum wirklich verlassen?")) {
        if (!connection.send({ type: "leave" })) {
          forgetRoom();
          render();
        }
      }
      break;
    case "share":
      void shareRoom();
      break;
    case "forgetDevice":
      forgetDevice();
      break;
  }
}

function forgetDevice(): void {
  const inRoom = state.session !== null;
  const question = inRoom
    ? "Name und Raum auf diesem Gerät löschen? Du verlässt dabei den Raum."
    : "Deinen gespeicherten Namen auf diesem Gerät löschen?";
  if (!confirm(question)) return;

  if (inRoom) connection.send({ type: "leave" });
  forgetRoom();
  state.name = "";
  save("werwolf.name", null);
  showToast("Deine Daten auf diesem Gerät sind gelöscht.");
}

function requireName(): boolean {
  state.name = state.name.trim();
  if (!state.name) {
    showToast("Gib zuerst deinen Namen ein.");
    document.querySelector<HTMLInputElement>("#name")?.focus();
    return false;
  }
  save("werwolf.name", state.name);
  return true;
}

function sendOrComplain(msg: Parameters<GameConnection["send"]>[0]): void {
  if (!connection.send(msg)) {
    showToast("Keine Verbindung zum Server. Einen Moment, ich versuche es weiter.");
  }
}

async function shareRoom(): Promise<void> {
  if (!state.room) return;
  const url = `${location.origin}${location.pathname}?raum=${state.room.code}`;
  try {
    if (navigator.share) {
      await navigator.share({ title: "Werwolf", text: `Komm in meinen Werwolf-Raum: ${state.room.code}`, url });
    } else {
      await navigator.clipboard.writeText(url);
      showToast("Link kopiert");
    }
  } catch {
    // Teilen abgebrochen, nichts zu tun
  }
}

function showToast(text: string): void {
  state.toast = text;
  window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => {
    state.toast = null;
    render();
  }, 4_000);
  render();
}

// ---------------------------------------------------------------------------
// Darstellung

function render(): void {
  const room = state.room;
  document.body.dataset.phase = room ? room.phase.toLowerCase() : "home";

  // Fokus und Cursor merken, damit Neuzeichnen beim Tippen und bei Tastaturbedienung nicht stört
  const active = document.activeElement as HTMLInputElement | null;
  const focusSelector = focusSelectorFor(active);
  const selection = active?.selectionStart ?? null;

  let body: string;
  if (!room) {
    body = state.session ? viewReconnecting() : viewHome();
  } else if (room.phase === "LOBBY") {
    body = viewLobby(room);
  } else {
    body = viewGame(room);
  }

  app.innerHTML = `
    ${viewStatus()}
    <main class="screen">${body}${viewFooter()}</main>
    <div class="toast" role="status" aria-live="polite">${state.toast ? esc(state.toast) : ""}</div>
  `;

  if (focusSelector) {
    const el = app.querySelector<HTMLInputElement>(focusSelector);
    el?.focus();
    if (el instanceof HTMLInputElement && selection !== null) el.setSelectionRange(selection, selection);
  }
}

function focusSelectorFor(el: HTMLElement | null): string | null {
  if (!el || !app.contains(el)) return null;
  if (el.id) return `#${el.id}`;
  if (el.dataset.action) return `[data-action="${el.dataset.action}"]`;
  return null;
}

function viewFooter(): string {
  return `
    <footer class="site-footer">
      <a href="./impressum.html">Impressum</a>
      <a href="./datenschutz.html">Datenschutz</a>
      <button class="link-button" data-action="forgetDevice">Meine Daten löschen</button>
    </footer>`;
}

function viewStatus(): string {
  if (state.status === "online") return "";
  const text =
    state.status === "waking"
      ? "Der Server wird geweckt. Beim ersten Aufruf kann das bis zu einer Minute dauern."
      : "Verbindung unterbrochen. Ich verbinde neu …";
  return `<p class="status">${text}</p>`;
}

function viewHome(): string {
  const online = state.status === "online";
  return `
    <header class="home-head">
      <h1 class="title">Werwolf</h1>
      <p class="lead">Für Spieleabende mit Freunden. Jeder spielt am eigenen Handy, gesprochen wird am Tisch.</p>
    </header>

    <label class="field">
      <span>Dein Name</span>
      <input id="name" data-bind="name" autocomplete="nickname" maxlength="20"
             value="${esc(state.name)}" placeholder="z. B. Anna" />
    </label>

    <button class="btn primary" data-action="create" ${online ? "" : "disabled"}>Neuen Raum erstellen</button>

    <p class="or">oder einem Raum beitreten</p>

    <div class="join">
      <label class="field">
        <span>Raumcode</span>
        <input id="code" data-bind="codeInput" class="code-input" maxlength="4"
               autocapitalize="characters" autocomplete="off" spellcheck="false"
               value="${esc(state.codeInput)}" placeholder="K7QX" />
      </label>
      <button class="btn" data-action="join" ${online ? "" : "disabled"}>Beitreten</button>
    </div>
  `;
}

function viewReconnecting(): string {
  return `
    <h1 class="title">Werwolf</h1>
    <p class="lead">Du kommst zurück in Raum <strong>${esc(state.session!.code)}</strong> …</p>
    <button class="btn quiet" data-action="leave">Abbrechen</button>
  `;
}

function viewLobby(room: RoomView): string {
  const missing = Math.max(0, MIN_PLAYERS - room.players.length);
  const hostControls = room.you.host
    ? `<button class="btn primary" data-action="start" ${missing > 0 ? "disabled" : ""}>Spiel starten</button>
       ${missing > 0 ? `<p class="hint">Noch ${missing} Spieler, dann kann es losgehen.</p>` : ""}`
    : `<p class="hint">Warte, bis die Spielleitung das Spiel startet.</p>`;

  return `
    <section class="room-code">
      <p>Raumcode</p>
      <strong>${esc(room.code)}</strong>
      <button class="btn small" data-action="share">Link teilen</button>
    </section>

    ${viewPlayers(room)}

    <div class="actions">
      ${hostControls}
      <button class="btn quiet" data-action="leave">Raum verlassen</button>
    </div>
  `;
}

function viewGame(room: RoomView): string {
  const night = room.phase === "NIGHT";
  const heading = `${night ? "Nacht" : "Tag"} ${room.round}`;
  const hint = night
    ? "Alle schließen die Augen. Die Spielleitung ruft die Rollen nacheinander auf."
    : "Diskutiert, wer ein Werwolf sein könnte, und stimmt ab.";

  const hostControls = room.you.host
    ? `<button class="btn primary" data-action="nextPhase">${night ? "Weiter zum Tag" : "Weiter zur Nacht"}</button>
       <button class="btn quiet" data-action="backToLobby">Spiel beenden</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;

  return `
    <header class="phase-head">
      <h1 class="title">${heading}</h1>
      <p class="lead">${hint}</p>
    </header>

    ${viewRoleCard(room)}
    ${viewPlayers(room)}

    <div class="actions">${hostControls}</div>
  `;
}

function viewRoleCard(room: RoomView): string {
  const you = room.you;
  if (!you.role) return "";

  let inner: string;
  if (state.revealing) {
    let wolves = "";
    if (you.role === "WERWOLF") {
      wolves =
        you.fellowWerewolves.length > 0
          ? `<p class="wolves">Mit dir jagen: ${you.fellowWerewolves.map(esc).join(", ")}</p>`
          : `<p class="wolves">Du bist der einzige Werwolf.</p>`;
    }
    inner = `
      <span class="role-name">${esc(you.roleName ?? "")}</span>
      <p class="role-desc">${esc(you.roleDescription ?? "")}</p>
      ${wolves}`;
  } else {
    inner = `<span class="role-hidden">Gedrückt halten,<br />um deine Rolle zu sehen</span>`;
  }

  return `
    <button class="role-card ${state.revealing ? "is-open" : ""} role-${you.role.toLowerCase()}"
            data-reveal aria-label="Rolle ansehen, gedrückt halten">
      ${inner}
    </button>`;
}

function viewPlayers(room: RoomView): string {
  const items = room.players
    .map((p) => {
      const notes: string[] = [];
      if (p.id === room.you.id) notes.push("du");
      if (p.id === room.hostId) notes.push("Spielleitung");
      if (!p.connected) notes.push("offline");
      return `
        <li class="${p.alive ? "" : "is-dead"} ${p.connected ? "" : "is-offline"}">
          <span class="player-name">${esc(p.name)}</span>
          ${notes.length ? `<span class="player-note">${notes.join(", ")}</span>` : ""}
        </li>`;
    })
    .join("");

  return `
    <section class="players">
      <h2>Mitspieler <span class="count">${room.players.length}</span></h2>
      <ul>${items}</ul>
    </section>`;
}

// ---------------------------------------------------------------------------
// Ereignisse

app.addEventListener("click", (event) => {
  const target = (event.target as HTMLElement).closest<HTMLElement>("[data-action]");
  if (target && !(target as HTMLButtonElement).disabled) {
    act(target.dataset.action!);
  }
});

app.addEventListener("input", (event) => {
  const input = event.target as HTMLInputElement;
  if (input.dataset.bind === "name") state.name = input.value;
  if (input.dataset.bind === "codeInput") {
    input.value = input.value.toUpperCase();
    state.codeInput = input.value;
  }
});

app.addEventListener("keydown", (event) => {
  const input = event.target as HTMLElement;
  if (event.key === "Enter" && input.id === "code") act("join");
  if (event.key === "Enter" && input.id === "name") act(state.codeInput ? "join" : "create");
  if ((event.key === " " || event.key === "Enter") && input.hasAttribute("data-reveal") && !event.repeat) {
    event.preventDefault();
    setRevealing(true);
  }
});

app.addEventListener("keyup", (event) => {
  if (event.key === " " || event.key === "Enter") setRevealing(false);
});

// Rolle nur zeigen, solange der Finger auf der Karte liegt
app.addEventListener("pointerdown", (event) => {
  if ((event.target as HTMLElement).closest("[data-reveal]")) {
    event.preventDefault();
    setRevealing(true);
  }
});
for (const type of ["pointerup", "pointercancel"] as const) {
  window.addEventListener(type, () => setRevealing(false));
}
window.addEventListener("blur", () => setRevealing(false));
// Langes Drücken soll auf dem Handy kein Kontextmenü öffnen
app.addEventListener("contextmenu", (event) => {
  if ((event.target as HTMLElement).closest("[data-reveal]")) event.preventDefault();
});

function setRevealing(value: boolean): void {
  if (state.revealing === value) return;
  state.revealing = value;
  render();
  if (value) document.querySelector<HTMLElement>("[data-reveal]")?.focus();
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen

function esc(text: string): string {
  return text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

function load<T>(key: string): T | null {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

function save(key: string, value: unknown): void {
  try {
    if (value === null) localStorage.removeItem(key);
    else localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // privater Modus o. ä. Dann klappt nur das Wiedereinsteigen nach Neuladen nicht.
  }
}

render();
void connection.start();
