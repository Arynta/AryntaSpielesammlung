package de.kruschinski.werwolf.game;

/** Die Spiele, die der Host in der Lobby auswählen kann. */
public enum GameType {

    WERWOLF("Werwolf", 4, "Rollen werden geheim verteilt. Nachts jagen die Werwölfe, tagsüber sucht das Dorf sie."),
    IMPOSTOR("Impostor", 3, "Alle kennen dasselbe geheime Wort, nur einer nicht. Findet ihn, bevor er sich durchmogelt."),
    TABU("Tabu", 4, "Erklärt eurem Team Begriffe, ohne die verbotenen Wörter zu sagen. Ein Aufpasser hat den Buzzer."),
    NOBODY_IS_PERFECT("Nobody is Perfect", 3, "Zu kuriosen Fragen erfindet jeder eine glaubwürdige Antwort. Wer findet die echte, wer legt die anderen rein?"),
    BUZZER("Buzzer", 2, "Kein Spiel, sondern ein Werkzeug fürs Quiz: Wer zuerst drückt, ist dran. Die Spielleitung sieht die Reihenfolge."),
    GEO_BINGO("Geo-Bingo", 2, "Ihr lauft durch Straßenbilder derselben Stadt und sucht die Motive eurer Bingo-Karte. Die anderen bestätigen jeden Fund.");

    private final String displayName;
    private final int minPlayers;
    private final String description;

    GameType(String displayName, int minPlayers, String description) {
        this.displayName = displayName;
        this.minPlayers = minPlayers;
        this.description = description;
    }

    public String displayName() {
        return displayName;
    }

    public int minPlayers() {
        return minPlayers;
    }

    public String description() {
        return description;
    }
}
