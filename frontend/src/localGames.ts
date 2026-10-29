// Spielregeln für den lokalen Modus (ein Handy, kein Server). Sie entsprechen den Regeln im
// Backend (RoleDistribution, ImpostorOptions, ImpostorWords, TabuGame, NobodyIsPerfectGame) und haben eigene Tests.
import {
  CATEGORIES,
  NOBODY_IS_PERFECT,
  NOBODY_IS_PERFECT_QUESTIONS,
  MAX_IMPOSTORS,
  MIN_PLAYERS,
  SPECIAL_ROLES,
  THIEF,
  THIEF_EXTRA_CARDS,
  TABU,
  TABU_CARDS,
  VILLAGER,
  WEREWOLF,
  roleById,
  type RoleData,
} from "./gameData";
import type { CardOutcome, CardResult, TabuCard } from "./types";

/** Zufallszahl von 0 (inklusive) bis 1 (exklusive), wie Math.random. Austauschbar für Tests. */
export type Random = () => number;

export function shuffled<T>(items: readonly T[], random: Random): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/** Leere Felder werden zu „Spieler 1“, „Spieler 2“ usw. */
export function playerNames(count: number, typed: readonly string[]): string[] {
  return Array.from({ length: count }, (_, i) => cleanName(typed[i] ?? "") || `Spieler ${i + 1}`);
}

/** Wie im Backend: unsichtbare Zeichen raus, Leerraum zusammenfassen. */
export function cleanName(raw: string): string {
  return raw
    .replace(/[\p{Cc}\p{Cf}\p{Co}\p{Cn}]/gu, (c) => (/\s/.test(c) ? c : ""))
    .replace(/[\s\p{Z}]+/gu, " ")
    .trim();
}

export function duplicateName(names: readonly string[]): string | null {
  const seen = new Set<string>();
  for (const name of names) {
    const key = name.toLowerCase();
    if (seen.has(key)) return name;
    seen.add(key);
  }
  return null;
}

// ---- Werwolf ---------------------------------------------------------------

/** Ein Werwolf pro angefangene vier Spieler (4–7 → 1, 8–11 → 2, ...). */
export function autoWerewolves(playerCount: number): number {
  return Math.max(1, Math.floor(playerCount / 4));
}

/** {@code chosen} ist null, wenn die Anzahl automatisch sein soll. */
export function werewolves(playerCount: number, chosen: number | null): number {
  return chosen ?? autoWerewolves(playerCount);
}

export function werwolfProblem(playerCount: number, chosen: number | null, specialRoles: readonly string[]): string | null {
  if (playerCount < MIN_PLAYERS.WERWOLF) {
    return `Es werden mindestens ${MIN_PLAYERS.WERWOLF} Spieler gebraucht.`;
  }
  const cards = werewolves(playerCount, chosen) + specialRoles.length;
  if (cards > playerCount) {
    return `Zu viele Rollen: ${cards} Rollen für ${playerCount} Spieler. Nimm Rollen raus oder weniger Werwölfe.`;
  }
  return null;
}

/** Bringt die Auswahl in die Reihenfolge der Rollenliste und lässt Unbekanntes weg. */
export function normalizeRoles(ids: readonly string[]): string[] {
  return SPECIAL_ROLES.map((r) => r.id).filter((id) => ids.includes(id));
}

export interface WerwolfDeal {
  perPlayer: RoleData[];
  /** Nur mit Dieb: die zwei übrigen Karten. */
  leftover: RoleData[];
}

export function dealWerwolf(
  playerCount: number,
  chosen: number | null,
  specialRoles: readonly string[],
  random: Random,
): WerwolfDeal {
  const problem = werwolfProblem(playerCount, chosen, specialRoles);
  if (problem) throw new Error(problem);

  const extra = specialRoles.includes(THIEF) ? THIEF_EXTRA_CARDS : 0;
  const cards: RoleData[] = [];
  for (let i = 0; i < werewolves(playerCount, chosen); i++) cards.push(roleById(WEREWOLF));
  specialRoles.forEach((id) => cards.push(roleById(id)));
  while (cards.length < playerCount + extra) cards.push(roleById(VILLAGER));

  const mixed = shuffled(cards, random);
  return { perPlayer: mixed.slice(0, playerCount), leftover: mixed.slice(playerCount) };
}

/** Das Rudel kennt sich gegenseitig, der Günstling kennt das Rudel. */
export function knownWolves(deal: WerwolfDeal, names: readonly string[], index: number): string[] {
  const role = deal.perPlayer[index];
  if (!role.wolfPack && !role.seesWolfPack) return [];
  return names.filter((_, i) => i !== index && deal.perPlayer[i].wolfPack);
}

// ---- Impostor --------------------------------------------------------------

/** Ab 2 Impostorn muss die Crew mindestens zwei mehr sein, sonst ist sie chancenlos. */
export function minImpostorParticipants(impostorCount: number): number {
  return impostorCount === 1 ? MIN_PLAYERS.IMPOSTOR : Math.max(MIN_PLAYERS.IMPOSTOR, 2 * impostorCount + 2);
}

export function impostorProblem(playerCount: number, impostorCount: number): string | null {
  if (impostorCount < 1 || impostorCount > MAX_IMPOSTORS) return `Es kann 1 bis ${MAX_IMPOSTORS} Impostor geben.`;
  const needed = minImpostorParticipants(impostorCount);
  if (playerCount >= needed) return null;
  return impostorCount === 1
    ? `Für Impostor braucht es mindestens ${needed} Mitspieler.`
    : `Für ${impostorCount} Impostor braucht es mindestens ${needed} Mitspieler.`;
}

export interface ImpostorOptions {
  impostorCount: number;
  randomStartPlayer: boolean;
  categories: readonly string[];
}

export interface ImpostorDeal {
  word: string;
  category: string;
  /** Plätze (Index in der Namensliste) der Impostor. */
  impostors: number[];
  /** Wer anfängt, oder null. Nie ein Impostor, der hätte ja gar keinen Hinweis. */
  startPlayer: number | null;
}

/** Ein Wort aus den Kategorien, das noch nicht dran war. Sind alle verbraucht, geht es von vorne los. */
export function pickWord(categories: readonly string[], usedWords: readonly string[], random: Random) {
  const inCategories = CATEGORIES.filter((c) => categories.includes(c.name)).flatMap((c) =>
    c.words.map((word) => ({ word, category: c.name })),
  );
  if (inCategories.length === 0) throw new Error("Bitte wähle mindestens eine Kategorie.");
  const unused = inCategories.filter((w) => !usedWords.includes(w.word));
  const candidates = unused.length > 0 ? unused : inCategories;
  return candidates[Math.floor(random() * candidates.length)];
}

export function dealImpostor(
  playerCount: number,
  options: ImpostorOptions,
  usedWords: readonly string[],
  random: Random,
): ImpostorDeal {
  const problem = impostorProblem(playerCount, options.impostorCount);
  if (problem) throw new Error(problem);

  const { word, category } = pickWord(options.categories, usedWords, random);
  const seats = shuffled(
    Array.from({ length: playerCount }, (_, i) => i),
    random,
  );
  const impostors = seats.slice(0, options.impostorCount).sort((a, b) => a - b);
  const crew = seats.slice(options.impostorCount);
  const startPlayer = options.randomStartPlayer ? crew[Math.floor(random() * crew.length)] : null;
  return { word, category, impostors, startPlayer };
}

// ---- Tabu ------------------------------------------------------------

/** Ein laufendes Tabu-Spiel. Spieler sind Plätze (Index in der Namensliste). */
export interface TabuMatch {
  teams: number[][];
  scores: number[];
  targetScore: number;
  currentTeam: number;
  /** Pro Team: wie oft schon erklärt bzw. aufgepasst wurde, daraus folgt, wer dran ist. */
  explainerTurns: number[];
  watcherTurns: number[];
  deck: TabuCard[];
  card: TabuCard | null;
  turnResults: CardResult[];
  lastTurn: CardResult[];
  winner: number | null;
}

/**
 * Warum nicht gestartet werden kann, oder null.
 * @param chosen pro Platz das selbst gewählte Team, null = noch keins
 */
export function tabuProblem(
  playerCount: number,
  teamCount: number,
  autoTeams: boolean,
  chosen: readonly (number | null)[],
): string | null {
  const needed = teamCount * TABU.minTeamSize;
  if (playerCount < needed) return `Für ${teamCount} Teams braucht es mindestens ${needed} Spieler.`;
  if (autoTeams) return null;
  const picks = Array.from({ length: playerCount }, (_, i) => chosen[i] ?? null);
  const unassigned = picks.filter((t) => t === null || t >= teamCount).length;
  if (unassigned > 0) {
    return unassigned === 1 ? "1 Spieler hat noch kein Team." : `${unassigned} Spieler haben noch kein Team.`;
  }
  for (let team = 0; team < teamCount; team++) {
    if (picks.filter((t) => t === team).length < TABU.minTeamSize) {
      return `Jedes Team braucht mindestens ${TABU.minTeamSize} Spieler.`;
    }
  }
  return null;
}

/** Automatisch: gemischt und reihum verteilt, also gleich groß. Sonst wie gewählt. */
export function makeTeams(
  playerCount: number,
  teamCount: number,
  autoTeams: boolean,
  chosen: readonly (number | null)[],
  random: Random,
): number[][] {
  const teams: number[][] = Array.from({ length: teamCount }, () => []);
  const seats = Array.from({ length: playerCount }, (_, i) => i);
  if (autoTeams) {
    shuffled(seats, random).forEach((seat, i) => teams[i % teamCount].push(seat));
  } else {
    seats.forEach((seat) => teams[chosen[seat]!].push(seat));
  }
  return teams;
}

export function createMatch(teams: number[][], targetScore: number): TabuMatch {
  return {
    teams,
    scores: teams.map(() => 0),
    targetScore,
    currentTeam: 0,
    explainerTurns: teams.map(() => 0),
    watcherTurns: teams.map(() => 0),
    deck: [],
    card: null,
    turnResults: [],
    lastTurn: [],
    winner: null,
  };
}

/** Der Aufpasser kommt aus dem Team, das als Nächstes dran ist. */
export function watcherTeam(match: TabuMatch): number {
  return (match.currentTeam + 1) % match.teams.length;
}

export function explainerSeat(match: TabuMatch): number {
  const team = match.teams[match.currentTeam];
  return team[match.explainerTurns[match.currentTeam] % team.length];
}

export function watcherSeat(match: TabuMatch): number {
  const index = watcherTeam(match);
  const team = match.teams[index];
  return team[match.watcherTurns[index] % team.length];
}

/** Neu gemischt wird erst, wenn alle Karten einmal dran waren. */
export function drawCard(match: TabuMatch, random: Random): void {
  if (match.deck.length === 0) match.deck = shuffled(TABU_CARDS, random);
  match.card = match.deck.pop()!;
}

/** Richtig: Punkt fürs eigene Team. Überspringen oder Buzzer: neue Karte, kein Punkt. */
export function scoreCard(match: TabuMatch, outcome: CardOutcome, random: Random): void {
  if (!match.card || match.winner !== null) return;
  if (outcome !== "CORRECT") {
    match.turnResults.push({ word: match.card.word, outcome, scoringTeam: null });
    drawCard(match, random);
    return;
  }
  const team = match.currentTeam;
  match.scores[team]++;
  match.turnResults.push({ word: match.card.word, outcome, scoringTeam: team });
  if (match.scores[team] >= match.targetScore) {
    match.winner = team;
    match.lastTurn = match.turnResults;
    match.turnResults = [];
    match.card = null;
    return;
  }
  drawCard(match, random);
}

/** Zeit um: das nächste Team ist dran, Erklärer und Aufpasser wechseln. */
export function endTurn(match: TabuMatch): void {
  match.lastTurn = match.turnResults;
  match.turnResults = [];
  match.explainerTurns[match.currentTeam]++;
  match.watcherTurns[watcherTeam(match)]++;
  match.currentTeam = (match.currentTeam + 1) % match.teams.length;
  match.card = null;
}

// ---- Nobody is Perfect -----------------------------------------------

export interface NobodyIsPerfectQuestion {
  question: string;
  answer: string;
}

/** Eine Antwort zur Auswahl. {@code author} ist der Platz des Erfinders, null bei der echten. */
export interface NobodyIsPerfectChoiceData {
  id: string;
  text: string;
  author: number | null;
}

/** Ein laufendes Nobody-is-Perfect-Spiel. Spieler sind Plätze (Index in der Namensliste). */
export interface NobodyIsPerfectMatch {
  questions: NobodyIsPerfectQuestion[];
  index: number;
  scores: number[];
  /** Punkte für die zuletzt aufgelöste Frage. */
  gained: number[];
  /** Pro Platz die erfundene Antwort zur aktuellen Frage. */
  answers: (string | null)[];
  /** Leer, solange noch geschrieben wird. */
  choices: NobodyIsPerfectChoiceData[];
  /** Pro Platz der Buchstabe, auf den getippt wurde. */
  guesses: (string | null)[];
}

/** Zieht Fragen, die noch nicht dran waren. Reichen die nicht, kommen auch alte wieder. */
export function pickQuestions(count: number, used: readonly string[], random: Random): NobodyIsPerfectQuestion[] {
  const fresh = shuffled(NOBODY_IS_PERFECT_QUESTIONS.filter((q) => !used.includes(q.question)), random);
  const old = shuffled(NOBODY_IS_PERFECT_QUESTIONS.filter((q) => used.includes(q.question)), random);
  return [...fresh, ...old].slice(0, count);
}

export function createNobodyIsPerfect(playerCount: number, questions: NobodyIsPerfectQuestion[]): NobodyIsPerfectMatch {
  return {
    questions,
    index: 0,
    scores: Array(playerCount).fill(0),
    gained: Array(playerCount).fill(0),
    answers: Array(playerCount).fill(null),
    choices: [],
    guesses: Array(playerCount).fill(null),
  };
}

/** Gibt zurück, was an der Antwort nicht stimmt, oder null. */
export function submitLie(match: NobodyIsPerfectMatch, seat: number, raw: string): string | null {
  const answer = cleanName(raw);
  if (!answer) return "Bitte schreib eine Antwort.";
  if (answer.length > NOBODY_IS_PERFECT.maxAnswerLength) return `Die Antwort darf höchstens ${NOBODY_IS_PERFECT.maxAnswerLength} Zeichen lang sein.`;
  match.answers[seat] = answer;
  return null;
}

/** Erfundene Antworten und die echte gemischt, mit Buchstaben A, B, C … */
export function mixChoices(match: NobodyIsPerfectMatch, random: Random): void {
  const all = match.answers.flatMap((text, seat) => (text === null ? [] : [{ text, author: seat as number | null }]));
  all.push({ text: match.questions[match.index].answer, author: null });
  match.choices = shuffled(all, random).map((c, i) => ({ id: String.fromCharCode(65 + i), ...c }));
}

/** Gibt zurück, warum der Tipp nicht geht, oder null. */
export function guessChoice(match: NobodyIsPerfectMatch, seat: number, id: string): string | null {
  const choice = match.choices.find((c) => c.id === id);
  if (!choice) return "Diese Antwort gibt es nicht.";
  if (choice.author === seat) return "Auf deine eigene Antwort kannst du nicht tippen.";
  match.guesses[seat] = id;
  return null;
}

/** Richtig getippt: +1. Jeder, der auf die eigene Erfindung hereinfällt: +1 für den Erfinder. */
export function revealQuestion(match: NobodyIsPerfectMatch): void {
  match.gained = match.scores.map(() => 0);
  match.guesses.forEach((id, seat) => {
    const choice = match.choices.find((c) => c.id === id);
    if (!choice) return;
    match.gained[choice.author ?? seat]++;
  });
  match.gained.forEach((points, seat) => (match.scores[seat] += points));
}

export function isLastQuestion(match: NobodyIsPerfectMatch): boolean {
  return match.index === match.questions.length - 1;
}

export function nextQuestion(match: NobodyIsPerfectMatch): void {
  match.index++;
  match.answers = match.answers.map(() => null);
  match.guesses = match.guesses.map(() => null);
  match.gained = match.gained.map(() => 0);
  match.choices = [];
}
