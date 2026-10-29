package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.TabuCards.Card;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.random.RandomGenerator;

/**
 * Tabu: Die Teams sind reihum dran. Der Erklärer beschreibt Begriffe, ohne die verbotenen Wörter
 * zu sagen. Ein Aufpasser aus dem nächsten Team sieht dieselbe Karte und hat den Buzzer.
 * Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class TabuGame implements Game {

    public static final List<String> TEAM_NAMES = List.of("Team Rot", "Team Blau", "Team Grün", "Team Gelb");

    public enum Outcome {
        CORRECT,
        SKIPPED,
        BUZZED
    }

    /** Was mit einer Karte passiert ist und welches Team den Punkt bekam ({@code null}: keins). */
    public record CardResult(String word, Outcome outcome, Integer scoringTeam) {
    }

    private final List<List<Player>> teams;
    private final TabuOptions options;
    private final RandomGenerator random;
    private final int[] scores;
    /** Pro Team: wer als Nächstes erklärt bzw. aufpasst (zählt nur hoch, Rest der Teamgröße zählt). */
    private final int[] explainerTurns;
    private final int[] watcherTurns;
    private final List<Card> deck = new ArrayList<>();
    private final List<CardResult> turnResults = new ArrayList<>();
    private List<CardResult> lastTurn = List.of();
    private Phase phase = Phase.TURN_READY;
    private int currentTeam;
    private int turn = 1;
    private Instant turnEndsAt;
    private Card card;
    private Integer winnerTeam;

    TabuGame(List<List<Player>> teams, TabuOptions options, RandomGenerator random) {
        if (teams.size() != options.teamCount()
                || teams.stream().anyMatch(t -> t.size() < TabuOptions.MIN_TEAM_SIZE)) {
            throw new GameException("Jedes Team braucht mindestens " + TabuOptions.MIN_TEAM_SIZE + " Spieler.");
        }
        this.teams = teams.stream().map(List::copyOf).toList();
        this.options = options;
        this.random = random;
        this.scores = new int[teams.size()];
        this.explainerTurns = new int[teams.size()];
        this.watcherTurns = new int[teams.size()];
    }

    @Override
    public GameType type() {
        return GameType.TABU;
    }

    @Override
    public Phase phase() {
        return phase;
    }

    @Override
    public int round() {
        return turn;
    }

    @Override
    public boolean betweenRounds() {
        return phase == Phase.RESULT;
    }

    public int currentTeam() {
        return currentTeam;
    }

    public int watcherTeam() {
        return (currentTeam + 1) % teams.size();
    }

    public String explainerId() {
        List<Player> team = teams.get(currentTeam);
        return team.get(explainerTurns[currentTeam] % team.size()).id();
    }

    public String watcherId() {
        List<Player> team = teams.get(watcherTeam());
        return team.get(watcherTurns[watcherTeam()] % team.size()).id();
    }

    public int score(int team) {
        return scores[team];
    }

    public Integer winnerTeam() {
        return winnerTeam;
    }

    public Card card() {
        return card;
    }

    public Instant turnEndsAt() {
        return turnEndsAt;
    }

    /** Der Erklärer (oder der Host, falls der Erklärer offline ist) startet die Uhr. */
    void startTurn(String requesterId, boolean requesterIsHost, Instant now) {
        if (phase != Phase.TURN_READY) {
            throw new GameException("Gerade kann kein Zug starten.");
        }
        if (!requesterIsHost && !requesterId.equals(explainerId())) {
            throw new GameException("Den Zug startet, wer erklärt.");
        }
        phase = Phase.TURN;
        turnEndsAt = now.plus(Duration.ofSeconds(options.turnSeconds()));
        drawCard();
    }

    void correct(String requesterId) {
        requireRunning(requesterId, explainerId(), "Nur wer erklärt, kann „Richtig“ drücken.");
        score(currentTeam, Outcome.CORRECT);
    }

    void skip(String requesterId) {
        requireRunning(requesterId, explainerId(), "Nur wer erklärt, kann überspringen.");
        discard(Outcome.SKIPPED);
    }

    void buzz(String requesterId) {
        requireRunning(requesterId, watcherId(), "Nur der Aufpasser hat den Buzzer.");
        discard(Outcome.BUZZED);
    }

    /** Überspringen und Buzzer: Die Karte ist weg, aber niemand bekommt einen Punkt. */
    private void discard(Outcome outcome) {
        turnResults.add(new CardResult(card.word(), outcome, null));
        drawCard();
    }

    /** Beendet den Zug, wenn die Zeit um ist. Gibt {@code true} zurück, wenn sich dadurch etwas geändert hat. */
    boolean expireTurn(Instant now) {
        if (phase != Phase.TURN || now.isBefore(turnEndsAt)) {
            return false;
        }
        lastTurn = List.copyOf(turnResults);
        turnResults.clear();
        explainerTurns[currentTeam]++;
        watcherTurns[watcherTeam()]++;
        currentTeam = (currentTeam + 1) % teams.size();
        turn++;
        phase = Phase.TURN_READY;
        turnEndsAt = null;
        card = null;
        return true;
    }

    RoomView.TabuView viewFor(String playerId, Instant now) {
        List<RoomView.TabuTeam> teamViews = new ArrayList<>();
        Integer yourTeam = null;
        for (int i = 0; i < teams.size(); i++) {
            List<String> ids = teams.get(i).stream().map(Player::id).toList();
            if (ids.contains(playerId)) {
                yourTeam = i;
            }
            teamViews.add(new RoomView.TabuTeam(TEAM_NAMES.get(i), ids, scores[i]));
        }

        boolean seesCard = playerId.equals(explainerId()) || playerId.equals(watcherId());
        RoomView.TabuCard cardView = seesCard && card != null
                ? new RoomView.TabuCard(card.word(), card.forbidden())
                : null;
        long remainingMs = phase == Phase.TURN ? Math.max(0, Duration.between(now, turnEndsAt).toMillis()) : 0;

        return new RoomView.TabuView(
                teamViews, currentTeam, watcherTeam(), explainerId(), watcherId(), yourTeam,
                remainingMs, options.turnSeconds(), options.targetScore(), cardView,
                List.copyOf(turnResults), lastTurn, winnerTeam);
    }

    private void requireRunning(String requesterId, String allowedId, String notAllowed) {
        if (phase != Phase.TURN) {
            throw new GameException("Gerade läuft kein Zug.");
        }
        if (!requesterId.equals(allowedId)) {
            throw new GameException(notAllowed);
        }
    }

    private void score(int team, Outcome outcome) {
        scores[team]++;
        turnResults.add(new CardResult(card.word(), outcome, team));
        if (scores[team] >= options.targetScore()) {
            winnerTeam = team;
            lastTurn = List.copyOf(turnResults);
            turnResults.clear();
            phase = Phase.RESULT;
            turnEndsAt = null;
            card = null;
            return;
        }
        drawCard();
    }

    /** Neu gemischt wird erst, wenn alle Karten einmal dran waren. */
    private void drawCard() {
        if (deck.isEmpty()) {
            deck.addAll(TabuCards.all());
            Shuffle.inPlace(deck, random);
        }
        card = deck.removeLast();
    }
}
