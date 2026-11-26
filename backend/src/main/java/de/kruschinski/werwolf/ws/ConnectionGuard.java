package de.kruschinski.werwolf.ws;

import java.time.Clock;

/**
 * Bremst eine einzelne Verbindung, die sich wie ein Skript verhält: zu viele Nachrichten pro Sekunde
 * oder zu viele Raumcodes hintereinander, die es nicht gibt (Raten fremder Räume).
 */
final class ConnectionGuard {

    private final Clock clock;
    private final int maxMessagesPerSecond;
    private final int maxUnknownCodes;
    private long windowStart;
    private int messagesInWindow;
    private int unknownCodesInARow;

    ConnectionGuard(Clock clock, int maxMessagesPerSecond, int maxUnknownCodes) {
        this.clock = clock;
        this.maxMessagesPerSecond = maxMessagesPerSecond;
        this.maxUnknownCodes = maxUnknownCodes;
        this.windowStart = clock.millis();
    }

    /** {@code false}: In dieser Sekunde kamen schon zu viele Nachrichten. */
    synchronized boolean allowMessage() {
        long now = clock.millis();
        if (now - windowStart >= 1000) {
            windowStart = now;
            messagesInWindow = 0;
        }
        messagesInWindow++;
        return messagesInWindow <= maxMessagesPerSecond;
    }

    /** {@code false}: Das war ein Raumcode zu viel, der nicht existiert. */
    synchronized boolean allowUnknownCode() {
        unknownCodesInARow++;
        return unknownCodesInARow < maxUnknownCodes;
    }

    /** Wer einen Raum gefunden hat, darf wieder von vorne raten (z. B. nach einem Tippfehler). */
    synchronized void joined() {
        unknownCodesInARow = 0;
    }
}
