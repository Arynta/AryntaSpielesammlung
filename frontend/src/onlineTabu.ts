// Online-Ansichten für Tabu: Teamwahl in der Lobby und das laufende Spiel.
import { TABU } from "./gameData";
import { esc } from "./html";
import { viewCountdown, viewForbiddenCard, viewScoreboard, viewTurnResults } from "./sharedViews";
import type { RoomView, TabuView } from "./types";

/** Teamwahl in der Lobby, wenn die Teams nicht automatisch gemischt werden. */
export function viewTeamChoice(room: RoomView): string {
  const settings = room.tabuSettings;
  const nameOf = (id: string) => room.players.find((p) => p.id === id)?.name ?? "?";
  const assigned = new Set(settings.teams.flat());
  const unassigned = room.players.filter((p) => !assigned.has(p.id));

  const boxes = settings.teams
    .map((ids, team) => {
      const mine = ids.includes(room.you.id);
      const members = ids
        .map((id) => {
          const move = room.you.host
            ? `<button class="kick" data-action="moveTeam" data-value="${id}" aria-label="${esc(nameOf(id))} ins nächste Team">⇄</button>`
            : "";
          return `<li><span class="player-name">${esc(nameOf(id))}${id === room.you.id ? " (du)" : ""}</span>${move}</li>`;
        })
        .join("");
      return `
        <div class="team-box team-${team}">
          <h3>${esc(TABU.teamNames[team])} <span class="count">${ids.length}</span></h3>
          <ul>${members}</ul>
          ${mine ? "" : `<button class="btn small" data-action="chooseTeam" data-value="${team}">Hier rein</button>`}
        </div>`;
    })
    .join("");

  const waiting = unassigned.length
    ? `<p class="hint">Noch ohne Team: ${unassigned.map((p) => esc(p.name)).join(", ")}</p>`
    : "";
  return `
    <section class="team-choice">
      <h2>Teams</h2>
      <div class="team-grid">${boxes}</div>
      ${waiting}
    </section>`;
}

/**
 * @param deadline Zeitpunkt (ms), an dem der laufende Zug endet
 * @param readyButton Bereit-Knopf aus main.ts für das Spielende
 */
export function viewTabu(room: RoomView, game: TabuView, deadline: number | null, readyButton: string): string {
  const label = `<p class="game-label">Tabu · Zug ${room.round}</p>`;
  const scoreboard = viewScoreboard(game.teams, game.currentTeam, game.targetScore);
  const teamNames = game.teams.map((t) => t.name);
  const leave = room.you.host
    ? `<button class="btn quiet" data-action="backToLobby">Spiel beenden</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;

  if (game.winnerTeam !== null) {
    const hostControls = room.you.host
      ? `<button class="btn primary" data-action="nextRound" ${room.canStart ? "" : "disabled"}>Nochmal spielen</button>
         <button class="btn quiet" data-action="backToLobby">Zurück zur Lobby</button>`
      : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;
    const waitHint =
      room.canStart && !room.you.host ? "Alle sind bereit. Die Spielleitung kann neu starten." : room.startHint;
    return `
      ${label}
      <header class="phase-head">
        <h1 class="title">${esc(teamNames[game.winnerTeam])} gewinnt!</h1>
        <p class="lead">${game.yourTeam === game.winnerTeam ? "Glückwunsch, ihr habt es geschafft." : "Knapp daneben ist auch vorbei."}</p>
      </header>
      ${scoreboard}
      ${viewTurnResults("Letzter Zug", game.lastTurn, teamNames)}
      <div class="actions">
        ${readyButton}
        ${hostControls}
        ${waitHint ? `<p class="hint">${esc(waitHint)}</p>` : ""}
      </div>`;
  }

  const nameOf = (id: string) => room.players.find((p) => p.id === id)?.name ?? "?";
  const explainer = nameOf(game.explainerId);
  const watcher = nameOf(game.watcherId);
  const youExplain = game.explainerId === room.you.id;
  const youWatch = game.watcherId === room.you.id;

  if (room.phase === "TURN_READY") {
    const explainerOnline = room.players.find((p) => p.id === game.explainerId)?.connected ?? false;
    let start = "";
    if (youExplain) start = `<button class="btn primary" data-action="startTurn">Uhr starten</button>`;
    else if (room.you.host && !explainerOnline) {
      start = `<button class="btn" data-action="startTurn">Für ${esc(explainer)} starten</button>`;
    }
    const lead = youExplain
      ? "Du erklärst! Starte die Uhr, wenn dein Team bereit ist."
      : youWatch
        ? `Du passt auf ${esc(explainer)} auf und hast den Buzzer.`
        : `<strong>${esc(explainer)}</strong> erklärt, <strong>${esc(watcher)}</strong> passt auf.`;
    return `
      ${label}
      <header class="phase-head">
        <h1 class="title">${esc(teamNames[game.currentTeam])} ist dran</h1>
        <p class="lead">${lead}</p>
      </header>
      <div class="actions">${start}</div>
      ${scoreboard}
      ${viewTurnResults("Letzter Zug", game.lastTurn, teamNames)}
      <div class="actions">${leave}</div>`;
  }

  // Zug läuft
  let main: string;
  if (youExplain && game.card) {
    main = `
      ${viewForbiddenCard(game.card)}
      <div class="turn-buttons">
        <button class="btn primary" data-action="wordCorrect">✓ Richtig</button>
        <button class="btn" data-action="wordSkip">Überspringen</button>
      </div>`;
  } else if (youWatch && game.card) {
    main = `
      ${viewForbiddenCard(game.card)}
      <button class="btn buzzer" data-action="buzz">Verboten!</button>
      <p class="hint">Drück, wenn ${esc(explainer)} ein verbotenes Wort, einen Teil davon oder eine Geste benutzt.</p>`;
  } else if (game.yourTeam === game.currentTeam) {
    main = `<p class="turn-role">Rate mit! <strong>${esc(explainer)}</strong> erklärt.</p>`;
  } else {
    main = `<p class="turn-role">${esc(teamNames[game.currentTeam])} rät gerade. <strong>${esc(watcher)}</strong> passt auf.</p>`;
  }

  return `
    <div class="turn-head">
      ${label}
      ${deadline ? viewCountdown(deadline) : ""}
    </div>
    ${main}
    ${viewTurnResults("Dieser Zug", game.turnResults, teamNames)}
    ${scoreboard}
    <div class="actions">${leave}</div>`;
}
