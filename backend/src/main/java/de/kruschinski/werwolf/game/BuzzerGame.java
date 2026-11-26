package de.kruschinski.werwolf.game;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Buzzer: Die Spieler drücken, die Spielleitung sieht die Reihenfolge und gibt wieder frei.
 * Mit Lock-out ist nach dem ersten Druck für alle anderen Schluss, ohne darf jeder einmal drücken.
 * Die Zeit misst der Server, weil man den Uhren der Handys nicht trauen kann.
 * Nicht threadsicher, {@link Room} synchronisiert.
 */
public final class BuzzerGame implements Game {

    private record Press(String playerId, Instant at) {
    }

    private final List<String> participantIds;
    private final boolean lockout;
    private final List<Press> presses = new ArrayList<>();
    /** Zählt die Freigaben, damit alle sehen, bei welcher Frage man ist. */
    private int question = 1;

    BuzzerGame(List<Player> participants, boolean lockout) {
        this.participantIds = participants.stream().map(Player::id).toList();
        this.lockout = lockout;
    }

    @Override
    public GameType type() {
        return GameType.BUZZER;
    }

    @Override
    public Phase phase() {
        return Phase.BUZZER;
    }

    @Override
    public int round() {
        return question;
    }

    @Override
    public boolean betweenRounds() {
        return false;
    }

    /** Wer zu spät oder doppelt drückt, wird ignoriert: Das ist beim Buzzern normal und kein Fehler. */
    void press(String playerId, Instant now) {
        if (!participantIds.contains(playerId)) {
            throw new GameException("error.buzzer.gameMasterHasNone");
        }
        if (canPress(playerId)) {
            presses.add(new Press(playerId, now));
        }
    }

    void release() {
        presses.clear();
        question++;
    }

    RoomView.BuzzerView viewFor(String playerId, boolean isHost) {
        Instant first = presses.isEmpty() ? null : presses.getFirst().at();
        List<RoomView.BuzzerPress> order = new ArrayList<>();
        Integer yourRank = null;
        for (int i = 0; i < presses.size(); i++) {
            Press press = presses.get(i);
            if (press.playerId().equals(playerId)) {
                yourRank = i + 1;
            }
            order.add(new RoomView.BuzzerPress(press.playerId(), i + 1, Duration.between(first, press.at()).toMillis()));
        }
        return new RoomView.BuzzerView(lockout, isHost ? order : List.of(), yourRank, canPress(playerId));
    }

    private boolean canPress(String playerId) {
        boolean pressed = presses.stream().anyMatch(p -> p.playerId().equals(playerId));
        boolean lockedOut = lockout && !presses.isEmpty();
        return participantIds.contains(playerId) && !pressed && !lockedOut;
    }
}
