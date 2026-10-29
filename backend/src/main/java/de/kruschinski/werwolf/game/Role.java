package de.kruschinski.werwolf.game;

public enum Role {

    WERWOLF("Werwolf", "Du wachst nachts mit den anderen Werwölfen auf und sucht euch ein Opfer aus."),
    SEHERIN("Seherin", "Du darfst jede Nacht die Rolle eines Mitspielers ansehen."),
    DORFBEWOHNER("Dorfbewohner", "Du hast keine Sonderfähigkeit. Finde tagsüber die Werwölfe!");

    private final String displayName;
    private final String description;

    Role(String displayName, String description) {
        this.displayName = displayName;
        this.description = description;
    }

    public String displayName() {
        return displayName;
    }

    public String description() {
        return description;
    }
}
