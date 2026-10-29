// Online-Ansichten für Nobody is Perfect: Antwort schreiben, tippen, Auflösung und Spielende.
import { NOBODY_IS_PERFECT } from "./gameData";
import { esc } from "./html";
import { viewChoices, viewPointTable, viewQuestion, viewReveal } from "./sharedViews";
import type { NobodyIsPerfectView, RoomView } from "./types";

/**
 * @param answerDraft was gerade im Antwortfeld steht (merkt sich main.ts)
 * @param readyButton Bereit-Knopf aus main.ts für das Spielende
 */
export function viewNobodyIsPerfect(room: RoomView, game: NobodyIsPerfectView, answerDraft: string, readyButton: string): string {
  const nameOf = (id: string) => room.players.find((p) => p.id === id)?.name ?? "?";
  const label = `<p class="game-label">Nobody is Perfect · Frage ${game.questionNumber} von ${game.questionCount}</p>`;
  const leave = room.you.host
    ? `<button class="btn quiet" data-action="backToLobby">Spiel beenden</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;
  const points = game.scores.map((s) => ({ name: nameOf(s.playerId), score: s.score, gained: s.gained }));

  if (room.phase === "WRITING" || room.phase === "GUESSING") {
    const writing = room.phase === "WRITING";
    const done = new Set(writing ? game.answeredIds : game.guessedIds);
    const waitingFor = room.players.filter((p) => game.participantIds.includes(p.id) && p.connected && !done.has(p.id));
    const progress = `
      <p class="hint">${done.size} von ${done.size + waitingFor.length} ${writing ? "haben geschrieben" : "haben getippt"}.
        ${waitingFor.length ? `Warte auf ${waitingFor.map((p) => esc(p.name)).join(", ")}.` : ""}</p>`;
    const skip =
      room.you.host && done.size > 0 && waitingFor.length > 0
        ? `<button class="btn" data-action="skipWaiting">Nicht länger warten</button>`
        : "";

    const main = writing ? viewWriting(game, answerDraft) : viewGuessing(game);
    return `
      <header class="phase-head">
        ${label}
        <h1 class="title">${writing ? "Flunker los!" : "Welche ist echt?"}</h1>
        <p class="lead">${
          writing
            ? "Denk dir eine Antwort aus, die echt klingt. Je glaubwürdiger, desto mehr fallen darauf herein."
            : "Tippe auf die Antwort, die du für die echte hältst. Du kannst deinen Tipp noch ändern."
        }</p>
      </header>
      ${viewQuestion(game.question, game.questionNumber, game.questionCount)}
      ${main}
      ${progress}
      <div class="actions">${skip}${leave}</div>`;
  }

  const reveal = viewReveal(
    game.reveal.map((r) => ({
      id: r.id,
      text: r.text,
      correct: r.correct,
      author: r.authorId ? nameOf(r.authorId) : null,
      guessers: r.guesserIds.map(nameOf),
    })),
  );
  const answer = `
    <section class="result-word">
      <p>Die echte Antwort</p>
      <strong class="answer-text">${esc(game.answer ?? "")}</strong>
    </section>`;

  if (room.phase === "REVEAL") {
    const next = room.you.host
      ? `<button class="btn primary" data-action="nextQuestion">Nächste Frage</button>`
      : `<p class="hint">Die Spielleitung geht zur nächsten Frage.</p>`;
    return `
      <header class="phase-head">
        ${label}
        <h1 class="title">Auflösung</h1>
      </header>
      ${viewQuestion(game.question, game.questionNumber, game.questionCount)}
      ${answer}
      ${reveal}
      ${viewPointTable(points)}
      <div class="actions">${next}${leave}</div>`;
  }

  // Spielende
  const best = Math.max(...game.scores.map((s) => s.score));
  const winners = game.scores.filter((s) => s.score === best).map((s) => s.playerId);
  const title =
    winners.length === 1
      ? `${esc(nameOf(winners[0]))} gewinnt!`
      : `Gleichstand: ${winners.map((id) => esc(nameOf(id))).join(" und ")}`;
  const hostControls = room.you.host
    ? `<button class="btn primary" data-action="nextRound" ${room.canStart ? "" : "disabled"}>Nochmal spielen</button>
       <button class="btn quiet" data-action="backToLobby">Zurück zur Lobby</button>`
    : `<button class="btn quiet" data-action="leave">Raum verlassen</button>`;
  const waitHint =
    room.canStart && !room.you.host ? "Alle sind bereit. Die Spielleitung kann neu starten." : room.startHint;
  return `
    <header class="phase-head">
      <p class="game-label">Nobody is Perfect · Spielende</p>
      <h1 class="title">${title}</h1>
      <p class="lead">${winners.includes(room.you.id) ? "Niemand flunkert so gut wie du." : `Mit ${best} Punkten.`}</p>
    </header>
    ${viewPointTable(points, "Endstand")}
    ${viewQuestion(game.question, game.questionNumber, game.questionCount)}
    ${answer}
    ${reveal}
    <div class="actions">
      ${readyButton}
      ${hostControls}
      ${waitHint ? `<p class="hint">${esc(waitHint)}</p>` : ""}
    </div>`;
}

function viewWriting(game: NobodyIsPerfectView, answerDraft: string): string {
  const submitted = game.yourAnswer
    ? `<p class="hint">✓ Abgegeben: „${esc(game.yourAnswer)}“. Du kannst sie noch ändern, bis alle fertig sind.</p>`
    : "";
  return `
    <div class="settings-group answer-form">
      <label class="field">
        <span>Deine erfundene Antwort</span>
        <input id="answer" data-bind="answerDraft" maxlength="${NOBODY_IS_PERFECT.maxAnswerLength}" autocomplete="off"
               value="${esc(answerDraft)}" placeholder="Klingt echt, ist aber ausgedacht" />
      </label>
      <button class="btn primary" data-action="submitAnswer">${game.yourAnswer ? "Antwort ändern" : "Antwort abgeben"}</button>
      ${submitted}
    </div>`;
}

function viewGuessing(game: NobodyIsPerfectView): string {
  return viewChoices(game.choices, game.yourChoiceId, game.yourGuess, "guessAnswer");
}
