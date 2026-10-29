package de.kruschinski.werwolf.game;

/** Die Spiele, die der Host in der Lobby auswählen kann. */
public enum GameType {

    WERWOLF("Werwolf", 4, "Rollen werden geheim verteilt. Nachts jagen die Werwölfe, tagsüber sucht das Dorf sie."),
    IMPOSTOR("Impostor", 3, "Alle kennen dasselbe geheime Wort, nur einer nicht. Findet ihn, bevor er sich durchmogelt.");

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
