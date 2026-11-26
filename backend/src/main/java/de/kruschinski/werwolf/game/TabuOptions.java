package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Text;

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
            throw new GameException("error.tabu.turnSeconds", MIN_TURN_SECONDS, MAX_TURN_SECONDS);
        }
        if (teamCount < MIN_TEAMS || teamCount > MAX_TEAMS) {
            throw new GameException("error.tabu.teamCount", MIN_TEAMS, MAX_TEAMS);
        }
        if (targetScore < MIN_TARGET_SCORE || targetScore > MAX_TARGET_SCORE) {
            throw new GameException("error.tabu.targetScore", MIN_TARGET_SCORE, MAX_TARGET_SCORE);
        }
    }

    /**
     * Warum mit dieser Aufteilung nicht gestartet werden kann, oder {@code null}.
     *
     * @param chosenTeamSizes Spieler pro Team bei selbst gewählten Teams, sonst ignoriert
     * @param unassigned      wie viele noch kein Team gewählt haben
     */
    public Text problem(int playerCount, List<Integer> chosenTeamSizes, int unassigned) {
        int needed = teamCount * MIN_TEAM_SIZE;
        if (playerCount < needed) {
            return Text.of("hint.tabu.minPlayers", teamCount, needed);
        }
        if (autoTeams) {
            return null;
        }
        if (unassigned > 0) {
            return unassigned == 1
                    ? Text.of("hint.tabu.oneUnassigned")
                    : Text.of("hint.tabu.unassigned", unassigned);
        }
        if (chosenTeamSizes.stream().anyMatch(size -> size < MIN_TEAM_SIZE)) {
            return Text.of("hint.tabu.teamSize", MIN_TEAM_SIZE);
        }
        return null;
    }
}
