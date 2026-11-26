package de.kruschinski.werwolf.game;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.function.Predicate;
import java.util.regex.Pattern;

/**
 * Geo-Bingo: Alle laufen durch Straßenbilder derselben Stadt und suchen die Motive ihrer 3×3-Karte.
 * Wer etwas findet, meldet die genaue Ansicht. Die anderen sehen dieselbe Stelle und stimmen ab.
 * Gewonnen hat, wer zuerst eine Reihe voll hat, sonst nach Ablauf der Zeit, wer die meisten Felder hat.
 * Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class GeoBingoGame implements Game {

    public static final int SIZE = 3;
    public static final Duration VOTE_TIME = Duration.ofSeconds(20);
    private static final int MAX_DECISIONS = 5;
    private static final double MAX_ZOOM = 3;
    /** Mapillary-Bild-IDs sind Zahlen. Alles andere kann die App nicht anzeigen. */
    private static final Pattern IMAGE_ID = Pattern.compile("\\d{1,20}");
    private static final List<List<Integer>> LINES = List.of(
            List.of(0, 1, 2), List.of(3, 4, 5), List.of(6, 7, 8),
            List.of(0, 3, 6), List.of(1, 4, 7), List.of(2, 5, 8),
            List.of(0, 4, 8), List.of(2, 4, 6));

    /** Genau die Ansicht, die gemeldet wurde: Bild, Blickpunkt im Bild (0 bis 1) und Zoom. */
    public record Spot(String imageId, double x, double y, double zoom) {

        public Spot {
            if (imageId == null || !IMAGE_ID.matcher(imageId).matches()) {
                throw new GameException("error.geoBingo.unknownImage");
            }
            if (!inRange(x, 1) || !inRange(y, 1) || !inRange(zoom, MAX_ZOOM)) {
                throw new GameException("error.geoBingo.invalidView");
            }
        }

        private static boolean inRange(double value, double max) {
            return value >= 0 && value <= max;
        }
    }

    /** Ergebnis einer Abstimmung, damit alle sehen, was zuletzt bestätigt oder abgelehnt wurde. */
    public record Decision(String playerId, int field, boolean accepted) {
    }

    private record Claim(String id, String playerId, int field, Spot spot, Instant deadline, Map<String, Boolean> votes) {
    }

    private final List<Player> participants;
    private final GeoBingoData.Place place;
    private final List<String> board;
    private final int round;
    private final Instant endsAt;
    private final Map<String, Set<Integer>> found = new HashMap<>();
    private final List<Claim> claims = new ArrayList<>();
    private final LinkedList<Decision> decisions = new LinkedList<>();
    private int nextClaim = 1;
    private Phase phase = Phase.GEO_BINGO;
    private List<String> winnerIds = List.of();
    private List<Integer> winningLine;

    GeoBingoGame(List<Player> participants, GeoBingoData.Place place, List<String> board,
                 GeoBingoOptions options, int round, Instant now) {
        if (board.size() != SIZE * SIZE) {
            throw new IllegalArgumentException("Die Karte braucht " + SIZE * SIZE + " Motive, nicht " + board.size());
        }
        this.participants = List.copyOf(participants);
        this.place = place;
        this.board = List.copyOf(board);
        this.round = round;
        this.endsAt = now.plus(Duration.ofMinutes(options.minutes()));
    }

    @Override
    public GameType type() {
        return GameType.GEO_BINGO;
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

    void claim(String playerId, int field, Spot spot, Instant now) {
        requireRunning();
        requireParticipant(playerId);
        if (field < 0 || field >= board.size()) {
            throw new GameException("error.geoBingo.unknownField");
        }
        if (foundBy(playerId).contains(field)) {
            throw new GameException("error.geoBingo.fieldTaken");
        }
        if (claims.stream().anyMatch(c -> c.playerId().equals(playerId))) {
            throw new GameException("error.geoBingo.waitForVote");
        }
        claims.add(new Claim("c" + nextClaim++, playerId, field, spot, now.plus(VOTE_TIME), new LinkedHashMap<>()));
        resolveCompleteClaims();
    }

    /** Wer schon abgestimmt hat, kann seine Stimme nicht mehr ändern. */
    void vote(String voterId, String claimId, boolean accept) {
        requireRunning();
        requireParticipant(voterId);
        Claim claim = claims.stream().filter(c -> c.id().equals(claimId)).findFirst()
                .orElseThrow(() -> new GameException("error.geoBingo.voteClosed"));
        if (claim.playerId().equals(voterId)) {
            throw new GameException("error.geoBingo.ownClaim");
        }
        claim.votes().putIfAbsent(voterId, accept);
        resolveCompleteClaims();
    }

    /** Entscheidet Abstimmungen, bei denen alle Mitspieler online abgestimmt haben. */
    void resolveCompleteClaims() {
        resolve(this::everyoneVoted);
    }

    /** Für die Uhr im Server: Abstimmungs- und Spielzeit prüfen. {@code true}, wenn sich etwas geändert hat. */
    boolean expire(Instant now) {
        if (phase != Phase.GEO_BINGO) {
            return false;
        }
        boolean changed = resolve(c -> !now.isBefore(c.deadline()));
        if (phase == Phase.GEO_BINGO && !now.isBefore(endsAt)) {
            // Offene Funde zählen noch mit den Stimmen, die bis jetzt da sind
            resolve(c -> true);
            if (phase == Phase.GEO_BINGO) {
                finishByTime();
            }
            changed = true;
        }
        return changed;
    }

    /** Wann sich als Nächstes von selbst etwas ändert, oder {@code null}, wenn das Spiel vorbei ist. */
    Instant nextDeadline() {
        if (phase != Phase.GEO_BINGO) {
            return null;
        }
        return claims.stream().map(Claim::deadline).filter(endsAt::isAfter).min(Comparator.naturalOrder()).orElse(endsAt);
    }

    RoomView.GeoBingoView viewFor(String playerId, Instant now) {
        List<RoomView.GeoBingoScore> scores = participants.stream()
                .map(p -> new RoomView.GeoBingoScore(p.id(), List.copyOf(foundBy(p.id()))))
                .toList();
        List<RoomView.GeoBingoClaim> openClaims = claims.stream()
                .map(c -> new RoomView.GeoBingoClaim(c.id(), c.playerId(), c.field(), c.spot().imageId(),
                        c.spot().x(), c.spot().y(), c.spot().zoom(), remainingMs(c.deadline(), now),
                        List.copyOf(c.votes().keySet()), c.votes().get(playerId)))
                .toList();
        return new RoomView.GeoBingoView(place.name(), place.lat(), place.lng(), board,
                remainingMs(endsAt, now), scores, openClaims, List.copyOf(decisions), winnerIds, winningLine);
    }

    private boolean resolve(Predicate<Claim> due) {
        List<Claim> dueClaims = claims.stream().filter(due).toList();
        for (Claim claim : dueClaims) {
            if (phase != Phase.GEO_BINGO) {
                break;
            }
            claims.remove(claim);
            decide(claim);
        }
        if (phase != Phase.GEO_BINGO) {
            claims.clear();
        }
        return !dueClaims.isEmpty();
    }

    private boolean everyoneVoted(Claim claim) {
        return participants.stream()
                .filter(p -> p.connected() && !p.id().equals(claim.playerId()))
                .allMatch(p -> claim.votes().containsKey(p.id()));
    }

    /** Die Mehrheit der abgegebenen Stimmen entscheidet. Bei Gleichstand oder ohne Stimmen gilt der Fund. */
    private void decide(Claim claim) {
        long yes = claim.votes().values().stream().filter(Boolean::booleanValue).count();
        boolean accepted = yes * 2 >= claim.votes().size();
        decisions.addFirst(new Decision(claim.playerId(), claim.field(), accepted));
        if (decisions.size() > MAX_DECISIONS) {
            decisions.removeLast();
        }
        if (!accepted) {
            return;
        }
        Set<Integer> fields = foundBy(claim.playerId());
        fields.add(claim.field());
        LINES.stream().filter(fields::containsAll).findFirst().ifPresent(line -> {
            winnerIds = List.of(claim.playerId());
            winningLine = line;
            phase = Phase.RESULT;
        });
    }

    private void finishByTime() {
        int best = participants.stream().mapToInt(p -> foundBy(p.id()).size()).max().orElse(0);
        winnerIds = best == 0 ? List.of() : participants.stream()
                .map(Player::id)
                .filter(id -> foundBy(id).size() == best)
                .toList();
        phase = Phase.RESULT;
    }

    private Set<Integer> foundBy(String playerId) {
        return found.computeIfAbsent(playerId, id -> new TreeSet<>());
    }

    private static long remainingMs(Instant deadline, Instant now) {
        return Math.max(0, Duration.between(now, deadline).toMillis());
    }

    private void requireRunning() {
        if (phase != Phase.GEO_BINGO) {
            throw new GameException("error.gameOver");
        }
    }

    private void requireParticipant(String playerId) {
        if (participants.stream().noneMatch(p -> p.id().equals(playerId))) {
            throw new GameException("error.notInRound");
        }
    }
}
