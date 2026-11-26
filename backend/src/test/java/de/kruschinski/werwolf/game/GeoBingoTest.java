package de.kruschinski.werwolf.game;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class GeoBingoTest {

    private static final GeoBingoGame.Spot SPOT = new GeoBingoGame.Spot("123456", 0.5, 0.5, 0);

    private final MutableClock clock = new MutableClock(Instant.parse("2026-11-26T18:00:00Z"));

    /** p1 (Anna) ist Host und spielt mit, dazu p2 und p3. */
    private Room started() {
        Room room = new Room("TEST", clock);
        List.of("Anna", "Ben", "Cem").forEach(room::addPlayer);
        room.selectGame("p1", GameType.GEO_BINGO);
        room.players().forEach(p -> room.setReady(p.id(), true));
        room.start("p1", new Random(1));
        return room;
    }

    private static RoomView.GeoBingoView view(Room room, String playerId) {
        return room.viewFor(playerId).geoBingo();
    }

    private static List<Integer> fieldsOf(Room room, String playerId) {
        return view(room, "p1").scores().stream().filter(s -> s.playerId().equals(playerId)).findFirst().orElseThrow().fields();
    }

    /** p1 meldet das Feld, p2 und p3 stimmen zu. */
    private static void confirm(Room room, int field) {
        room.claimGeoBingoField("p1", field, SPOT);
        String claimId = view(room, "p1").claims().getFirst().id();
        room.voteGeoBingo("p2", claimId, true);
        room.voteGeoBingo("p3", claimId, true);
    }

    @Test
    void startetMitNeunMotivenUndOrt() {
        Room room = started();
        RoomView.GeoBingoView view = view(room, "p2");

        assertEquals(Phase.GEO_BINGO, room.phase());
        assertEquals(9, view.board().size());
        assertEquals(9, view.board().stream().distinct().count());
        assertEquals(Duration.ofMinutes(10).toMillis(), view.remainingMs());
    }

    @Test
    void zustimmungAllerMarkiertDasFeld() {
        Room room = started();
        confirm(room, 4);

        assertEquals(List.of(4), fieldsOf(room, "p1"));
        assertTrue(view(room, "p1").claims().isEmpty());
        assertEquals(new GeoBingoGame.Decision("p1", 4, true), view(room, "p1").decisions().getFirst());
    }

    @Test
    void mehrheitDagegenLehntAb() {
        Room room = started();
        room.claimGeoBingoField("p1", 0, SPOT);
        String claimId = view(room, "p1").claims().getFirst().id();
        room.voteGeoBingo("p2", claimId, false);
        room.voteGeoBingo("p3", claimId, false);

        assertTrue(fieldsOf(room, "p1").isEmpty());
        assertEquals(new GeoBingoGame.Decision("p1", 0, false), view(room, "p1").decisions().getFirst());
    }

    @Test
    void gleichstandZaehltAlsTreffer() {
        Room room = started();
        room.claimGeoBingoField("p1", 0, SPOT);
        String claimId = view(room, "p1").claims().getFirst().id();
        room.voteGeoBingo("p2", claimId, true);
        room.voteGeoBingo("p3", claimId, false);

        assertEquals(List.of(0), fieldsOf(room, "p1"));
    }

    @Test
    void andereSehenDieGemeldeteAnsichtUndIhreStimme() {
        Room room = started();
        room.claimGeoBingoField("p1", 2, new GeoBingoGame.Spot("987", 0.25, 0.75, 1.5));
        RoomView.GeoBingoClaim claim = view(room, "p2").claims().getFirst();

        assertEquals("987", claim.imageId());
        assertEquals(0.25, claim.x());
        assertEquals(1.5, claim.zoom());
        assertNull(claim.yourVote());

        room.voteGeoBingo("p2", claim.id(), true);
        assertEquals(true, view(room, "p2").claims().getFirst().yourVote());
        assertEquals(List.of("p2"), view(room, "p3").claims().getFirst().votedIds());
    }

    @Test
    void nachAblaufDerAbstimmzeitZaehlenDieAbgegebenenStimmen() {
        Room room = started();
        room.claimGeoBingoField("p1", 1, SPOT);
        room.voteGeoBingo("p2", view(room, "p1").claims().getFirst().id(), false);

        clock.advance(GeoBingoGame.VOTE_TIME);
        assertTrue(room.expireGeoBingo());
        assertTrue(fieldsOf(room, "p1").isEmpty());
    }

    @Test
    void offlineSpielerBlockierenDieAbstimmungNicht() {
        Room room = started();
        room.setConnected("p3", false);
        room.claimGeoBingoField("p1", 1, SPOT);
        room.voteGeoBingo("p2", view(room, "p1").claims().getFirst().id(), true);

        assertEquals(List.of(1), fieldsOf(room, "p1"));
    }

    @Test
    void volleReiheGewinnt() {
        Room room = started();
        confirm(room, 2);
        confirm(room, 4);
        confirm(room, 6);

        RoomView.GeoBingoView view = view(room, "p2");
        assertEquals(Phase.RESULT, room.phase());
        assertEquals(List.of("p1"), view.winnerIds());
        assertEquals(List.of(2, 4, 6), view.winningLine());
    }

    @Test
    void nachAblaufDerSpielzeitGewinntWerAmMeistenHat() {
        Room room = started();
        confirm(room, 0);
        clock.advance(Duration.ofMinutes(10));

        assertTrue(room.expireGeoBingo());
        assertEquals(Phase.RESULT, room.phase());
        assertEquals(List.of("p1"), view(room, "p1").winnerIds());
        assertNull(view(room, "p1").winningLine());
        assertThrows(GameException.class, () -> room.claimGeoBingoField("p2", 0, SPOT));
    }

    @Test
    void ohneTrefferGewinntNiemand() {
        Room room = started();
        clock.advance(Duration.ofMinutes(10));
        room.expireGeoBingo();

        assertTrue(view(room, "p1").winnerIds().isEmpty());
    }

    @Test
    void nurEineOffeneMeldungProSpieler() {
        Room room = started();
        room.claimGeoBingoField("p1", 0, SPOT);
        assertThrows(GameException.class, () -> room.claimGeoBingoField("p1", 1, SPOT));
    }

    @Test
    void ueberDenEigenenFundStimmtManNichtAb() {
        Room room = started();
        room.claimGeoBingoField("p1", 0, SPOT);
        String claimId = view(room, "p1").claims().getFirst().id();
        assertThrows(GameException.class, () -> room.voteGeoBingo("p1", claimId, true));
    }

    @Test
    void ungueltigeMeldungenWerdenAbgelehnt() {
        Room room = started();
        assertThrows(GameException.class, () -> room.claimGeoBingoField("p1", 9, SPOT));
        assertThrows(GameException.class, () -> new GeoBingoGame.Spot("abc", 0.5, 0.5, 0));
        assertThrows(GameException.class, () -> new GeoBingoGame.Spot("1", 1.5, 0.5, 0));
        assertThrows(GameException.class, () -> new GeoBingoGame.Spot("1", Double.NaN, 0.5, 0));
        confirm(room, 0);
        assertThrows(GameException.class, () -> room.claimGeoBingoField("p1", 0, SPOT));
    }

    @Test
    void spielzeitIstEinstellbar() {
        Room room = new Room("TEST", clock);
        room.addPlayer("Anna");
        room.selectGame("p1", GameType.GEO_BINGO);
        room.configureGeoBingo("p1", 5);

        assertEquals(5, room.viewFor("p1").geoBingoSettings().minutes());
        assertThrows(GameException.class, () -> room.configureGeoBingo("p1", 4));
        assertThrows(GameException.class, () -> room.configureGeoBingo("p1", 31));
    }

    @Test
    void neueRundeHatNeuenOrt() {
        Room room = started();
        String firstPlace = view(room, "p1").place();
        clock.advance(Duration.ofMinutes(10));
        room.expireGeoBingo();
        room.players().forEach(p -> room.setReady(p.id(), true));
        room.nextRound("p1", new Random(1));

        assertEquals(2, room.round());
        assertNotEquals(firstPlace, view(room, "p1").place());
    }
}
