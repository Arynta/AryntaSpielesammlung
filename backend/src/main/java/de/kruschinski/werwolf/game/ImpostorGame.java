package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.ImpostorWords.SecretWord;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.random.RandomGenerator;

/**
 * Eine Runde Impostor: Alle kennen dasselbe Wort, nur die Impostor nicht. Hinweise und Diskussion
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
    private final Set<String> impostorIds;
    private final String startPlayerId;
    private final SecretWord secret;
    private final boolean impostorSeesCategory;
    private final int round;
    private final Map<String, String> targetByVoterId = new LinkedHashMap<>();
    private Phase phase = Phase.WORD;

    /**
     * @param participants alle, die mitspielen (ohne Spielleitung)
     * @param gameMasterId Host, der das Wort vorgegeben hat, oder {@code null}, wenn alle mitspielen
     */
    ImpostorGame(List<Player> participants, String gameMasterId, SecretWord secret, ImpostorOptions options,
                 int round, RandomGenerator random) {
        String problem = options.problem(participants.size());
        if (problem != null) {
            throw new GameException(problem);
        }
        this.participants = List.copyOf(participants);
        this.gameMasterId = gameMasterId;
        this.secret = secret;
        this.impostorSeesCategory = options.impostorSeesCategory();
        this.round = round;

        int count = options.impostorCount();
        List<Player> shuffled = new ArrayList<>(participants);
        Shuffle.inPlace(shuffled, random);
        this.impostorIds = Set.copyOf(shuffled.subList(0, count).stream().map(Player::id).toList());
        // Ein Impostor als Erster hätte gar keinen Hinweis, deshalb fängt immer jemand aus der Crew an
        this.startPlayerId = options.randomStartPlayer()
                ? shuffled.get(count + random.nextInt(shuffled.size() - count)).id()
                : null;
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

    public Set<String> impostorIds() {
        return impostorIds;
    }

    public String startPlayerId() {
        return startPlayerId;
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

    /** Die Crew gewinnt nur, wenn ein Impostor allein die meisten Stimmen hat. Ein Gleichstand hilft den Impostorn. */
    public boolean impostorCaught() {
        Map<String, Integer> votes = votesPerTarget();
        int most = votes.values().stream().mapToInt(Integer::intValue).max().orElse(0);
        List<String> leaders = votes.entrySet().stream()
                .filter(e -> e.getValue() == most)
                .map(Map.Entry::getKey)
                .toList();
        return leaders.size() == 1 && impostorIds.contains(leaders.getFirst());
    }

    RoomView.ImpostorView viewFor(String playerId) {
        Part part = partOf(playerId);
        String word = part == Part.IMPOSTOR ? null : secret.word();
        String category = part != Part.IMPOSTOR || impostorSeesCategory ? secret.category() : null;
        List<String> fellowImpostors = part == Part.IMPOSTOR ? impostorNamesExcept(playerId) : List.of();

        List<String> votedIds = List.copyOf(targetByVoterId.keySet());
        RoomView.ImpostorResult result = phase == Phase.RESULT ? result() : null;

        return new RoomView.ImpostorView(
                part,
                word,
                category,
                fellowImpostors,
                startPlayerId,
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
        List<Player> impostors = participants.stream().filter(p -> impostorIds.contains(p.id())).toList();
        return new RoomView.ImpostorResult(
                impostors.stream().map(Player::id).toList(),
                impostors.stream().map(Player::name).toList(),
                secret.word(),
                secret.category(),
                impostorCaught(),
                tally);
    }

    private List<String> impostorNamesExcept(String playerId) {
        return participants.stream()
                .filter(p -> impostorIds.contains(p.id()) && !p.id().equals(playerId))
                .map(Player::name)
                .toList();
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
        return impostorIds.contains(playerId) ? Part.IMPOSTOR : Part.CREW;
    }

    private boolean isParticipant(String playerId) {
        return participants.stream().anyMatch(p -> p.id().equals(playerId));
    }
}
