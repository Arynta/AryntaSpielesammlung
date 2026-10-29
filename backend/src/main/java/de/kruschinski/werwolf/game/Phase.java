package de.kruschinski.werwolf.game;

public enum Phase {
    /** Spieler treten bei, wählen das Spiel und machen sich bereit. */
    LOBBY,

    // Werwolf
    NIGHT,
    DAY,

    // Impostor
    /** Jeder sieht sein Wort, Hinweise und Diskussion laufen am Tisch. */
    WORD,
    VOTING,
    RESULT
}
