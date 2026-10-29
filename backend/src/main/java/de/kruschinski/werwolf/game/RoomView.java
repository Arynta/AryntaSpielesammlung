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
    public record ImpostorSettings(boolean impostorSeesCategory, boolean customWordSet, String customWord) {
    }

    public record WerwolfView(Role role, String roleName, String roleDescription, List<String> fellowWerewolves) {
    }

    /**
     * {@code word} fehlt beim Impostor. {@code category} bekommt er nur, wenn der Host das eingestellt hat.
     * {@code result} gibt es erst nach der Abstimmung, vorher erfährt niemand, wer der Impostor ist.
     */
    public record ImpostorView(
            ImpostorGame.Part part,
            String word,
            String category,
            String gameMasterId,
            List<String> participantIds,
            List<String> votedIds,
            String yourVote,
            ImpostorResult result
    ) {
    }

    public record ImpostorResult(
            String impostorId,
            String impostorName,
            String word,
            String category,
            boolean impostorCaught,
            List<VoteCount> votes
    ) {
    }

    public record VoteCount(String playerId, String name, int votes) {
    }
}
