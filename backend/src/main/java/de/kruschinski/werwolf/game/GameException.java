package de.kruschinski.werwolf.game;

/** Fehler, deren Text direkt beim Spieler angezeigt werden darf. */
public class GameException extends RuntimeException {

    public GameException(String message) {
        super(message);
    }
}
