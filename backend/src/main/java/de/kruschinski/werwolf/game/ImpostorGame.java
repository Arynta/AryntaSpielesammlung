package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.ImpostorWords.SecretWord;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.random.RandomGenerator;

/**
 * Eine Runde Impostor: Alle kennen dasselbe Wort, nur der Impostor nicht. Hinweise und Diskussion
 * laufen am Tisch, abgestimmt wird im Handy. Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class ImpostorGame implements Game {

    /** Was ein Spieler in dieser Runde ist. */
    public enum Part {
        CREW,
        IMPOSTOR,
        /** Der Host hat ein eigenes Wort vorgegeben und spielt deshalb nicht mit. */
        GAME_MASTER
    }

    private final List<Player> participants;
    private final String gameMasterId;
    private final String impostorId;
    private final SecretWord secret;
    private final boolean impostorSeesCategory;
    private final int round;
    private final Map<String, String> targetByVoterId = new LinkedHashMap<>();
    private Phase phase = Phase.WORD;

    /**
     * @param participants alle, die mitspielen (ohne Spielleitung)
     * @param gameMasterId Host, der das Wort vorgegeben hat, oder {@code null}, wenn alle mitspielen
     */
    ImpostorGame(List<Player> participants, String gameMasterId, SecretWord secret,
                 boolean impostorSeesCategory, int round, RandomGenerator random) {
        int minPlayers = GameType.IMPOSTOR.minPlayers();
        if (participants.size() < minPlayers) {
            throw new GameException("Für Impostor braucht es mindestens " + minPlayers + " Mitspieler.");
        }
        this.participants = List.copyOf(participants);
        this.gameMasterId = gameMasterId;
        this.impostorId = participants.get(random.nextInt(participants.size())).id();
        this.secret = secret;
        this.impostorSeesCategory = impostorSeesCategory;
        this.round = round;
    }

    @Override
    public GameType type() {
        return GameType.IMPOSTOR;
    }

    @Override
    public Phase phase() {
        return phase;
    }

    @Override
    public int round() {
        return round;
    }

    @Override
    public boolean betweenRounds() {
        return phase == Phase.RESULT;
    }

    public String impostorId() {
        return impostorId;
    }

    public SecretWord secret() {
        return secret;
    }

    void startVoting() {
        if (phase != Phase.WORD) {
            throw new GameException("Die Abstimmung hat schon begonnen.");
        }
        phase = Phase.VOTING;
        closeVotingIfComplete();
    }

    /** Eine Stimme abgeben oder ändern. Sind alle verbundenen Mitspieler fertig, folgt die Auflösung. */
    void vote(String voterId, String targetId) {
        if (phase != Phase.VOTING) {
            throw new GameException("Gerade wird nicht abgestimmt.");
        }
        if (!isParticipant(voterId)) {
            throw new GameException("Du spielst in dieser Runde nicht mit.");
        }
        if (voterId.equals(targetId)) {
            throw new GameException("Du kannst nicht für dich selbst stimmen.");
        }
        if (!isParticipant(targetId)) {
            throw new GameException("Diesen Spieler gibt es in dieser Runde nicht.");
        }
        targetByVoterId.put(voterId, targetId);
        closeVotingIfComplete();
    }

    /** Auch aufrufen, wenn jemand offline geht: Auf ihn wird dann nicht mehr gewartet. */
    void closeVotingIfComplete() {
        if (phase != Phase.VOTING || targetByVoterId.isEmpty()) {
            return;
        }
        boolean everyoneVoted = participants.stream()
                .filter(Player::connected)
                .allMatch(p -> targetByVoterId.containsKey(p.id()));
        if (everyoneVoted) {
            phase = Phase.RESULT;
        }
    }

    /** Die Mitspieler gewinnen nur, wenn der Impostor allein die meisten Stimmen hat. */
    public boolean impostorCaught() {
        Map<String, Integer> votes = votesPerTarget();
        int impostorVotes = votes.getOrDefault(impostorId, 0);
        return impostorVotes > 0 && votes.entrySet().stream()
                .filter(e -> !e.getKey().equals(impostorId))
                .allMatch(e -> e.getValue() < impostorVotes);
    }

    RoomView.ImpostorView viewFor(String playerId) {
        Part part = partOf(playerId);
        String word = part == Part.IMPOSTOR ? null : secret.word();
        String category = part != Part.IMPOSTOR || impostorSeesCategory ? secret.category() : null;

        List<String> votedIds = List.copyOf(targetByVoterId.keySet());
        RoomView.ImpostorResult result = phase == Phase.RESULT ? result() : null;

        return new RoomView.ImpostorView(
                part,
                word,
                category,
                gameMasterId,
                participants.stream().map(Player::id).toList(),
                votedIds,
                targetByVoterId.get(playerId),
                result);
    }

    private RoomView.ImpostorResult result() {
        Map<String, Integer> votes = votesPerTarget();
        List<RoomView.VoteCount> tally = participants.stream()
                .map(p -> new RoomView.VoteCount(p.id(), p.name(), votes.getOrDefault(p.id(), 0)))
                .sorted((a, b) -> Integer.compare(b.votes(), a.votes()))
                .toList();
        String impostorName = participants.stream()
                .filter(p -> p.id().equals(impostorId))
                .map(Player::name)
                .findFirst()
                .orElse("?");
        return new RoomView.ImpostorResult(
                impostorId, impostorName, secret.word(), secret.category(), impostorCaught(), tally);
    }

    private Map<String, Integer> votesPerTarget() {
        Map<String, Integer> votes = new HashMap<>();
        targetByVoterId.values().forEach(target -> votes.merge(target, 1, Integer::sum));
        return votes;
    }

    private Part partOf(String playerId) {
        if (playerId.equals(gameMasterId)) {
            return Part.GAME_MASTER;
        }
        return playerId.equals(impostorId) ? Part.IMPOSTOR : Part.CREW;
    }

    private boolean isParticipant(String playerId) {
        return participants.stream().anyMatch(p -> p.id().equals(playerId));
    }
}
