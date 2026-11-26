package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.i18n.Language;

import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * Das, was ein bestimmter Spieler vom Raum sehen darf.
 * Jeder Spieler bekommt seine eigene Ansicht, damit Rollen und Wörter geheim bleiben.
 *
 * <p>{@code werwolf}, {@code impostor}, {@code tabu}, {@code nobodyIsPerfect}, {@code buzzer} bzw. {@code geoBingo} ist nur gefüllt, solange das jeweilige Spiel läuft.
 */
public record RoomView(
        String code,
        GameType game,
        List<GameOption> games,
        ImpostorSettings impostorSettings,
        WerwolfSettings werwolfSettings,
        TabuSettings tabuSettings,
        NobodyIsPerfectSettings nobodyIsPerfectSettings,
        BuzzerSettings buzzerSettings,
        GeoBingoSettings geoBingoSettings,
        PlayerLimit playerLimit,
        Phase phase,
        int round,
        String hostId,
        List<PlayerView> players,
        boolean canStart,
        String startHint,
        You you,
        WerwolfView werwolf,
        ImpostorView impostor,
        TabuView tabu,
        NobodyIsPerfectView nobodyIsPerfect,
        BuzzerView buzzer,
        GeoBingoView geoBingo
) {

    /** Öffentliche Infos über einen Mitspieler (ohne Rolle!). */
    public record PlayerView(String id, String name, boolean alive, boolean connected, boolean ready) {
    }

    /** Infos nur für den Spieler selbst. */
    public record You(String id, String name, boolean host, boolean ready) {
    }

    /** Ein Spiel, das der Host auswählen kann. {@code locked}: noch nicht wählbar ("Bald verfügbar"). */
    public record GameOption(GameType type, String name, String description, int minPlayers, boolean locked) {

        static List<GameOption> all(Set<GameType> lockedGames, Language language) {
            return Arrays.stream(GameType.values())
                    .map(t -> new GameOption(t, t.displayName().in(language), t.description().in(language),
                            t.minPlayers(), lockedGames.contains(t)))
                    .toList();
        }
    }

    /**
     * {@code customWord} steht nur in der Ansicht des Hosts, alle anderen sehen nur, ob eins gesetzt ist.
     * Kategorien werden über ihre ID gewählt, {@code categoryNames} sind die Namen dazu in derselben Reihenfolge.
     */
    public record ImpostorSettings(
            boolean impostorSeesCategory,
            boolean customWordSet,
            String customWord,
            List<String> allCategories,
            List<String> categoryNames,
            List<String> selectedCategories,
            int impostorCount,
            int maxImpostorCount,
            boolean randomStartPlayer
    ) {
    }

    /**
     * {@code werewolfCount} ist {@code null} bei automatischer Anzahl. {@code effectiveWerewolfCount}
     * sagt, wie viele es mit den Spielern im Raum gerade wären.
     */
    public record WerwolfSettings(
            Integer werewolfCount,
            int effectiveWerewolfCount,
            List<RoleCard> allRoles,
            List<String> selectedRoles,
            boolean hostIsGameMaster
    ) {
    }

    /** {@code teams}: Spieler-IDs pro Team, wenn jeder sein Team selbst wählt. */
    public record TabuSettings(int turnSeconds, boolean autoTeams, int teamCount, int targetScore, List<List<String>> teams) {
    }

    public record TabuTeam(String name, List<String> playerIds, int score) {
    }

    public record TabuCard(String word, List<String> forbidden) {
    }

    /**
     * {@code card} sehen nur Erklärer und Aufpasser. {@code remainingMs} ist die Restzeit des laufenden Zugs,
     * damit jedes Handy unabhängig von seiner eigenen Uhr richtig herunterzählt.
     */
    public record TabuView(
            List<TabuTeam> teams,
            int currentTeam,
            int watcherTeam,
            String explainerId,
            String watcherId,
            Integer yourTeam,
            long remainingMs,
            int turnSeconds,
            int targetScore,
            TabuCard card,
            List<TabuGame.CardResult> turnResults,
            List<TabuGame.CardResult> lastTurn,
            Integer winnerTeam
    ) {
    }

    public record NobodyIsPerfectSettings(int questionCount) {
    }

    public record NobodyIsPerfectChoice(String id, String text) {
    }

    /** Eine Antwort nach der Auflösung: wer sie erfunden hat ({@code null} bei der echten) und wer darauf getippt hat. */
    public record NobodyIsPerfectReveal(String id, String text, boolean correct, String authorId, List<String> guesserIds) {
    }

    /** {@code gained}: Punkte für die zuletzt aufgelöste Frage. */
    public record NobodyIsPerfectScore(String playerId, int score, int gained) {
    }

    /**
     * {@code choices} gibt es ab dem Tippen, die echte {@code answer} und {@code reveal} erst nach der Auflösung.
     * Wer welche Antwort erfunden hat, steht vorher nirgends drin, nur die eigene ({@code yourChoiceId}).
     */
    public record NobodyIsPerfectView(
            int questionNumber,
            int questionCount,
            String question,
            String answer,
            List<String> participantIds,
            List<String> answeredIds,
            String yourAnswer,
            List<NobodyIsPerfectChoice> choices,
            String yourChoiceId,
            List<String> guessedIds,
            String yourGuess,
            List<NobodyIsPerfectReveal> reveal,
            List<NobodyIsPerfectScore> scores
    ) {
    }

    public record BuzzerSettings(boolean lockout) {
    }

    /** {@code offsetMs}: wie viel später als der Erste gedrückt wurde. */
    public record BuzzerPress(String playerId, int rank, long offsetMs) {
    }

    /** Die ganze Reihenfolge ({@code presses}) sieht nur die Spielleitung, Spieler nur ihren Platz. */
    public record BuzzerView(boolean lockout, List<BuzzerPress> presses, Integer yourRank, boolean canPress) {
    }

    public record GeoBingoSettings(int minutes, int minMinutes, int maxMinutes) {
    }

    /** {@code fields}: bestätigte Felder der Karte (0 bis 8, zeilenweise). */
    public record GeoBingoScore(String playerId, List<Integer> fields) {
    }

    /**
     * Ein Fund, über den gerade abgestimmt wird. {@code imageId}, {@code x}, {@code y} und {@code zoom}
     * zeigen genau die gemeldete Ansicht. {@code yourVote} ist {@code null}, solange man nicht abgestimmt hat.
     */
    public record GeoBingoClaim(String id, String playerId, int field, String imageId, double x, double y, double zoom,
                                long remainingMs, List<String> votedIds, Boolean yourVote) {
    }

    /**
     * {@code lat}/{@code lng}: Mittelpunkt, um den die App das Startbild sucht. {@code winnerIds} ist erst
     * am Ende gefüllt, {@code winningLine} nur, wenn jemand eine Reihe voll hat.
     */
    public record GeoBingoView(
            String place,
            double lat,
            double lng,
            List<String> board,
            long remainingMs,
            List<GeoBingoScore> scores,
            List<GeoBingoClaim> claims,
            List<GeoBingoGame.Decision> decisions,
            List<String> winnerIds,
            List<Integer> winningLine
    ) {
    }

    /** Aktuelles Limit und in welchem Bereich der Host es gerade einstellen darf. */
    public record PlayerLimit(int value, int min, int max) {
    }

    /** Eine Rolle so, wie sie auf der Karte steht. */
    public record RoleCard(String id, String name, String team, String teamName, String description) {

        static RoleCard of(Role role, Language language) {
            Role translated = WerwolfRoles.byId(role.id(), language);
            return new RoleCard(role.id(), translated.name(), role.team(),
                    WerwolfRoles.teamName(role.team(), language), translated.description());
        }
    }

    public record RoleAssignment(String playerId, String playerName, RoleCard role) {
    }

    /**
     * Für Mitspieler: eigene Karte, bekannte Wölfe und beim Dieb die übrigen Karten.
     * Für die Spielleitung: {@code gameMaster}, alle Rollen in {@code overview} und die übrigen Karten.
     */
    public record WerwolfView(
            boolean gameMaster,
            RoleCard role,
            List<String> knownWolves,
            List<String> leftoverRoles,
            List<RoleAssignment> overview
    ) {
    }

    /**
     * {@code word} fehlt bei Impostorn. {@code category} bekommen sie nur, wenn der Host das eingestellt hat.
     * {@code result} gibt es erst nach der Abstimmung, vorher erfährt niemand, wer Impostor ist.
     */
    public record ImpostorView(
            ImpostorGame.Part part,
            String word,
            String category,
            List<String> fellowImpostors,
            String startPlayerId,
            String gameMasterId,
            List<String> participantIds,
            List<String> votedIds,
            String yourVote,
            ImpostorResult result
    ) {
    }

    public record ImpostorResult(
            List<String> impostorIds,
            List<String> impostorNames,
            String word,
            String category,
            boolean impostorCaught,
            List<VoteCount> votes
    ) {
    }

    public record VoteCount(String playerId, String name, int votes) {
    }
}
