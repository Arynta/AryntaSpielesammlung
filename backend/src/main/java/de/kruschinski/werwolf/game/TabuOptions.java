package de.kruschinski.werwolf.game;

import java.util.List;

/** Einstellungen für Tabu, die der Host in der Lobby wählt. */
public record TabuOptions(int turnSeconds, boolean autoTeams, int teamCount, int targetScore) {

    public static final int MIN_TURN_SECONDS = 30;
    public static final int MAX_TURN_SECONDS = 180;
    public static final int MIN_TEAMS = 2;
    public static final int MAX_TEAMS = 4;
    public static final int MIN_TARGET_SCORE = 10;
    public static final int MAX_TARGET_SCORE = 100;
    /** Einer erklärt, mindestens einer rät. */
    public static final int MIN_TEAM_SIZE = 2;

    public static final TabuOptions DEFAULT = new TabuOptions(60, true, 2, 30);

    public TabuOptions {
        if (turnSeconds < MIN_TURN_SECONDS || turnSeconds > MAX_TURN_SECONDS) {
            throw new GameException("Die Zeit muss zwischen " + MIN_TURN_SECONDS + " und " + MAX_TURN_SECONDS + " Sekunden liegen.");
        }
        if (teamCount < MIN_TEAMS || teamCount > MAX_TEAMS) {
            throw new GameException("Es kann " + MIN_TEAMS + " bis " + MAX_TEAMS + " Teams geben.");
        }
        if (targetScore < MIN_TARGET_SCORE || targetScore > MAX_TARGET_SCORE) {
            throw new GameException("Die Siegpunkte müssen zwischen " + MIN_TARGET_SCORE + " und " + MAX_TARGET_SCORE + " liegen.");
        }
    }

    /**
     * Warum mit dieser Aufteilung nicht gestartet werden kann, oder {@code null}.
     *
     * @param chosenTeamSizes Spieler pro Team bei selbst gewählten Teams, sonst ignoriert
     * @param unassigned      wie viele noch kein Team gewählt haben
     */
    public String problem(int playerCount, List<Integer> chosenTeamSizes, int unassigned) {
        int needed = teamCount * MIN_TEAM_SIZE;
        if (playerCount < needed) {
            return "Für " + teamCount + " Teams braucht es mindestens " + needed + " Spieler.";
        }
        if (autoTeams) {
            return null;
        }
        if (unassigned > 0) {
            return unassigned == 1
                    ? "1 Spieler hat noch kein Team gewählt."
                    : unassigned + " Spieler haben noch kein Team gewählt.";
        }
        if (chosenTeamSizes.stream().anyMatch(size -> size < MIN_TEAM_SIZE)) {
            return "Jedes Team braucht mindestens " + MIN_TEAM_SIZE + " Spieler.";
        }
        return null;
    }
}
