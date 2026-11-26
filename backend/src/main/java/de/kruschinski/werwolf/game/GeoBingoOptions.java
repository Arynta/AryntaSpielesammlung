package de.kruschinski.werwolf.game;

/** Einstellungen für Geo-Bingo, die der Host in der Lobby wählt. */
public record GeoBingoOptions(int minutes) {

    public static final int MIN_MINUTES = 5;
    public static final int MAX_MINUTES = 30;

    public static final GeoBingoOptions DEFAULT = new GeoBingoOptions(10);

    public GeoBingoOptions {
        if (minutes < MIN_MINUTES || minutes > MAX_MINUTES) {
            throw new GameException("error.geoBingo.minutes", MIN_MINUTES, MAX_MINUTES);
        }
    }
}
