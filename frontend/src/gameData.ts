// Wörter und Rollen kommen aus denselben Dateien wie im Backend, damit es nur eine Liste gibt.
import wordFile from "../../backend/src/main/resources/games/impostor-words.json";
import roleFile from "../../backend/src/main/resources/games/werwolf-roles.json";
import cardFile from "../../backend/src/main/resources/games/tabu-cards.json";
import questionFile from "../../backend/src/main/resources/games/nobody-is-perfect-questions.json";
import werwolfCard from "../../assets/images/Werwolf/Werwolf_werwolf1.png";

export interface RoleData {
  id: string;
  name: string;
  team: string;
  description: string;
  /** Wacht mit den Wölfen auf: kennt das Rudel und wird von ihm erkannt. */
  wolfPack?: boolean;
  /** Kennt das Rudel, wird aber nicht erkannt (Günstling). */
  seesWolfPack?: boolean;
}

export interface WordCategory {
  name: string;
  words: string[];
}

export const ROLES: RoleData[] = roleFile.roles;
export const TEAM_NAMES: Record<string, string> = Object.fromEntries(roleFile.teams.map((t) => [t.id, t.name]));
export const TEAM_IDS: string[] = roleFile.teams.map((t) => t.id);
export const CATEGORIES: WordCategory[] = wordFile.categories;
export const TABU_CARDS: { word: string; forbidden: string[] }[] = cardFile.cards;
export const NOBODY_IS_PERFECT_QUESTIONS: { question: string; answer: string }[] = questionFile.questions;

export const VILLAGER = "DORFBEWOHNER";
export const WEREWOLF = "WERWOLF";
export const SEER = "SEHERIN";
/** Mit Dieb kommen zwei Karten mehr ins Spiel, aus denen er tauschen darf. */
export const THIEF = "DIEB";
export const THIEF_EXTRA_CARDS = 2;

// Gleiche Werte wie im Backend (GameType, Room, ImpostorOptions)
export const MAX_PLAYERS = 20;
export const MIN_PLAYERS = { WERWOLF: 4, IMPOSTOR: 3, TABU: 4, NOBODY_IS_PERFECT: 3 } as const;
export const MAX_IMPOSTORS = MAX_PLAYERS / 2 - 1;

// Gleiche Werte wie im Backend (TabuOptions, TabuGame)
export const TABU = {
  teamNames: ["Team Rot", "Team Blau", "Team Grün", "Team Gelb"],
  minTurnSeconds: 30,
  maxTurnSeconds: 180,
  turnSecondsStep: 15,
  minTeams: 2,
  maxTeams: 4,
  minTargetScore: 10,
  maxTargetScore: 100,
  targetScoreStep: 5,
  minTeamSize: 2,
} as const;

// Gleiche Werte wie im Backend (NobodyIsPerfectOptions)
export const NOBODY_IS_PERFECT = {
  minQuestions: 3,
  maxQuestions: 20,
  defaultQuestions: 8,
  maxAnswerLength: 100,
} as const;

/** Rollen zum Ankreuzen. Dorfbewohner füllen auf, Werwölfe werden gezählt. */
export const SPECIAL_ROLES: RoleData[] = ROLES.filter((r) => r.id !== VILLAGER && r.id !== WEREWOLF);

/** Kartenbilder für Rollen. Hat eine Rolle ein Bild, zeigt die Karte das Bild statt des Rollennamens. */
export const ROLE_IMAGES: Partial<Record<string, string>> = {
  [WEREWOLF]: werwolfCard,
};

/** Lädt die Bilder vorab, damit sie beim Aufdecken sofort da sind und nicht erst nachladen. */
export function preloadRoleImages(roleIds: readonly string[]): void {
  for (const id of new Set(roleIds)) {
    const url = ROLE_IMAGES[id];
    if (url) new Image().src = url;
  }
}

export function roleById(id: string): RoleData {
  const role = ROLES.find((r) => r.id === id);
  if (!role) throw new Error(`Unbekannte Rolle: ${id}`);
  return role;
}
