// Spiegelt die Java-Klassen im Backend (RoomView, Role, Phase).

export type Phase = "LOBBY" | "NIGHT" | "DAY";
export type Role = "WERWOLF" | "SEHERIN" | "DORFBEWOHNER";

export interface PlayerView {
  id: string;
  name: string;
  alive: boolean;
  connected: boolean;
}

export interface You {
  id: string;
  name: string;
  host: boolean;
  role: Role | null;
  roleName: string | null;
  roleDescription: string | null;
  fellowWerewolves: string[];
}

export interface RoomView {
  code: string;
  phase: Phase;
  round: number;
  hostId: string;
  players: PlayerView[];
  you: You;
}

/** Was der Server schickt. */
export type ServerMessage =
  | { type: "joined"; code: string; secret: string }
  | { type: "state"; state: RoomView }
  | { type: "left" }
  | { type: "error"; message: string }
  | { type: "pong" };

/** Was das Handy schickt. */
export type ClientMessage =
  | { type: "create"; name: string }
  | { type: "join"; code: string; name: string }
  | { type: "rejoin"; code: string; secret: string }
  | { type: "leave" }
  | { type: "start" }
  | { type: "nextPhase" }
  | { type: "backToLobby" }
  | { type: "ping" };
