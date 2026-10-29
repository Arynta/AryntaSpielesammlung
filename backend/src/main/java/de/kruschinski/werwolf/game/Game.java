package de.kruschinski.werwolf.game;

/** Ein laufendes Spiel in einem Raum. Die Lobby (Spieler, Host, Bereit) verwaltet {@link Room}. */
public sealed interface Game permits WerwolfGame, ImpostorGame {

    GameType type();

    Phase phase();

    int round();

    /** Ob die Spieler sich gerade für die nächste Runde bereit machen können. */
    boolean betweenRounds();
}
