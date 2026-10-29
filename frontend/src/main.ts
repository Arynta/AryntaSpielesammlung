import "./fonts";
import "./style.css";
import { askConfirm } from "./confirmDialog";
import { GameConnection, type ConnectionStatus } from "./connection";
import { TABU, preloadRoleImages } from "./gameData";
import { esc } from "./html";
import {
  actLocal,
  changeLocal,
  createLocalState,
  forgetLocalSetup,
  inputLocal,
  tickLocal,
  viewLocal,
  type LocalState,
  type LocalUi,
} from "./localMode";
import {
  nobodyIsPerfectSummary,
  impostorCardContent,
  impostorSummary,
  roleCardContent,
  roleCardVariant,
  updateCountdowns,
  viewNobodyIsPerfectOptions,
  viewImpostorOptions,
  viewRoleOverview,
  viewSummary,
  viewWerwolfOptions,
  viewTabuOptions,
  werwolfSummary,
  tabuSummary,
  type ImpostorForm,
  type WerwolfForm,
  type TabuForm,
} from "./sharedViews";
import { viewTeamChoice, viewTabu } from "./onlineTabu";
import { viewNobodyIsPerfect } from "./onlineNobodyIsPerfect";
import type { GameType, ImpostorView, PlayerView, RoomView, ServerMessage, WerwolfView } from "./types";

const BACKEND_URL = import.meta.env.VITE_BACKEND_URL || "ws://localhost:8080/ws";

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
  /** Eigenes Impostor-Wort, das der Host gerade tippt, aber noch nicht übernommen hat. */
  customWordDraft: "",
  gamePickerOpen: false,
  settingsOpen: load<boolean>("arynta.settingsOpen") ?? false,
  toast: null as string | null,
  revealing: false,
  waitingForRejoin: false,
  /** Tabu: wann der laufende Zug endet (ms, Uhr dieses Handys). */
  turnDeadline: null as number | null,
  /** Nobody is Perfect: was im Antwortfeld steht, noch nicht abgeschickt. */
  answerDraft: "",
  /** Gesetzt, solange man ohne Server mit einem Handy spielt. */
  local: null as LocalState | null,
};

const localUi: LocalUi = {
  render: () => render(),
  toast: (text) => showToast(text),
  exit: () => {
    state.local = null;
    render();
  },
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
      // Ein eigenes Wort gilt nur für eine Runde, also beim Spielstart auch das Eingabefeld leeren
      if (state.room?.phase === "LOBBY" && msg.state.phase !== "LOBBY") state.customWordDraft = "";
      // Neue Nobody-is-Perfect-Frage, neues leeres Antwortfeld
      if (msg.state.phase !== "WRITING" || msg.state.round !== state.room?.round) state.answerDraft = "";
      state.room = msg.state;
      // Restzeit statt Endzeitpunkt vom Server, damit falsch gestellte Handy-Uhren nicht stören
      state.turnDeadline =
        msg.state.tabu && msg.state.phase === "TURN" ? Date.now() + msg.state.tabu.remainingMs : null;
      break;
    case "left":
      forgetRoom();
      break;
    case "kicked":
      forgetRoom();
      showToast("Du wurdest aus dem Raum entfernt.");
      return;
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
  state.customWordDraft = "";
  save("werwolf.session", null);
  history.replaceState(null, "", location.pathname);
}

// ---------------------------------------------------------------------------
// Aktionen (über data-action im HTML, ein eventuelles data-value steht in value)

function act(action: string, value?: string): void {
  if (state.local && actLocal(state.local, action, value, localUi)) return;
  switch (action) {
    case "openLocal":
      state.local = createLocalState();
      render();
      break;
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
    case "toggleGamePicker":
      state.gamePickerOpen = !state.gamePickerOpen;
      render();
      break;
    case "selectGame":
      state.gamePickerOpen = false;
      if (value !== state.room?.game) sendOrComplain({ type: "selectGame", game: value as GameType });
      else render();
      break;
    case "toggleSettings":
      state.settingsOpen = !state.settingsOpen;
      save("arynta.settingsOpen", state.settingsOpen);
      render();
      break;
    case "changePlayerLimit":
      if (state.room) {
        sendOrComplain({ type: "setPlayerLimit", playerLimit: state.room.playerLimit.value + Number(value) });
      }
      break;
    case "changeImpostorCount":
      if (state.room) setImpostorOptions({ impostorCount: state.room.impostorSettings.impostorCount + Number(value) });
      break;
    case "changeWerewolfCount":
      if (state.room) {
        configureWerwolf({ werewolfCount: state.room.werwolfSettings.effectiveWerewolfCount + Number(value) });
      }
      break;
    case "autoWerewolves":
      configureWerwolf({ werewolfCount: null });
      break;
    case "kick":
      void kick(value);
      break;
    case "toggleReady":
      sendOrComplain({ type: "setReady", ready: !state.room?.you.ready });
      break;
    case "saveWord":
      configureImpostor({ customWord: state.customWordDraft });
      break;
    case "clearWord":
      state.customWordDraft = "";
      configureImpostor({ customWord: "" });
      break;
    case "start":
      sendOrComplain({ type: "start" });
      break;
    case "nextPhase":
      sendOrComplain({ type: "nextPhase" });
      break;
    case "startVoting":
      sendOrComplain({ type: "startVoting" });
      break;
    case "vote":
      if (value) sendOrComplain({ type: "vote", targetId: value });
      break;
    case "changeTurnSeconds":
      if (state.room) configureTabu({ turnSeconds: state.room.tabuSettings.turnSeconds + Number(value) * TABU.turnSecondsStep });
      break;
    case "changeTargetScore":
      if (state.room) configureTabu({ targetScore: state.room.tabuSettings.targetScore + Number(value) * TABU.targetScoreStep });
      break;
    case "changeTeamCount":
      if (state.room) configureTabu({ teamCount: state.room.tabuSettings.teamCount + Number(value) });
      break;
    case "chooseTeam":
      sendOrComplain({ type: "chooseTeam", team: Number(value) });
      break;
    case "moveTeam":
      moveToNextTeam(value);
      break;
    case "startTurn":
      sendOrComplain({ type: "startTurn" });
      break;
    case "wordCorrect":
      sendOrComplain({ type: "wordCorrect" });
      break;
    case "wordSkip":
      sendOrComplain({ type: "wordSkip" });
      break;
    case "buzz":
      sendOrComplain({ type: "buzz" });
      break;
    case "changeQuestionCount":
      if (state.room) {
        sendOrComplain({ type: "configureNobodyIsPerfect", questionCount: state.room.nobodyIsPerfectSettings.questionCount + Number(value) });
      }
      break;
    case "submitAnswer":
      if (state.answerDraft.trim().length === 0) {
        showToast("Schreib zuerst eine Antwort.");
        return;
      }
      sendOrComplain({ type: "submitAnswer", answer: state.answerDraft });
      break;
    case "guessAnswer":
      if (value) sendOrComplain({ type: "guessAnswer", choice: value });
      break;
    case "skipWaiting":
      sendOrComplain({ type: "skipWaiting" });
      break;
    case "nextQuestion":
      sendOrComplain({ type: "nextQuestion" });
      break;
    case "nextRound":
      sendOrComplain({ type: "nextRound" });
      break;
    case "backToLobby":
      void backToLobby();
      break;
    case "leave":
      void leave();
      break;
    case "share":
      void shareRoom();
      break;
    case "forgetDevice":
      void forgetDevice();
      break;
  }
}

async function backToLobby(): Promise<void> {
  if (await askConfirm("Spiel beenden und alle zurück in die Lobby schicken?", "Ja, beenden")) {
    sendOrComplain({ type: "backToLobby" });
  }
}

async function leave(): Promise<void> {
  if (!(await askConfirm("Raum wirklich verlassen?", "Ja, verlassen"))) return;
  if (!connection.send({ type: "leave" })) {
    forgetRoom();
    render();
  }
}

async function kick(playerId: string | undefined): Promise<void> {
  const player = state.room?.players.find((p) => p.id === playerId);
  if (!player) return;
  if (await askConfirm(`${player.name} aus dem Raum entfernen?`, "Ja, entfernen")) {
    sendOrComplain({ type: "kick", targetId: player.id });
  }
}

/** Schickt die Impostor-Einstellungen. Was nicht angegeben ist, bleibt wie es auf dem Server steht. */
function configureImpostor(change: { seesCategory?: boolean; customWord?: string }): void {
  const current = state.room?.impostorSettings;
  if (!current) return;
  sendOrComplain({
    type: "configureImpostor",
    impostorSeesCategory: change.seesCategory ?? current.impostorSeesCategory,
    customWord: change.customWord ?? current.customWord ?? "",
  });
}

function setImpostorOptions(change: { impostorCount?: number; randomStartPlayer?: boolean }): void {
  const current = state.room?.impostorSettings;
  if (!current) return;
  sendOrComplain({
    type: "setImpostorOptions",
    impostorCount: change.impostorCount ?? current.impostorCount,
    randomStartPlayer: change.randomStartPlayer ?? current.randomStartPlayer,
  });
}

/** {@code werewolfCount: null} heißt automatisch, fehlt das Feld, bleibt die Anzahl wie sie ist. */
function configureWerwolf(change: { werewolfCount?: number | null; roles?: string[]; hostIsGameMaster?: boolean }): void {
  const current = state.room?.werwolfSettings;
  if (!current) return;
  sendOrComplain({
    type: "configureWerwolf",
    werewolfCount: change.werewolfCount !== undefined ? change.werewolfCount : current.werewolfCount,
    roles: change.roles ?? current.selectedRoles,
    hostIsGameMaster: change.hostIsGameMaster ?? current.hostIsGameMaster,
  });
}

function configureTabu(change: Partial<TabuForm>): void {
  const current = state.room?.tabuSettings;
  if (!current) return;
  sendOrComplain({
    type: "configureTabu",
    turnSeconds: change.turnSeconds ?? current.turnSeconds,
    autoTeams: change.autoTeams ?? current.autoTeams,
    teamCount: change.teamCount ?? current.teamCount,
    targetScore: change.targetScore ?? current.targetScore,
  });
}

/** Host verschiebt jemanden ins nächste Team (nach dem letzten wieder ins erste). */
function moveToNextTeam(playerId: string | undefined): void {
  const settings = state.room?.tabuSettings;
  if (!settings || !playerId) return;
  const current = settings.teams.findIndex((ids) => ids.includes(playerId));
  sendOrComplain({ type: "chooseTeam", team: (current + 1) % settings.teamCount, targetId: playerId });
}

async function forgetDevice(): Promise<void> {
  const inRoom = state.session !== null;
  const question = inRoom
    ? "Name und Raum auf diesem Gerät löschen? Du verlässt dabei den Raum."
    : "Deinen gespeicherten Namen auf diesem Gerät löschen?";
  if (!(await askConfirm(question, "Ja, löschen"))) return;

  if (inRoom) connection.send({ type: "leave" });
  forgetRoom();
  forgetLocalSetup();
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
      await navigator.share({ title: "Arynta", text: `Komm in meinen Spieleraum: ${state.room.code}`, url });
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
  if (state.local) {
    document.body.dataset.phase = "home";
    body = viewLocal(state.local);
  } else if (!room) {
    body = state.session ? viewReconnecting() : viewHome();
  } else if (room.phase === "LOBBY") {
    body = viewLobby(room);
  } else if (room.werwolf) {
    body = viewWerwolf(room, room.werwolf);
  } else if (room.tabu) {
    body = viewTabu(room, room.tabu, state.turnDeadline, viewReadyButton(room));
  } else if (room.nobodyIsPerfect) {
    body = viewNobodyIsPerfect(room, room.nobodyIsPerfect, state.answerDraft, viewReadyButton(room));
  } else if (room.impostor) {
    body = viewImpostor(room, room.impostor);
  } else {
    body = viewLobby(room);
  }

  app.innerHTML = `
    ${state.local ? "" : viewStatus()}
    <main class="screen">${body}${viewFooter()}</main>
    <div class="toast" role="status" aria-live="polite">${state.toast ? esc(state.toast) : ""}</div>
  `;

  if (focusSelector) {
    const el = app.querySelector<HTMLInputElement>(focusSelector);
    el?.focus();
    if (el instanceof HTMLInputElement && el.type === "text" && selection !== null) {
      el.setSelectionRange(selection, selection);
    }
  }
}

function focusSelectorFor(el: HTMLElement | null): string | null {
  if (!el || !app.contains(el)) return null;
  if (el.id) return `#${el.id}`;
  if (el.dataset.action && el.dataset.value) {
    return `[data-action="${el.dataset.action}"][data-value="${el.dataset.value}"]`;
  }
  if (el.dataset.action) return `[data-action="${el.dataset.action}"]`;
  return null;
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
      <h1 class="title">Arynta</h1>
      <p class="lead">Spieleabend mit Freunden. Jeder spielt am eigenen Handy, gesprochen wird am Tisch.</p>
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

    <p class="or">oder ohne Internet mit nur einem Handy</p>
    <button class="btn" data-action="openLocal">Lokal spielen</button>
  `;
}

function viewReconnecting(): string {
  return `
    <h1 class="title">Arynta</h1>
    <p class="lead">Du kommst zurück in Raum <strong>${esc(state.session!.code)}</strong> …</p>
    <button class="btn quiet" data-action="leave">Abbrechen</button>
  `;
}

// ---- Lobby ----------------------------------------------------------------

function viewLobby(room: RoomView): string {
  const startControls = room.you.host
    ? `<button class="btn primary" data-action="start" ${room.canStart ? "" : "disabled"}>Spiel starten</button>`
    : "";
  const waitHint =
    room.canStart && !room.you.host ? "Alle sind bereit. Die Spielleitung kann starten." : room.startHint;

  return `
    <section class="room-code">
      <p>Raumcode</p>
      <strong>${esc(room.code)}</strong>
      <button class="btn small" data-action="share">Link teilen</button>
    </section>

    ${viewGamePicker(room)}
    ${viewSettings(room)}
    ${room.game === "TABU" && !room.tabuSettings.autoTeams ? viewTeamChoice(room) : ""}
    ${viewPlayers(room, { showReady: true, showLimit: true, kickable: room.you.host })}

    <div class="actions">
      ${viewReadyButton(room)}
      ${startControls}
      ${waitHint ? `<p class="hint">${esc(waitHint)}</p>` : ""}
      <button class="btn quiet" data-action="leave">Raum verlassen</button>
    </div>
  `;
}

function viewReadyButton(room: RoomView): string {
  return room.you.ready
    ? `<button class="btn ready is-ready" data-action="toggleReady" aria-pressed="true">✓ Bereit</button>`
    : `<button class="btn ready" data-action="toggleReady" aria-pressed="false">Ich bin bereit</button>`;
}

function viewGamePicker(room: RoomView): string {
  const selected = room.games.find((g) => g.type === room.game)!;

  if (!room.you.host) {
    return `
      <section class="game-picker">
        <h2>Spiel</h2>
        <div class="game-chosen">
          <strong>${esc(selected.name)}</strong>
          <span class="game-min">ab ${selected.minPlayers} Spielern</span>
          <p>${esc(selected.description)}</p>
        </div>
      </section>`;
  }

  if (!state.gamePickerOpen) {
    return `
      <section class="game-picker">
        <h2>Spiel</h2>
        <button class="game-option is-selected" data-action="toggleGamePicker" aria-expanded="false">
          <strong>${esc(selected.name)}</strong>
          <span class="game-min">Wechseln ▾</span>
          <span class="game-desc">${esc(selected.description)}</span>
        </button>
      </section>`;
  }

  const options = room.games
    .map((g) => {
      const active = g.type === room.game;
      return `
        <button class="game-option ${active ? "is-selected" : ""}" data-action="selectGame"
                data-value="${g.type}" aria-pressed="${active}">
          <strong>${esc(g.name)}</strong>
          <span class="game-min">ab ${g.minPlayers} Spielern</span>
          <span class="game-desc">${esc(g.description)}</span>
        </button>`;
    })
    .join("");

  return `
    <section class="game-picker">
      <h2>Spiel wählen</h2>
      <div class="game-options">${options}</div>
    </section>`;
}

/** Aufklappbarer Bereich: Spielerlimit für alle Spiele, dazu die Einstellungen des gewählten Spiels. */
function viewSettings(room: RoomView): string {
  const open = state.settingsOpen;
  const toggle = `
    <button class="settings-toggle" data-action="toggleSettings" aria-expanded="${open}" aria-controls="settings-body">
      <span>Spieleinstellungen</span>
      <span class="chevron" aria-hidden="true">${open ? "▴" : "▾"}</span>
    </button>`;
  if (!open) return `<section class="settings-panel">${toggle}</section>`;

  let gameSettings: string;
  if (room.game === "IMPOSTOR") {
    gameSettings = room.you.host ? viewImpostorSettings(room) : viewImpostorSettingsSummary(room);
  } else if (room.game === "TABU") {
    const form = room.tabuSettings;
    gameSettings = room.you.host ? viewTabuOptions(form) : viewSummary(tabuSummary(form));
  } else if (room.game === "NOBODY_IS_PERFECT") {
    const form = room.nobodyIsPerfectSettings;
    gameSettings = room.you.host ? viewNobodyIsPerfectOptions(form) : viewSummary(nobodyIsPerfectSummary(form));
  } else {
    const form = werwolfForm(room);
    gameSettings = room.you.host ? viewWerwolfOptions(form) : viewSummary(werwolfSummary(form));
  }

  return `
    <section class="settings-panel">
      ${toggle}
      <div id="settings-body" class="settings">
        ${viewPlayerLimit(room)}
        ${gameSettings}
      </div>
    </section>`;
}

function viewPlayerLimit(room: RoomView): string {
  const limit = room.playerLimit;
  if (!room.you.host) {
    return `<p class="setting-row"><span>Spielerlimit</span><strong>${limit.value}</strong></p>`;
  }
  return `
    <div class="setting-row">
      <span id="limit-label">Spielerlimit</span>
      <div class="stepper" role="group" aria-labelledby="limit-label">
        <button class="btn small" data-action="changePlayerLimit" data-value="-1"
                aria-label="Limit verringern" ${limit.value <= limit.min ? "disabled" : ""}>−</button>
        <output aria-live="polite">${limit.value}</output>
        <button class="btn small" data-action="changePlayerLimit" data-value="1"
                aria-label="Limit erhöhen" ${limit.value >= limit.max ? "disabled" : ""}>+</button>
      </div>
    </div>`;
}

function impostorForm(room: RoomView): ImpostorForm {
  const settings = room.impostorSettings;
  return {
    impostorCount: settings.impostorCount,
    maxImpostorCount: settings.maxImpostorCount,
    seesCategory: settings.impostorSeesCategory,
    randomStartPlayer: settings.randomStartPlayer,
    allCategories: settings.allCategories,
    selectedCategories: settings.selectedCategories,
    categoryHint: settings.customWordSet
      ? "Gilt erst wieder, wenn kein eigenes Wort gesetzt ist."
      : "Das Wort kommt zufällig aus den angekreuzten Kategorien.",
  };
}

function werwolfForm(room: RoomView): WerwolfForm {
  const settings = room.werwolfSettings;
  return {
    werewolfCount: settings.werewolfCount,
    effectiveWerewolfCount: settings.effectiveWerewolfCount,
    selectedRoles: settings.selectedRoles,
    hostIsGameMaster: settings.hostIsGameMaster,
  };
}

function viewImpostorSettings(room: RoomView): string {
  const settings = room.impostorSettings;
  const current = settings.customWord
    ? `<p class="hint">Eigenes Wort: <strong>${esc(settings.customWord)}</strong>. Du spielst die nächste Runde nicht mit.</p>
       <button class="btn quiet" data-action="clearWord">Wort entfernen, Wortliste nehmen</button>`
    : "";

  return `
    ${viewImpostorOptions(impostorForm(room))}

    <div class="settings-group">
      <label class="field">
        <span>Eigenes Wort (optional)</span>
        <input id="custom-word" data-bind="customWordDraft" maxlength="30" autocomplete="off"
               value="${esc(state.customWordDraft)}" placeholder="leer lassen = Wortliste" />
      </label>
      <button class="btn small" data-action="saveWord">Wort übernehmen</button>
      ${current}
    </div>`;
}

function viewImpostorSettingsSummary(room: RoomView): string {
  const lines = impostorSummary(impostorForm(room));
  if (room.impostorSettings.customWordSet) lines.push("Die Spielleitung hat ein eigenes Wort gewählt und spielt nicht mit.");
  return viewSummary(lines);
}

// ---- Werwolf --------------------------------------------------------------

function viewWerwolf(room: RoomView, werwolf: WerwolfView): string {
  const night = room.phase === "NIGHT";
  const heading = `${night ? "Nacht" : "Tag"} ${room.round}`;
  const hint = night
    ? "Alle schließen die Augen. Die Spielleitung ruft die Rollen nacheinander auf."
    : "Diskutiert, wer ein Werwolf sein könnte, und stimmt ab.";

  const hostControls = room.you.host
    ? `<button class="btn primary" data-action="nextPhase">${night ? "Weiter zum Tag" : "Weiter zur Nacht"}</button>
       <button class="btn quiet" data-action="backToLobby">Spiel beenden</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;

  if (werwolf.role) preloadRoleImages([werwolf.role.id]);
  const card = werwolf.gameMaster
    ? viewRoleOverview(
        (werwolf.overview ?? []).map((a) => ({ name: a.playerName, role: a.role })),
        werwolf.leftoverRoles,
      )
    : viewSecretCard(
        roleCardVariant(werwolf.role!),
        "um deine Rolle zu sehen",
        roleCardContent(werwolf.role!, werwolf.knownWolves, werwolf.leftoverRoles),
      );

  return `
    <header class="phase-head">
      <p class="game-label">Werwolf</p>
      <h1 class="title">${heading}</h1>
      <p class="lead">${hint}</p>
    </header>

    ${card}
    ${viewPlayers(room)}

    <div class="actions">${hostControls}</div>
  `;
}

// ---- Impostor -------------------------------------------------------------

function viewImpostor(room: RoomView, impostor: ImpostorView): string {
  const label = `<p class="game-label">Impostor · Runde ${room.round}</p>`;
  if (room.phase === "RESULT" && impostor.result) {
    return label + viewImpostorResult(room, impostor);
  }

  const voting = room.phase === "VOTING";
  const title = voting ? "Abstimmung" : "Hinweise";
  const lead = voting
    ? "Wer ist der Impostor? Tippe auf einen Namen. Du kannst deine Stimme noch ändern."
    : "Reihum sagt jeder ein Wort als Hinweis. Nicht zu deutlich, sonst errät der Impostor das Wort.";

  const hostControls = room.you.host
    ? `${voting ? "" : `<button class="btn primary" data-action="startVoting">Zur Abstimmung</button>`}
       <button class="btn quiet" data-action="backToLobby">Spiel beenden</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;

  return `
    <header class="phase-head">
      ${label}
      <h1 class="title">${title}</h1>
      <p class="lead">${lead}</p>
    </header>

    ${voting ? viewVoting(room, impostor) : ""}
    ${viewWordCard(impostor)}
    ${voting ? "" : viewStartPlayer(room, impostor)}
    ${voting ? "" : viewPlayers(room, { only: impostor.participantIds })}

    <div class="actions">${hostControls}</div>
  `;
}

function viewWordCard(impostor: ImpostorView): string {
  if (impostor.part === "GAME_MASTER") {
    return `
      <section class="game-master">
        <p>Du leitest diese Runde und spielst nicht mit.</p>
        <p>Das Wort: <strong>${esc(impostor.word ?? "")}</strong></p>
      </section>`;
  }

  const isImpostor = impostor.part === "IMPOSTOR";
  return viewSecretCard(
    isImpostor ? "role-impostor" : "role-crew",
    "um dein Wort zu sehen",
    impostorCardContent(isImpostor, impostor.word, impostor.category, impostor.fellowImpostors),
  );
}

function viewStartPlayer(room: RoomView, impostor: ImpostorView): string {
  const start = room.players.find((p) => p.id === impostor.startPlayerId);
  if (!start) return "";
  const name = start.id === room.you.id ? "Du fängst" : `<strong>${esc(start.name)}</strong> fängt`;
  return `<p class="start-player">${name} an.</p>`;
}

function viewVoting(room: RoomView, impostor: ImpostorView): string {
  const voted = new Set(impostor.votedIds);
  const participants = room.players.filter((p) => impostor.participantIds.includes(p.id));
  const progress = `<p class="hint">${voted.size} von ${participants.filter((p) => p.connected).length} haben abgestimmt.</p>`;

  if (impostor.part === "GAME_MASTER") {
    return `${progress}${viewPlayers(room, { only: impostor.participantIds, votedIds: voted })}`;
  }

  const options = participants
    .filter((p) => p.id !== room.you.id)
    .map((p) => {
      const chosen = impostor.yourVote === p.id;
      return `
        <li>
          <button class="vote-option ${chosen ? "is-selected" : ""}" data-action="vote" data-value="${p.id}"
                  aria-pressed="${chosen}">
            <span class="player-name">${esc(p.name)}</span>
            <span class="player-note">${voted.has(p.id) ? "hat abgestimmt" : ""}</span>
          </button>
        </li>`;
    })
    .join("");

  return `
    <section class="voting">
      ${progress}
      <ul>${options}</ul>
    </section>`;
}

function viewImpostorResult(room: RoomView, impostor: ImpostorView): string {
  const result = impostor.result!;
  const several = result.impostorIds.length > 1;
  const youWereImpostor = result.impostorIds.includes(room.you.id);
  const title = result.impostorCaught ? "Erwischt!" : several ? "Die Impostor gewinnen!" : "Der Impostor gewinnt!";
  const names = result.impostorNames.map(esc).join(" und ");
  let lead = several ? `${names} waren die Impostor.` : `${names} war der Impostor.`;
  if (youWereImpostor && !several) {
    lead = result.impostorCaught ? "Sie haben dich durchschaut." : "Du hast alle getäuscht.";
  }
  const category = result.category ? ` <span class="hint">(${esc(result.category)})</span>` : "";
  const votes = new Map(result.votes.map((v) => [v.playerId, v.votes]));

  const hostControls = room.you.host
    ? `<button class="btn primary" data-action="nextRound" ${room.canStart ? "" : "disabled"}>Nächste Runde</button>
       <button class="btn quiet" data-action="backToLobby">Zurück zur Lobby</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;
  const waitHint =
    room.canStart && !room.you.host ? "Alle sind bereit. Die Spielleitung startet die nächste Runde." : room.startHint;

  return `
    <header class="phase-head">
      <h1 class="title">${title}</h1>
      <p class="lead">${lead}</p>
    </header>

    <section class="result-word">
      <p>Das Wort war</p>
      <strong>${esc(result.word)}</strong>${category}
    </section>

    ${viewPlayers(room, { showReady: true, votes, impostorIds: new Set(result.impostorIds) })}

    <div class="actions">
      ${viewReadyButton(room)}
      ${hostControls}
      ${waitHint ? `<p class="hint">${esc(waitHint)}</p>` : ""}
    </div>
  `;
}

// ---- Gemeinsame Bausteine -------------------------------------------------

/** Karte, die ihren Inhalt nur zeigt, solange man sie gedrückt hält. */
function viewSecretCard(variant: string, what: string, openContent: string): string {
  const inner = state.revealing
    ? openContent
    : `<span class="role-hidden">Gedrückt halten,<br />${what}</span>`;
  return `
    <button class="role-card ${state.revealing ? "is-open" : ""} ${variant}"
            data-reveal aria-label="Gedrückt halten, ${what}">
      ${inner}
    </button>`;
}

interface PlayerListOptions {
  showReady?: boolean;
  /** Zeigt „3 / 20“ statt nur „3“. */
  showLimit?: boolean;
  /** Host sieht neben jedem anderen Spieler einen Knopf zum Entfernen. */
  kickable?: boolean;
  only?: string[];
  votedIds?: Set<string>;
  /** Stimmen nach der Abstimmung. Ist das gesetzt, wird nach Stimmen sortiert. */
  votes?: Map<string, number>;
  impostorIds?: Set<string>;
}

function viewPlayers(room: RoomView, options: PlayerListOptions = {}): string {
  let players = options.only ? room.players.filter((p) => options.only!.includes(p.id)) : room.players;
  if (options.votes) {
    const votesOf = (p: PlayerView) => options.votes!.get(p.id) ?? -1;
    // sort() ist stabil, bei Gleichstand bleibt die Beitrittsreihenfolge
    players = [...players].sort((a, b) => votesOf(b) - votesOf(a));
  }
  const items = players.map((p) => viewPlayerItem(room, p, options)).join("");
  const count = options.showLimit ? `${players.length} / ${room.playerLimit.value}` : `${players.length}`;

  return `
    <section class="players">
      <h2>Mitspieler <span class="count">${count}</span></h2>
      <ul>${items}</ul>
    </section>`;
}

function viewPlayerItem(room: RoomView, p: PlayerView, options: PlayerListOptions): string {
  const notes: string[] = [];
  const voteCount = options.votes?.get(p.id);
  if (voteCount !== undefined) notes.push(`${voteCount} ${voteCount === 1 ? "Stimme" : "Stimmen"}`);
  if (p.id === room.you.id) notes.push("du");
  if (p.id === room.hostId) notes.push("Spielleitung");
  if (options.showReady && p.ready) notes.push("bereit");
  if (options.votedIds?.has(p.id)) notes.push("hat abgestimmt");
  if (!p.connected) notes.push("offline");

  const classes = [
    p.alive ? "" : "is-dead",
    p.connected ? "" : "is-offline",
    options.showReady && p.ready ? "is-ready" : "",
    options.impostorIds?.has(p.id) ? "is-impostor" : "",
  ];
  const kickButton =
    options.kickable && p.id !== room.you.id
      ? `<button class="kick" data-action="kick" data-value="${p.id}" aria-label="${esc(p.name)} entfernen">✗</button>`
      : "";
  return `
    <li class="${classes.join(" ").trim()}">
      <span class="player-name">${esc(p.name)}</span>
      <span class="player-side">
        ${notes.length ? `<span class="player-note">${notes.join(" · ")}</span>` : ""}
        ${kickButton}
      </span>
    </li>`;
}

function viewFooter(): string {
  return `
    <footer class="site-footer">
      <a href="./impressum.html">Impressum</a>
      <a href="./datenschutz.html">Datenschutz</a>
      <button class="link-button" data-action="forgetDevice">Meine Daten löschen</button>
    </footer>`;
}

// ---------------------------------------------------------------------------
// Ereignisse

app.addEventListener("click", (event) => {
  const target = (event.target as HTMLElement).closest<HTMLElement>("[data-action]");
  if (target && !(target as HTMLButtonElement).disabled) {
    act(target.dataset.action!, target.dataset.value);
  }
});

app.addEventListener("input", (event) => {
  const input = event.target as HTMLInputElement;
  if (state.local && inputLocal(state.local, input)) return;
  if (input.dataset.bind === "name") state.name = input.value;
  if (input.dataset.bind === "customWordDraft") state.customWordDraft = input.value;
  if (input.dataset.bind === "answerDraft") state.answerDraft = input.value;
  if (input.dataset.bind === "codeInput") {
    input.value = input.value.toUpperCase();
    state.codeInput = input.value;
  }
});

app.addEventListener("change", (event) => {
  const input = event.target as HTMLInputElement;
  if (state.local) {
    changeLocal(state.local, input, localUi);
    return;
  }
  if (input.dataset.setting === "seesCategory") configureImpostor({ seesCategory: input.checked });
  if (input.dataset.setting === "randomStart") setImpostorOptions({ randomStartPlayer: input.checked });
  if (input.dataset.setting === "gameMaster") configureWerwolf({ hostIsGameMaster: input.checked });
  if (input.dataset.setting === "autoTeams") configureTabu({ autoTeams: input.checked });
  if (input.dataset.role !== undefined) {
    const roles = [...app.querySelectorAll<HTMLInputElement>("[data-role]")]
      .filter((box) => box.checked)
      .map((box) => box.dataset.role!);
    configureWerwolf({ roles });
  }
  if (input.dataset.category !== undefined) {
    const categories = [...app.querySelectorAll<HTMLInputElement>("[data-category]")]
      .filter((box) => box.checked)
      .map((box) => box.dataset.category!);
    sendOrComplain({ type: "setImpostorCategories", categories });
  }
});

app.addEventListener("keydown", (event) => {
  const input = event.target as HTMLElement;
  if (event.key === "Enter" && input.id === "code") act("join");
  if (event.key === "Enter" && input.id === "name") act(state.codeInput ? "join" : "create");
  if (event.key === "Enter" && input.id === "custom-word") act("saveWord");
  if (event.key === "Enter" && input.id === "answer") act("submitAnswer");
  if (event.key === "Enter" && input.id === "local-answer") act("localSubmitAnswer");
  if ((event.key === " " || event.key === "Enter") && input.hasAttribute("data-reveal") && !event.repeat) {
    event.preventDefault();
    setRevealing(true);
  }
});

app.addEventListener("keyup", (event) => {
  if (event.key === " " || event.key === "Enter") setRevealing(false);
});

// Karte nur aufdecken, solange der Finger darauf liegt
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

// Uhren weiterzählen. Lokal endet hier auch der Zug, online macht das der Server.
window.setInterval(() => {
  updateCountdowns(app);
  if (state.local) tickLocal(state.local, localUi);
}, 250);

render();
void connection.start();
