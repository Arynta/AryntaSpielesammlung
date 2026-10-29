// Spiegelt die Java-Klassen im Backend (RoomView, GameType, Phase).

export type GameType = "WERWOLF" | "IMPOSTOR";
export type Phase = "LOBBY" | "NIGHT" | "DAY" | "WORD" | "VOTING" | "RESULT";
export type ImpostorPart = "CREW" | "IMPOSTOR" | "GAME_MASTER";

export interface PlayerView {
  id: string;
  name: string;
  alive: boolean;
  connected: boolean;
  ready: boolean;
}

export interface You {
  id: string;
  name: string;
  host: boolean;
  ready: boolean;
}

export interface GameOption {
  type: GameType;
  name: string;
  description: string;
  minPlayers: number;
}

export interface ImpostorSettings {
  impostorSeesCategory: boolean;
  customWordSet: boolean;
  /** Nur beim Host gefüllt. */
  customWord: string | null;
  allCategories: string[];
  selectedCategories: string[];
  impostorCount: number;
  maxImpostorCount: number;
  randomStartPlayer: boolean;
}

export interface WerwolfSettings {
  /** null = automatisch passend zur Spielerzahl. */
  werewolfCount: number | null;
  effectiveWerewolfCount: number;
  allRoles: RoleCard[];
  selectedRoles: string[];
  hostIsGameMaster: boolean;
}

export interface PlayerLimit {
  value: number;
  /** Kleinster Wert, den der Host gerade einstellen darf. */
  min: number;
  max: number;
}

export interface RoleCard {
  id: string;
  name: string;
  team: string;
  teamName: string;
  description: string;
}

export interface RoleAssignment {
  playerId: string;
  playerName: string;
  role: RoleCard;
}

/** Mitspieler: role, knownWolves, beim Dieb leftoverRoles. Spielleitung: gameMaster, overview, leftoverRoles. */
export interface WerwolfView {
  gameMaster: boolean;
  role: RoleCard | null;
  knownWolves: string[];
  leftoverRoles: string[];
  overview: RoleAssignment[] | null;
}

export interface VoteCount {
  playerId: string;
  name: string;
  votes: number;
}

export interface ImpostorResult {
  impostorIds: string[];
  impostorNames: string[];
  word: string;
  category: string | null;
  impostorCaught: boolean;
  votes: VoteCount[];
}

export interface ImpostorView {
  part: ImpostorPart;
  word: string | null;
  category: string | null;
  fellowImpostors: string[];
  startPlayerId: string | null;
  gameMasterId: string | null;
  participantIds: string[];
  votedIds: string[];
  yourVote: string | null;
  result: ImpostorResult | null;
}

export interface RoomView {
  code: string;
  game: GameType;
  games: GameOption[];
  impostorSettings: ImpostorSettings;
  werwolfSettings: WerwolfSettings;
  playerLimit: PlayerLimit;
  phase: Phase;
  round: number;
  hostId: string;
  players: PlayerView[];
  canStart: boolean;
  startHint: string | null;
  you: You;
  werwolf: WerwolfView | null;
  impostor: ImpostorView | null;
}

/** Was der Server schickt. */
export type ServerMessage =
  | { type: "joined"; code: string; secret: string }
  | { type: "state"; state: RoomView }
  | { type: "left" }
  | { type: "kicked" }
  | { type: "error"; message: string }
  | { type: "pong" };

/** Was das Handy schickt. */
export type ClientMessage =
  | { type: "create"; name: string }
  | { type: "join"; code: string; name: string }
  | { type: "rejoin"; code: string; secret: string }
  | { type: "leave" }
  | { type: "selectGame"; game: GameType }
  | { type: "setReady"; ready: boolean }
  | { type: "configureImpostor"; impostorSeesCategory: boolean; customWord: string }
  | { type: "start" }
  | { type: "nextPhase" }
  | { type: "startVoting" }
  | { type: "vote"; targetId: string }
  | { type: "kick"; targetId: string }
  | { type: "setPlayerLimit"; playerLimit: number }
  | { type: "setImpostorCategories"; categories: string[] }
  | { type: "setImpostorOptions"; impostorCount: number; randomStartPlayer: boolean }
  | { type: "configureWerwolf"; werewolfCount: number | null; roles: string[]; hostIsGameMaster: boolean }
  | { type: "nextRound" }
  | { type: "backToLobby" }
  | { type: "ping" };
