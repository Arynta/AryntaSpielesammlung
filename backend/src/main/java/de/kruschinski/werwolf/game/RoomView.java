package de.kruschinski.werwolf.game;

import java.util.Arrays;
import java.util.List;

/**
 * Das, was ein bestimmter Spieler vom Raum sehen darf.
 * Jeder Spieler bekommt seine eigene Ansicht, damit Rollen und Wörter geheim bleiben.
 *
 * <p>{@code werwolf} bzw. {@code impostor} ist nur gefüllt, solange das jeweilige Spiel läuft.
 */
public record RoomView(
        String code,
        GameType game,
        List<GameOption> games,
        ImpostorSettings impostorSettings,
        WerwolfSettings werwolfSettings,
        PlayerLimit playerLimit,
        Phase phase,
        int round,
        String hostId,
        List<PlayerView> players,
        boolean canStart,
        String startHint,
        You you,
        WerwolfView werwolf,
        ImpostorView impostor
) {

    /** Öffentliche Infos über einen Mitspieler (ohne Rolle!). */
    public record PlayerView(String id, String name, boolean alive, boolean connected, boolean ready) {
    }

    /** Infos nur für den Spieler selbst. */
    public record You(String id, String name, boolean host, boolean ready) {
    }

    /** Ein Spiel, das der Host auswählen kann. */
    public record GameOption(GameType type, String name, String description, int minPlayers) {

        static List<GameOption> all() {
            return Arrays.stream(GameType.values())
                    .map(t -> new GameOption(t, t.displayName(), t.description(), t.minPlayers()))
                    .toList();
        }
    }

    /** {@code customWord} steht nur in der Ansicht des Hosts, alle anderen sehen nur, ob eins gesetzt ist. */
    public record ImpostorSettings(
            boolean impostorSeesCategory,
            boolean customWordSet,
            String customWord,
            List<String> allCategories,
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

    /** Aktuelles Limit und in welchem Bereich der Host es gerade einstellen darf. */
    public record PlayerLimit(int value, int min, int max) {
    }

    /** Eine Rolle so, wie sie auf der Karte steht. */
    public record RoleCard(String id, String name, String team, String teamName, String description) {

        static RoleCard of(Role role) {
            return new RoleCard(role.id(), role.name(), role.team(), WerwolfRoles.teamName(role.team()), role.description());
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
