package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Text;

/** Die Spiele, die der Host in der Lobby auswählen kann. Name und Beschreibung stehen in i18n/messages*.properties. */
public enum GameType {

    WERWOLF(4),
    IMPOSTOR(3),
    TABU(4),
    NOBODY_IS_PERFECT(3),
    BUZZER(2),
    GEO_BINGO(2);

    private final int minPlayers;

    GameType(int minPlayers) {
        this.minPlayers = minPlayers;
    }

    public Text displayName() {
        return Text.of("game." + name() + ".name");
    }

    public int minPlayers() {
        return minPlayers;
    }

    public Text description() {
        return Text.of("game." + name() + ".description");
    }
}
