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
    /** Ergebnis einer Runde bzw. Spielende. */
    RESULT,

    // Tabu
    /** Das nächste Team ist dran, der Erklärer startet die Uhr. */
    TURN_READY,
    /** Die Uhr läuft. */
    TURN,

    // Nobody is Perfect
    /** Jeder denkt sich eine Antwort aus. */
    WRITING,
    /** Alle Antworten stehen zur Wahl, jeder tippt auf die echte. */
    GUESSING,
    /** Auflösung einer Frage. Nach der letzten Frage kommt stattdessen RESULT. */
    REVEAL
}
