// Lokaler Modus: Ein Handy wird reihum weitergegeben, jeder sieht kurz seine Karte.
// Läuft komplett im Browser, ohne Server. Nur die Einrichtung (Namen, Einstellungen) wird gespeichert.
import { askConfirm } from "./confirmDialog";
import { CATEGORIES, MAX_IMPOSTORS, MAX_PLAYERS, MIN_PLAYERS, SEER, TEAM_NAMES } from "./gameData";
import { esc } from "./html";
import {
  dealImpostor,
  dealWerwolf,
  duplicateName,
  impostorProblem,
  knownWolves,
  normalizeRoles,
  playerNames,
  werewolves,
  werwolfProblem,
  type ImpostorDeal,
  type WerwolfDeal,
} from "./localGames";
import {
  impostorCardContent,
  roleCardContent,
  roleCardVariant,
  viewImpostorOptions,
  viewRoleOverview,
  viewStepper,
  viewWerwolfOptions,
} from "./sharedViews";
import type { GameType } from "./types";

const STORAGE_KEY = "arynta.local";
const DEFAULT_PLAYERS = 5;
const ALL_CATEGORIES = CATEGORIES.map((c) => c.name);

export interface LocalSetup {
  game: GameType;
  playerCount: number;
  /** Eingegebene Namen, leere werden zu „Spieler 1“ usw. */
  names: string[];
  impostorCount: number;
  seesCategory: boolean;
  randomStartPlayer: boolean;
  categories: string[];
  /** null = automatisch. */
  werewolfCount: number | null;
  roles: string[];
}

type Stage = "setup" | "pass" | "card" | "table" | "reveal";

export interface LocalState {
  setup: LocalSetup;
  stage: Stage;
  /** Namen der laufenden Runde, in Weitergabe-Reihenfolge. */
  players: string[];
  /** Wer gerade das Handy hat. */
  index: number;
  impostor: ImpostorDeal | null;
  werwolf: WerwolfDeal | null;
  usedWords: string[];
  overviewOpen: boolean;
}

/** Was der lokale Modus von main.ts braucht. */
export interface LocalUi {
  render(): void;
  toast(text: string): void;
  exit(): void;
}

export function createLocalState(): LocalState {
  return {
    setup: loadSetup(),
    stage: "setup",
    players: [],
    index: 0,
    impostor: null,
    werwolf: null,
    usedWords: [],
    overviewOpen: false,
  };
}

/** Löscht die gespeicherte Einrichtung (für „Meine Daten löschen“). */
export function forgetLocalSetup(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch {
    // Speicher nicht verfügbar, dann gibt es auch nichts zu löschen
  }
}

// ---------------------------------------------------------------------------
// Aktionen

/** Gibt true zurück, wenn die Aktion zum lokalen Modus gehört. */
export function actLocal(local: LocalState, action: string, value: string | undefined, ui: LocalUi): boolean {
  const setup = local.setup;
  const step = Number(value);
  switch (action) {
    case "localGame":
      setup.game = value === "WERWOLF" ? "WERWOLF" : "IMPOSTOR";
      break;
    case "localPlayers":
      setup.playerCount = clamp(setup.playerCount + step, MIN_PLAYERS.IMPOSTOR, MAX_PLAYERS);
      break;
    case "changeImpostorCount":
      setup.impostorCount = clamp(setup.impostorCount + step, 1, maxImpostors(setup.playerCount));
      break;
    case "changeWerewolfCount":
      setup.werewolfCount = clamp(werewolves(setup.playerCount, setup.werewolfCount) + step, 1, MAX_PLAYERS - 1);
      break;
    case "autoWerewolves":
      setup.werewolfCount = null;
      break;
    case "localStart":
      startRound(local, ui);
      return true;
    case "localShow":
      local.stage = "card";
      break;
    case "localNext":
      local.index++;
      local.stage = local.index < local.players.length ? "pass" : "table";
      break;
    case "localReveal":
      void confirmThen(ui, "Auflösen? Danach sehen alle, wer Impostor war.", "Ja, auflösen", () => {
        local.stage = "reveal";
      });
      return true;
    case "localOverview":
      void confirmThen(ui, "Nur die Spielleitung darf jetzt hinschauen. Alle Rollen zeigen?", "Ja, zeigen", () => {
        local.overviewOpen = true;
      });
      return true;
    case "localHideOverview":
      local.overviewOpen = false;
      break;
    case "localRedeal":
      void confirmThen(ui, "Rollen neu verteilen? Das Handy geht dann wieder reihum.", "Ja, neu verteilen", () =>
        startRound(local, ui),
      );
      return true;
    case "localNewRound":
      startRound(local, ui);
      return true;
    case "localSetup":
      if (local.stage === "setup" || local.stage === "reveal") {
        local.stage = "setup";
        break;
      }
      void confirmThen(ui, "Runde abbrechen und zurück zu den Einstellungen?", "Ja, abbrechen", () => {
        local.stage = "setup";
      });
      return true;
    case "localExit":
      if (local.stage === "setup") {
        ui.exit();
        return true;
      }
      void askConfirm("Lokales Spiel beenden?", "Ja, beenden").then((yes) => yes && ui.exit());
      return true;
    default:
      return false;
  }
  saveSetup(setup);
  ui.render();
  return true;
}

/** Häkchen und Namensfelder. Gibt true zurück, wenn das Feld zum lokalen Modus gehört. */
export function changeLocal(local: LocalState, input: HTMLInputElement, ui: LocalUi): boolean {
  const setup = local.setup;
  if (input.dataset.setting === "seesCategory") setup.seesCategory = input.checked;
  else if (input.dataset.setting === "randomStart") setup.randomStartPlayer = input.checked;
  else if (input.dataset.category !== undefined) setup.categories = checkedValues("category").filter((c) => ALL_CATEGORIES.includes(c));
  else if (input.dataset.role !== undefined) setup.roles = normalizeRoles(checkedValues("role"));
  else return false;
  saveSetup(setup);
  ui.render();
  return true;
}

/** Tippen in ein Namensfeld. Kein Neuzeichnen, damit der Cursor bleibt. */
export function inputLocal(local: LocalState, input: HTMLInputElement): boolean {
  if (input.dataset.bind !== "localName") return false;
  local.setup.names[Number(input.dataset.index)] = input.value;
  saveSetup(local.setup);
  return true;
}

function startRound(local: LocalState, ui: LocalUi): void {
  const setup = local.setup;
  const problem = setupProblem(setup);
  if (problem) {
    ui.toast(problem);
    return;
  }
  local.players = playerNames(setup.playerCount, setup.names);
  if (setup.game === "IMPOSTOR") {
    local.impostor = dealImpostor(
      setup.playerCount,
      { impostorCount: setup.impostorCount, randomStartPlayer: setup.randomStartPlayer, categories: setup.categories },
      local.usedWords,
      Math.random,
    );
    local.usedWords.push(local.impostor.word);
    local.werwolf = null;
  } else {
    local.werwolf = dealWerwolf(setup.playerCount, setup.werewolfCount, setup.roles, Math.random);
    local.impostor = null;
  }
  local.index = 0;
  local.overviewOpen = false;
  local.stage = "pass";
  ui.render();
}

async function confirmThen(ui: LocalUi, question: string, yes: string, then: () => void): Promise<void> {
  if (await askConfirm(question, yes)) {
    then();
    ui.render();
  }
}

function setupProblem(setup: LocalSetup): string | null {
  const duplicate = duplicateName(playerNames(setup.playerCount, setup.names));
  if (duplicate) return `Der Name „${duplicate}“ kommt doppelt vor.`;
  return setup.game === "IMPOSTOR"
    ? impostorProblem(setup.playerCount, setup.impostorCount)
    : werwolfProblem(setup.playerCount, setup.werewolfCount, setup.roles);
}

// ---------------------------------------------------------------------------
// Darstellung

export function viewLocal(local: LocalState): string {
  switch (local.stage) {
    case "setup":
      return viewSetup(local.setup);
    case "pass":
      return viewPass(local);
    case "card":
      return viewCard(local);
    case "table":
      return local.impostor ? viewImpostorTable(local, local.impostor) : viewWerwolfTable(local, local.werwolf!);
    case "reveal":
      return viewImpostorReveal(local, local.impostor!);
  }
}

function viewSetup(setup: LocalSetup): string {
  const problem = setupProblem(setup);
  const gameButton = (type: GameType, name: string, description: string) => {
    const active = setup.game === type;
    return `
      <button class="game-option ${active ? "is-selected" : ""}" data-action="localGame" data-value="${type}" aria-pressed="${active}">
        <strong>${name}</strong>
        <span class="game-min">ab ${MIN_PLAYERS[type]} Spielern</span>
        <span class="game-desc">${description}</span>
      </button>`;
  };

  const settings =
    setup.game === "IMPOSTOR"
      ? viewImpostorOptions({
          impostorCount: setup.impostorCount,
          maxImpostorCount: maxImpostors(setup.playerCount),
          seesCategory: setup.seesCategory,
          randomStartPlayer: setup.randomStartPlayer,
          allCategories: ALL_CATEGORIES,
          selectedCategories: setup.categories,
          categoryHint: "Das Wort kommt zufällig aus den angekreuzten Kategorien.",
        })
      : viewWerwolfOptions({
          werewolfCount: setup.werewolfCount,
          effectiveWerewolfCount: werewolves(setup.playerCount, setup.werewolfCount),
          selectedRoles: setup.roles,
        });

  const nameFields = Array.from({ length: setup.playerCount }, (_, i) => {
    return `
      <input id="local-name-${i}" data-bind="localName" data-index="${i}" maxlength="20" autocomplete="off"
             aria-label="Name von Spieler ${i + 1}" value="${esc(setup.names[i] ?? "")}" placeholder="Spieler ${i + 1}" />`;
  }).join("");

  return `
    <header class="phase-head">
      <p class="game-label">Ein Handy für alle</p>
      <h1 class="title">Lokal spielen</h1>
      <p class="lead">Das Handy geht reihum. Jeder schaut kurz auf seine Karte und gibt es weiter. Kein Internet nötig.</p>
    </header>

    <section class="game-picker">
      <h2>Spiel</h2>
      <div class="game-options">
        ${gameButton("IMPOSTOR", "Impostor", "Alle kennen ein geheimes Wort, nur die Impostor nicht.")}
        ${gameButton("WERWOLF", "Werwolf", "Das Handy verteilt nur die Rollen. Den Rest leitet ihr am Tisch.")}
      </div>
    </section>

    <section class="settings">
      ${viewStepper("local-players", "Spieler", setup.playerCount, MIN_PLAYERS.IMPOSTOR, MAX_PLAYERS, "localPlayers")}
      ${setup.game === "WERWOLF" ? `<p class="hint">Die Spielleitung zählt nicht mit, sie bekommt keine Karte.</p>` : ""}
      <div class="settings-group">
        <span class="settings-label">Namen (optional)</span>
        <div class="name-list">${nameFields}</div>
      </div>
      ${settings}
    </section>

    <div class="actions">
      <button class="btn primary" data-action="localStart" ${problem ? "disabled" : ""}>Karten verteilen</button>
      ${problem ? `<p class="hint">${esc(problem)}</p>` : ""}
      <button class="btn quiet" data-action="localExit">Zurück zum Start</button>
    </div>`;
}

function viewPass(local: LocalState): string {
  const name = esc(local.players[local.index]);
  return `
    <header class="phase-head pass-head">
      <p class="game-label">Karte ${local.index + 1} von ${local.players.length}</p>
      <h1 class="title">Gib das Handy an ${name}</h1>
      <p class="lead">Nur ${name} darf auf den Bildschirm schauen.</p>
    </header>
    <div class="actions">
      <button class="btn primary" data-action="localShow">Ich bin ${name}, Karte zeigen</button>
      <button class="btn quiet" data-action="localSetup">Runde abbrechen</button>
    </div>`;
}

function viewCard(local: LocalState): string {
  const last = local.index === local.players.length - 1;
  let variant: string;
  let content: string;
  if (local.impostor) {
    const deal = local.impostor;
    const isImpostor = deal.impostors.includes(local.index);
    const category = !isImpostor || local.setup.seesCategory ? deal.category : null;
    const fellows = isImpostor ? deal.impostors.filter((i) => i !== local.index).map((i) => local.players[i]) : [];
    variant = isImpostor ? "role-impostor" : "role-crew";
    content = impostorCardContent(isImpostor, deal.word, category, fellows);
  } else {
    const deal = local.werwolf!;
    const role = deal.perPlayer[local.index];
    const card = { ...role, teamName: TEAM_NAMES[role.team] };
    const leftover = role.id === "DIEB" ? deal.leftover.map((r) => r.name) : [];
    variant = roleCardVariant(card);
    content = roleCardContent(card, knownWolves(deal, local.players, local.index), leftover);
  }

  return `
    <header class="phase-head">
      <p class="game-label">Karte von ${esc(local.players[local.index])}</p>
    </header>
    <div class="role-card is-open ${variant}">${content}</div>
    <div class="actions">
      <button class="btn primary" data-action="localNext">${last ? "Verstecken, alle haben ihre Karte" : "Verstecken und weitergeben"}</button>
    </div>`;
}

function viewImpostorTable(local: LocalState, deal: ImpostorDeal): string {
  const start =
    deal.startPlayer !== null ? `<p class="start-player"><strong>${esc(local.players[deal.startPlayer])}</strong> fängt an.</p>` : "";
  return `
    <header class="phase-head">
      <p class="game-label">Impostor</p>
      <h1 class="title">Alle kennen ihr Wort</h1>
      <p class="lead">Reihum sagt jeder ein Wort als Hinweis. Dann zeigt ihr gleichzeitig auf euren Verdacht.</p>
    </header>
    ${start}
    <div class="actions">
      <button class="btn primary" data-action="localReveal">Auflösen</button>
      <button class="btn quiet" data-action="localSetup">Runde abbrechen</button>
    </div>`;
}

function viewImpostorReveal(local: LocalState, deal: ImpostorDeal): string {
  const names = deal.impostors.map((i) => `<strong>${esc(local.players[i])}</strong>`);
  const who = names.length === 1 ? `${names[0]} war der Impostor.` : `${names.join(" und ")} waren die Impostor.`;
  return `
    <header class="phase-head">
      <p class="game-label">Impostor</p>
      <h1 class="title">Auflösung</h1>
      <p class="lead">${who}</p>
    </header>
    <section class="result-word">
      <p>Das Wort war</p>
      <strong>${esc(deal.word)}</strong> <span class="hint">(${esc(deal.category)})</span>
    </section>
    <div class="actions">
      <button class="btn primary" data-action="localNewRound">Nächste Runde</button>
      <button class="btn quiet" data-action="localSetup">Einstellungen ändern</button>
    </div>`;
}

function viewWerwolfTable(local: LocalState, deal: WerwolfDeal): string {
  const overview = local.overviewOpen
    ? `${viewRoleOverview(
        local.players.map((name, i) => ({ name, role: { ...deal.perPlayer[i], teamName: TEAM_NAMES[deal.perPlayer[i].team] } })),
        deal.leftover.map((r) => r.name),
      )}
       <button class="btn" data-action="localHideOverview">Übersicht verstecken</button>`
    : `<button class="btn" data-action="localOverview">Spielleitung: alle Rollen zeigen</button>`;
  return `
    <header class="phase-head">
      <p class="game-label">Werwolf</p>
      <h1 class="title">Alle kennen ihre Rolle</h1>
      <p class="lead">Die Spielleitung führt jetzt durch Nacht und Tag.</p>
    </header>
    <div class="actions">
      ${overview}
      <button class="btn quiet" data-action="localRedeal">Neu verteilen</button>
      <button class="btn quiet" data-action="localSetup">Einstellungen ändern</button>
    </div>`;
}

// ---------------------------------------------------------------------------
// Hilfsfunktionen

function maxImpostors(playerCount: number): number {
  return clamp(Math.floor(playerCount / 2) - 1, 1, MAX_IMPOSTORS);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function checkedValues(attribute: "category" | "role"): string[] {
  return [...document.querySelectorAll<HTMLInputElement>(`[data-${attribute}]`)]
    .filter((box) => box.checked)
    .map((box) => box.dataset[attribute]!);
}

function loadSetup(): LocalSetup {
  const defaults: LocalSetup = {
    game: "IMPOSTOR",
    playerCount: DEFAULT_PLAYERS,
    names: [],
    impostorCount: 1,
    seesCategory: true,
    randomStartPlayer: true,
    categories: ALL_CATEGORIES,
    werewolfCount: null,
    roles: [SEER],
  };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaults;
    const saved = { ...defaults, ...(JSON.parse(raw) as Partial<LocalSetup>) };
    // Gespeicherte Werte können von einer älteren Version stammen, deshalb absichern
    saved.playerCount = clamp(Number(saved.playerCount) || DEFAULT_PLAYERS, MIN_PLAYERS.IMPOSTOR, MAX_PLAYERS);
    saved.names = Array.isArray(saved.names) ? saved.names.map(String) : [];
    saved.categories = ALL_CATEGORIES.filter((c) => saved.categories.includes(c));
    if (saved.categories.length === 0) saved.categories = ALL_CATEGORIES;
    saved.roles = normalizeRoles(Array.isArray(saved.roles) ? saved.roles : []);
    saved.impostorCount = clamp(Number(saved.impostorCount) || 1, 1, MAX_IMPOSTORS);
    saved.werewolfCount =
      typeof saved.werewolfCount === "number" ? clamp(saved.werewolfCount, 1, MAX_PLAYERS - 1) : null;
    return saved;
  } catch {
    return defaults;
  }
}

function saveSetup(setup: LocalSetup): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(setup));
  } catch {
    // privater Modus o. ä.: Dann sind die Einstellungen beim nächsten Mal einfach weg
  }
}
