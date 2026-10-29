// Bausteine, die online (Lobby) und lokal (ein Handy) gleich aussehen.
// Die Eingaben tragen data-setting, data-category, data-role bzw. data-action. Was beim Ändern
// passiert, entscheidet main.ts (an den Server schicken) oder localMode.ts (lokal merken).
import { NOBODY_IS_PERFECT, MAX_PLAYERS, ROLE_IMAGES, SPECIAL_ROLES, TEAM_IDS, TEAM_NAMES, TABU, roleById } from "./gameData";
import { esc } from "./html";

export function viewStepper(id: string, label: string, value: number, min: number, max: number, action: string): string {
  return `
    <div class="setting-row">
      <span id="${id}-label">${esc(label)}</span>
      <div class="stepper" role="group" aria-labelledby="${id}-label">
        <button class="btn small" data-action="${action}" data-value="-1"
                aria-label="${esc(label)} verringern" ${value <= min ? "disabled" : ""}>−</button>
        <output aria-live="polite">${value}</output>
        <button class="btn small" data-action="${action}" data-value="1"
                aria-label="${esc(label)} erhöhen" ${value >= max ? "disabled" : ""}>+</button>
      </div>
    </div>`;
}

function viewCheck(id: string, attribute: string, checked: boolean, label: string, extra = ""): string {
  return `
    <label class="check">
      <input type="checkbox" id="${id}" ${attribute} ${checked ? "checked" : ""} ${extra} />
      <span>${label}</span>
    </label>`;
}

// ---- Impostor --------------------------------------------------------------

export interface ImpostorForm {
  impostorCount: number;
  maxImpostorCount: number;
  seesCategory: boolean;
  randomStartPlayer: boolean;
  allCategories: string[];
  selectedCategories: string[];
  categoryHint: string;
}

export function viewImpostorOptions(form: ImpostorForm): string {
  return `
    <div class="settings-group">
      ${viewStepper("impostor-count", "Anzahl Impostor", form.impostorCount, 1, form.maxImpostorCount, "changeImpostorCount")}
      ${viewCheck("sees-category", `data-setting="seesCategory"`, form.seesCategory, "Impostor sieht die Kategorie")}
      ${viewCheck("random-start", `data-setting="randomStart"`, form.randomStartPlayer, "Startspieler auslosen")}
    </div>
    ${viewCategoryChoice(form)}`;
}

function viewCategoryChoice(form: ImpostorForm): string {
  const selected = new Set(form.selectedCategories);
  const onlyOneLeft = selected.size === 1;

  const boxes = form.allCategories
    .map((name, index) => {
      const checked = selected.has(name);
      // Die letzte angekreuzte Kategorie lässt sich nicht abwählen, ohne Kategorie gäbe es kein Wort
      const locked = checked && onlyOneLeft;
      return `
        <label class="check category">
          <input type="checkbox" id="category-${index}" data-category="${esc(name)}"
                 ${checked ? "checked" : ""} ${locked ? "disabled" : ""} />
          <span>${esc(name)}</span>
        </label>`;
    })
    .join("");

  return `
    <div class="settings-group" role="group" aria-labelledby="categories-label">
      <span id="categories-label" class="settings-label">Kategorien</span>
      <div class="category-grid">${boxes}</div>
      <p class="hint">${esc(form.categoryHint)}</p>
    </div>`;
}

export function impostorSummary(form: ImpostorForm): string[] {
  const allSelected = form.selectedCategories.length === form.allCategories.length;
  return [
    `Anzahl Impostor: <strong>${form.impostorCount}</strong>`,
    `Impostor sieht die Kategorie: <strong>${form.seesCategory ? "an" : "aus"}</strong>`,
    `Startspieler auslosen: <strong>${form.randomStartPlayer ? "an" : "aus"}</strong>`,
    `Kategorien: <strong>${allSelected ? "alle" : form.selectedCategories.map(esc).join(", ")}</strong>`,
  ];
}

// ---- Werwolf ---------------------------------------------------------------

export interface WerwolfForm {
  /** null = automatisch. */
  werewolfCount: number | null;
  effectiveWerewolfCount: number;
  selectedRoles: string[];
  /** Nur online: Host spielt nicht mit und sieht alle Rollen. undefined = Schalter nicht zeigen. */
  hostIsGameMaster?: boolean;
}

export function viewWerwolfOptions(form: WerwolfForm): string {
  const auto = form.werewolfCount === null;
  const autoControl = auto
    ? `<p class="hint">Automatisch: 1 Werwolf pro 4 Spieler.</p>`
    : `<button class="btn small" data-action="autoWerewolves">Wieder automatisch</button>`;
  const gameMaster =
    form.hostIsGameMaster === undefined
      ? ""
      : `<div class="settings-group">
           ${viewCheck("game-master", `data-setting="gameMaster"`, form.hostIsGameMaster, "Ich leite das Spiel und spiele nicht mit")}
           <p class="hint">Die Spielleitung sieht dann alle Rollen.</p>
         </div>`;

  return `
    ${gameMaster}
    <div class="settings-group">
      ${viewStepper("werewolf-count", "Werwölfe", form.effectiveWerewolfCount, 1, MAX_PLAYERS - 1, "changeWerewolfCount")}
      ${autoControl}
    </div>
    ${viewRoleChoice(form.selectedRoles)}`;
}

function viewRoleChoice(selectedRoles: string[]): string {
  const selected = new Set(selectedRoles);
  const groups = TEAM_IDS.map((team) => {
    const boxes = SPECIAL_ROLES.filter((r) => r.team === team)
      .map(
        (role) => `
          <label class="check role-option">
            <input type="checkbox" id="role-${role.id}" data-role="${role.id}" ${selected.has(role.id) ? "checked" : ""} />
            <span><strong>${esc(role.name)}</strong><small>${esc(role.description)}</small></span>
          </label>`,
      )
      .join("");
    return `
      <fieldset class="role-group">
        <legend>${esc(TEAM_NAMES[team])}</legend>
        ${boxes}
      </fieldset>`;
  }).join("");

  return `
    <div class="settings-group">
      <span class="settings-label">Sonderrollen</span>
      ${groups}
      <p class="hint">Jede Rolle gibt es einmal. Alle übrigen Spieler sind Dorfbewohner.</p>
    </div>`;
}

export function werwolfSummary(form: WerwolfForm): string[] {
  const roles = form.selectedRoles.map((id) => esc(roleById(id).name)).join(", ") || "keine";
  const lines = [
    `Werwölfe: <strong>${form.effectiveWerewolfCount}${form.werewolfCount === null ? " (automatisch)" : ""}</strong>`,
    `Sonderrollen: <strong>${roles}</strong>`,
  ];
  if (form.hostIsGameMaster) lines.push("Die Spielleitung spielt nicht mit.");
  return lines;
}

export function viewSummary(lines: string[]): string {
  return `<ul class="settings-summary settings-group">${lines.map((l) => `<li>${l}</li>`).join("")}</ul>`;
}

// ---- Karteninhalt ----------------------------------------------------------

export interface RoleCardContent {
  id: string;
  name: string;
  team: string;
  teamName: string;
  description: string;
}

/** CSS-Klasse für die Kartenfarbe nach Team. */
export function roleCardVariant(role: RoleCardContent): string {
  return `role-team-${role.team.toLowerCase()}`;
}

export function roleCardContent(role: RoleCardContent, knownWolves: string[], leftoverRoles: string[]): string {
  const data = roleById(role.id);
  let wolves = "";
  if (data.seesWolfPack) {
    wolves = knownWolves.length
      ? `<p class="wolves">Die Werwölfe: ${knownWolves.map(esc).join(", ")}</p>`
      : `<p class="wolves">Es gibt keine Werwölfe, die du kennst.</p>`;
  } else if (data.wolfPack) {
    wolves = knownWolves.length
      ? `<p class="wolves">Mit dir jagen: ${knownWolves.map(esc).join(", ")}</p>`
      : `<p class="wolves">Du jagst allein.</p>`;
  }
  const thief = leftoverRoles.length
    ? `<p class="wolves">Übrige Karten: ${leftoverRoles.map(esc).join(" und ")}</p>`
    : "";
  const image = ROLE_IMAGES[role.id];
  const title = image
    ? `<img class="role-image" src="${image}" alt="${esc(role.name)}" draggable="false" />`
    : `<span class="role-team">${esc(role.teamName)}</span>
       <span class="role-name">${esc(role.name)}</span>`;
  return `
    ${title}
    <p class="role-desc">${esc(role.description)}</p>
    ${wolves}${thief}`;
}

export function impostorCardContent(
  isImpostor: boolean,
  word: string | null,
  category: string | null,
  fellowImpostors: string[],
): string {
  if (!isImpostor) {
    const categoryLine = category ? `<p class="role-desc">Kategorie: ${esc(category)}</p>` : "";
    return `<span class="role-name">${esc(word ?? "")}</span>${categoryLine}`;
  }
  const categoryLine = category
    ? `<p class="role-desc">Kategorie: <strong>${esc(category)}</strong></p>`
    : `<p class="role-desc">Du kennst das Wort nicht. Hör gut zu und bluffe.</p>`;
  const fellows = fellowImpostors.length
    ? `<p class="wolves">Mit dir: ${fellowImpostors.map(esc).join(", ")}</p>`
    : "";
  return `<span class="role-name">Impostor</span>${categoryLine}${fellows}`;
}

/** Liste „Name – Rolle“ für die Spielleitung. */
export function viewRoleOverview(rows: { name: string; role: RoleCardContent }[], leftoverRoles: string[]): string {
  const items = rows
    .map(
      (row) => `
        <li class="${roleCardVariant(row.role)}">
          <span class="player-name">${esc(row.name)}</span>
          <span class="player-note">${esc(row.role.name)} · ${esc(row.role.teamName)}</span>
        </li>`,
    )
    .join("");
  const leftover = leftoverRoles.length
    ? `<p class="hint">Übrige Karten: ${leftoverRoles.map(esc).join(" und ")}</p>`
    : "";
  return `
    <section class="players role-overview">
      <h2>Alle Rollen</h2>
      <ul>${items}</ul>
      ${leftover}
    </section>`;
}

// ---- Tabu ------------------------------------------------------------

export interface TabuForm {
  turnSeconds: number;
  autoTeams: boolean;
  teamCount: number;
  targetScore: number;
}

export function viewTabuOptions(form: TabuForm): string {
  return `
    <div class="settings-group">
      ${viewStepper("turn-seconds", "Sekunden pro Zug", form.turnSeconds, TABU.minTurnSeconds, TABU.maxTurnSeconds, "changeTurnSeconds")}
      ${viewStepper("target-score", "Punkte bis zum Sieg", form.targetScore, TABU.minTargetScore, TABU.maxTargetScore, "changeTargetScore")}
    </div>
    <div class="settings-group">
      ${viewStepper("team-count", "Teams", form.teamCount, TABU.minTeams, TABU.maxTeams, "changeTeamCount")}
      ${viewCheck("auto-teams", `data-setting="autoTeams"`, form.autoTeams, "Teams automatisch mischen")}
      <p class="hint">${form.autoTeams ? "Beim Start werden die Teams zufällig und gleich groß gemischt." : "Jeder wählt sein Team selbst."}</p>
    </div>`;
}

export function tabuSummary(form: TabuForm): string[] {
  return [
    `Sekunden pro Zug: <strong>${form.turnSeconds}</strong>`,
    `Punkte bis zum Sieg: <strong>${form.targetScore}</strong>`,
    `Teams: <strong>${form.teamCount}</strong>, ${form.autoTeams ? "automatisch gemischt" : "selbst gewählt"}`,
  ];
}

/** Die Karte mit Begriff und verbotenen Wörtern. */
export function viewForbiddenCard(card: { word: string; forbidden: string[] }): string {
  return `
    <section class="forbidden-card">
      <strong class="forbidden-word">${esc(card.word)}</strong>
      <p class="forbidden-label">Nicht sagen:</p>
      <ul>${card.forbidden.map((f) => `<li>${esc(f)}</li>`).join("")}</ul>
    </section>`;
}

/** Uhr, die main.ts jede Viertelsekunde weiterzählt (data-deadline = Zeitpunkt in ms). */
export function viewCountdown(deadline: number): string {
  const seconds = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
  return `<output class="countdown" data-deadline="${deadline}" aria-label="Restzeit in Sekunden">${seconds}</output>`;
}

export function viewScoreboard(teams: { name: string; score: number }[], currentTeam: number, targetScore: number): string {
  const rows = teams
    .map(
      (team, i) => `
        <li class="team-${i} ${i === currentTeam ? "is-current" : ""}">
          <span>${esc(team.name)}</span>
          <strong>${team.score}</strong>
        </li>`,
    )
    .join("");
  return `
    <section class="scoreboard" aria-label="Punktestand">
      <ul>${rows}</ul>
      <p class="hint">Gewonnen hat, wer zuerst ${targetScore} Punkte hat.</p>
    </section>`;
}

const OUTCOME_TEXT = { CORRECT: "✓ richtig", SKIPPED: "übersprungen", BUZZED: "✗ verboten" } as const;

export function viewTurnResults(
  title: string,
  results: { word: string; outcome: keyof typeof OUTCOME_TEXT; scoringTeam: number | null }[],
  teamNames: string[],
): string {
  if (results.length === 0) return "";
  const items = results
    .map(
      (r) => `
        <li>
          <span class="player-name">${esc(r.word)}</span>
          <span class="player-note">${OUTCOME_TEXT[r.outcome]}${r.scoringTeam === null ? "" : ` · +1 ${esc(teamNames[r.scoringTeam])}`}</span>
        </li>`,
    )
    .join("");
  return `
    <section class="players turn-results">
      <h2>${esc(title)}</h2>
      <ul>${items}</ul>
    </section>`;
}

// ---- Nobody is Perfect -----------------------------------------------

export interface NobodyIsPerfectForm {
  questionCount: number;
}

export function viewNobodyIsPerfectOptions(form: NobodyIsPerfectForm): string {
  return `
    <div class="settings-group">
      ${viewStepper("question-count", "Fragen", form.questionCount, NOBODY_IS_PERFECT.minQuestions, NOBODY_IS_PERFECT.maxQuestions, "changeQuestionCount")}
      <p class="hint">Richtig getippt: 1 Punkt. Für jeden, der auf deine erfundene Antwort hereinfällt: 1 Punkt.</p>
    </div>`;
}

export function nobodyIsPerfectSummary(form: NobodyIsPerfectForm): string[] {
  return [`Fragen: <strong>${form.questionCount}</strong>`];
}

export function viewQuestion(question: string, number: number, count: number): string {
  return `
    <section class="question-card">
      <p class="question-number">Frage ${number} von ${count}</p>
      <strong class="question-text">${esc(question)}</strong>
    </section>`;
}

/**
 * Antworten zum Tippen. Die eigene Erfindung ist gesperrt.
 * @param action data-action der Knöpfe, data-value ist der Buchstabe
 */
export function viewChoices(
  choices: { id: string; text: string }[],
  ownId: string | null,
  chosenId: string | null,
  action: string,
): string {
  const items = choices
    .map((c) => {
      const own = c.id === ownId;
      const chosen = c.id === chosenId;
      return `
        <li>
          <button class="vote-option choice ${chosen ? "is-selected" : ""}" data-action="${action}" data-value="${c.id}"
                  aria-pressed="${chosen}" ${own ? "disabled" : ""}>
            <span class="choice-letter">${c.id}</span>
            <span class="choice-text">${esc(c.text)}</span>
            ${own ? `<span class="player-note">deine</span>` : ""}
          </button>
        </li>`;
    })
    .join("");
  return `<section class="voting choices"><ul>${items}</ul></section>`;
}

export interface RevealRow {
  id: string;
  text: string;
  correct: boolean;
  /** null bei der echten Antwort. */
  author: string | null;
  guessers: string[];
}

/** Auflösung: echte Antwort zuerst, dann die Erfindungen nach Anzahl der Reingefallenen. */
export function viewReveal(rows: RevealRow[]): string {
  const sorted = [...rows].sort((a, b) => Number(b.correct) - Number(a.correct) || b.guessers.length - a.guessers.length);
  const items = sorted
    .map((r) => {
      const who = r.correct ? "Die echte Antwort" : `Erfunden von ${esc(r.author ?? "?")}`;
      const guessed = r.guessers.length ? `Getippt: ${r.guessers.map(esc).join(", ")}` : "Niemand hat darauf getippt";
      return `
        <li class="${r.correct ? "is-correct" : ""}">
          <span class="choice-letter">${r.id}</span>
          <span class="reveal-body">
            <span class="choice-text">${esc(r.text)}</span>
            <span class="player-note">${who} · ${guessed}</span>
          </span>
        </li>`;
    })
    .join("");
  return `
    <section class="players reveal-list">
      <h2>Auflösung</h2>
      <ul>${items}</ul>
    </section>`;
}

/** Punktestand, Bester oben. {@code gained}: Punkte für die letzte Frage. */
export function viewPointTable(rows: { name: string; score: number; gained: number }[], title = "Punkte"): string {
  const items = [...rows]
    .sort((a, b) => b.score - a.score)
    .map(
      (r) => `
        <li>
          <span class="player-name">${esc(r.name)}</span>
          <span class="player-note">${r.gained ? `+${r.gained} · ` : ""}<strong>${r.score}</strong></span>
        </li>`,
    )
    .join("");
  return `
    <section class="players point-table">
      <h2>${esc(title)}</h2>
      <ul>${items}</ul>
    </section>`;
}

/** Aktualisiert alle Uhren auf der Seite, ohne neu zu zeichnen (sonst springt beim Tippen der Fokus). */
export function updateCountdowns(root: ParentNode): void {
  for (const el of root.querySelectorAll<HTMLElement>("[data-deadline]")) {
    const seconds = Math.max(0, Math.ceil((Number(el.dataset.deadline) - Date.now()) / 1000));
    el.textContent = String(seconds);
    el.classList.toggle("is-low", seconds <= 10);
  }
}
