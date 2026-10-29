// Bausteine, die online (Lobby) und lokal (ein Handy) gleich aussehen.
// Die Eingaben tragen data-setting, data-category, data-role bzw. data-action. Was beim Ändern
// passiert, entscheidet main.ts (an den Server schicken) oder localMode.ts (lokal merken).
import { MAX_PLAYERS, ROLE_IMAGES, SPECIAL_ROLES, TEAM_IDS, TEAM_NAMES, roleById } from "./gameData";
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
