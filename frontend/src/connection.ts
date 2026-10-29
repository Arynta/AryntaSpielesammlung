import type { ClientMessage, ServerMessage } from "./types";

export type ConnectionStatus = "waking" | "connecting" | "online" | "offline";

const PING_EVERY_MS = 25_000;
const MAX_RETRY_DELAY_MS = 10_000;

/**
 * Hält die WebSocket-Verbindung zum Backend offen und baut sie nach
 * Abbrüchen (Handy gesperrt, WLAN gewechselt) selbst wieder auf.
 */
export class GameConnection {
  private socket: WebSocket | null = null;
  private retryDelay = 1_000;
  private pingTimer: number | undefined;
  private everConnected = false;

  constructor(
    private readonly url: string,
    private readonly onMessage: (msg: ServerMessage) => void,
    private readonly onStatus: (status: ConnectionStatus) => void,
    /** Wird nach jedem (Wieder-)Verbinden aufgerufen, z. B. um sich im Raum zurückzumelden. */
    private readonly onOpen: () => void,
  ) {}

  async start(): Promise<void> {
    // Render Free legt den Server nach 15 Minuten schlafen. Ein normaler HTTP-Aufruf weckt ihn auf.
    this.onStatus("waking");
    try {
      await fetch(healthUrl(this.url), { cache: "no-store" });
    } catch {
      // egal, der WebSocket-Versuch danach zeigt, ob der Server da ist
    }
    this.connect();
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible" && !this.isOpen()) {
        this.retryDelay = 1_000;
        this.connect();
      }
    });
  }

  send(msg: ClientMessage): boolean {
    if (!this.isOpen()) {
      return false;
    }
    this.socket!.send(JSON.stringify(msg));
    return true;
  }

  private isOpen(): boolean {
    return this.socket?.readyState === WebSocket.OPEN;
  }

  private connect(): void {
    if (this.socket && this.socket.readyState <= WebSocket.OPEN) {
      return; // verbindet schon oder ist offen
    }
    this.onStatus(this.everConnected ? "connecting" : "waking");
    const socket = new WebSocket(this.url);
    this.socket = socket;

    socket.addEventListener("open", () => {
      this.everConnected = true;
      this.retryDelay = 1_000;
      this.onStatus("online");
      this.pingTimer = window.setInterval(() => this.send({ type: "ping" }), PING_EVERY_MS);
      this.onOpen();
    });

    socket.addEventListener("message", (event) => {
      try {
        this.onMessage(JSON.parse(event.data as string) as ServerMessage);
      } catch (e) {
        console.error("Kaputte Nachricht vom Server", e);
      }
    });

    socket.addEventListener("close", () => {
      window.clearInterval(this.pingTimer);
      if (this.socket !== socket) {
        return;
      }
      this.socket = null;
      this.onStatus("offline");
      window.setTimeout(() => this.connect(), this.retryDelay);
      this.retryDelay = Math.min(this.retryDelay * 2, MAX_RETRY_DELAY_MS);
    });
  }
}

function healthUrl(wsUrl: string): string {
  const url = new URL(wsUrl);
  url.protocol = url.protocol === "wss:" ? "https:" : "http:";
  url.pathname = "/health";
  url.search = "";
  return url.toString();
}
