// Spielregeln für den lokalen Modus (ein Handy, kein Server). Sie entsprechen den Regeln im
// Backend (RoleDistribution, ImpostorOptions, ImpostorWords) und haben eigene Tests.
import {
  CATEGORIES,
  MAX_IMPOSTORS,
  MIN_PLAYERS,
  SPECIAL_ROLES,
  THIEF,
  THIEF_EXTRA_CARDS,
  VILLAGER,
  WEREWOLF,
  roleById,
  type RoleData,
} from "./gameData";

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
