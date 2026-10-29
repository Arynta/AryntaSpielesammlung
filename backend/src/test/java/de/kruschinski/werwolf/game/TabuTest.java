
package de.kruschinski.werwolf.game;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TabuTest {

    private final MutableClock clock = new MutableClock(Instant.parse("2026-10-29T18:00:00Z"));

    private Room lobby(String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
            if (room.players().size() == 1) {
                room.setPlayerLimit("p1", Room.MAX_PLAYERS);
            }
        }
        room.selectGame("p1", GameType.TABU);
        return room;
    }

    private static void allReady(Room room) {
        room.players().forEach(p -> room.setReady(p.id(), true));
    }

    private Room started(int targetScore, String... names) {
        Room room = lobby(names);
        room.configureTabu("p1", 60, true, 2, targetScore);
        allReady(room);
        room.start("p1", new Random(5));
        return room;
    }

    private static TabuGame game(Room room) {
        return (TabuGame) room.game();
    }

    private Room runningTurn(String... names) {
        Room room = started(30, names);
        room.startTurn(game(room).explainerId());
        return room;
    }

    // ---- Lobby ---------------------------------------------------------

    @Test
    void standardEinstellungen() {
        RoomView.TabuSettings settings = lobby("A").viewFor("p1").tabuSettings();
        assertEquals(60, settings.turnSeconds());
        assertTrue(settings.autoTeams());
        assertEquals(2, settings.teamCount());
        assertEquals(30, settings.targetScore());
    }

    @Test
    void jedesTeamBrauchtZweiSpieler() {
        Room room = lobby("A", "B", "C");
        allReady(room);
        assertEquals("Noch 1 Spieler, dann kann es losgehen.", room.viewFor("p1").startHint());

        Room five = lobby("A", "B", "C", "D", "E");
        five.configureTabu("p1", 60, true, 3, 30);
        allReady(five);
        assertEquals("Für 3 Teams braucht es mindestens 6 Spieler.", five.viewFor("p1").startHint());
    }

    @Test
    void einstellungenHabenGrenzen() {
        Room room = lobby("A", "B");
        assertThrows(GameException.class, () -> room.configureTabu("p1", 20, true, 2, 30));
        assertThrows(GameException.class, () -> room.configureTabu("p1", 60, true, 5, 30));
        assertThrows(GameException.class, () -> room.configureTabu("p1", 60, true, 2, 5));
        assertThrows(GameException.class, () -> room.configureTabu("p2", 60, true, 2, 30));
    }

    @Test
    void automatischeTeamsSindGleichGross() {
        Room room = started(30, "A", "B", "C", "D", "E");
        List<Integer> sizes = room.viewFor("p1").tabu().teams().stream().map(t -> t.playerIds().size()).toList();
        assertEquals(List.of(3, 2), sizes);
    }

    @Test
    void selbstGewaehlteTeams() {
        Room room = lobby("A", "B", "C", "D");
        room.configureTabu("p1", 60, false, 2, 30);
        allReady(room);
        assertEquals("4 Spieler haben noch kein Team gewählt.", room.viewFor("p1").startHint());

        room.chooseTeam("p1", null, 0);
        room.chooseTeam("p2", null, 0);
        room.chooseTeam("p3", null, 0);
        room.chooseTeam("p1", "p4", 0);
        assertEquals("Jedes Team braucht mindestens 2 Spieler.", room.viewFor("p1").startHint());

        room.chooseTeam("p3", null, 1);
        room.chooseTeam("p1", "p4", 1);
        assertNull(room.viewFor("p1").startHint());
        assertEquals(List.of(List.of("p1", "p2"), List.of("p3", "p4")), room.viewFor("p2").tabuSettings().teams());

        room.start("p1", new Random(1));
        List<List<String>> teams = room.viewFor("p1").tabu().teams().stream().map(RoomView.TabuTeam::playerIds).toList();
        assertEquals(List.of(List.of("p1", "p2"), List.of("p3", "p4")), teams);
    }

    @Test
    void nurDerHostVerschiebtAndere() {
        Room room = lobby("A", "B", "C", "D");
        room.configureTabu("p1", 60, false, 2, 30);
        assertThrows(GameException.class, () -> room.chooseTeam("p2", "p3", 0));
        assertThrows(GameException.class, () -> room.chooseTeam("p2", null, 2));
    }

    @Test
    void wenigerTeamsLoeschtUngueltigeWahl() {
        Room room = lobby("A", "B", "C", "D", "E", "F");
        room.configureTabu("p1", 60, false, 3, 30);
        room.chooseTeam("p2", null, 2);
        room.configureTabu("p1", 60, false, 2, 30);
        assertEquals(List.of(List.of(), List.of()), room.viewFor("p1").tabuSettings().teams());
    }

    // ---- Zug -----------------------------------------------------------

    @Test
    void nurDerErklaererStartetDenZug() {
        Room room = started(30, "A", "B", "C", "D");
        TabuGame game = game(room);
        assertEquals(Phase.TURN_READY, room.phase());
        String someoneElse = room.players().stream().map(Player::id)
                .filter(id -> !id.equals(game.explainerId()) && !id.equals("p1"))
                .findFirst().orElseThrow();
        assertThrows(GameException.class, () -> room.startTurn(someoneElse));

        room.startTurn(game.explainerId());
        assertEquals(Phase.TURN, room.phase());
        assertEquals(60_000, room.viewFor("p1").tabu().remainingMs());
        clock.advance(Duration.ofSeconds(45));
        assertEquals(15_000, room.viewFor("p1").tabu().remainingMs());
    }

    @Test
    void erklaererUndAufpasserSindAusVerschiedenenTeams() {
        Room room = started(30, "A", "B", "C", "D", "E", "F");
        TabuGame game = game(room);
        RoomView.TabuView view = room.viewFor("p1").tabu();
        assertTrue(view.teams().get(game.currentTeam()).playerIds().contains(game.explainerId()));
        assertTrue(view.teams().get(game.watcherTeam()).playerIds().contains(game.watcherId()));
        assertNotEquals(game.currentTeam(), game.watcherTeam());
    }

    @Test
    void karteSehenNurErklaererUndAufpasser() {
        Room room = runningTurn("A", "B", "C", "D", "E", "F");
        TabuGame game = game(room);
        for (Player p : room.players()) {
            RoomView.TabuCard card = room.viewFor(p.id()).tabu().card();
            boolean allowed = p.id().equals(game.explainerId()) || p.id().equals(game.watcherId());
            assertEquals(allowed, card != null, p.name());
            if (allowed) {
                assertEquals(5, card.forbidden().size());
            }
        }
    }

    @Test
    void richtigGibtDemEigenenTeamEinenPunkt() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        String firstWord = game.card().word();
        room.wordCorrect(game.explainerId());

        assertEquals(1, game.score(game.currentTeam()));
        assertEquals(0, game.score(game.watcherTeam()));
        assertNotEquals(firstWord, game.card().word());
        RoomView.TabuView view = room.viewFor("p1").tabu();
        assertEquals(List.of(new TabuGame.CardResult(firstWord, TabuGame.Outcome.CORRECT, game.currentTeam())),
                view.turnResults());
    }

    @Test
    void ueberspringenZiehtNeueKarteOhnePunkt() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        String firstWord = game.card().word();
        room.wordSkip(game.explainerId());
        assertNotEquals(firstWord, game.card().word());
        assertEquals(0, game.score(game.currentTeam()));
        assertEquals(0, game.score(game.watcherTeam()));
        assertEquals(List.of(new TabuGame.CardResult(firstWord, TabuGame.Outcome.SKIPPED, null)),
                room.viewFor("p1").tabu().turnResults());
    }

    @Test
    void buzzerZiehtNeueKarteOhnePunkt() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        String firstWord = game.card().word();
        room.buzz(game.watcherId());
        assertNotEquals(firstWord, game.card().word());
        assertEquals(0, game.score(game.currentTeam()));
        assertEquals(0, game.score(game.watcherTeam()));
        assertEquals(List.of(new TabuGame.CardResult(firstWord, TabuGame.Outcome.BUZZED, null)),
                room.viewFor("p1").tabu().turnResults());
    }

    @Test
    void nurDerAufpasserHatDenBuzzer() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        assertThrows(GameException.class, () -> room.buzz(game.explainerId()));
        assertThrows(GameException.class, () -> room.wordCorrect(game.watcherId()));
    }

    @Test
    void nachAblaufDerZeitIstDasNaechsteTeamDran() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        room.wordCorrect(game.explainerId());
        assertFalse(room.expireTabuTurn());

        clock.advance(Duration.ofSeconds(60));
        assertTrue(room.expireTabuTurn());
        assertEquals(Phase.TURN_READY, room.phase());
        assertEquals(1, game.currentTeam());
        assertEquals(0, game.watcherTeam());
        assertNull(game.card());
        RoomView.TabuView view = room.viewFor("p1").tabu();
        assertEquals(1, view.lastTurn().size());
        assertTrue(view.turnResults().isEmpty());
    }

    @Test
    void zuSpaetGedruecktZaehltNicht() {
        Room room = runningTurn("A", "B", "C", "D");
        TabuGame game = game(room);
        String explainer = game.explainerId();
        int team = game.currentTeam();
        clock.advance(Duration.ofSeconds(61));
        room.wordCorrect(explainer);
        assertEquals(0, game.score(team));
        assertEquals(Phase.TURN_READY, room.phase());
    }

    @Test
    void erklaererUndAufpasserWechselnReihum() {
        Room room = started(30, "A", "B", "C", "D", "E", "F");
        TabuGame game = game(room);
        Set<String> explainersOfTeam0 = new HashSet<>();
        Set<String> watchersOfTeam1 = new HashSet<>();
        for (int i = 0; i < 6; i++) {
            if (game.currentTeam() == 0) {
                explainersOfTeam0.add(game.explainerId());
                watchersOfTeam1.add(game.watcherId());
            }
            room.startTurn(game.explainerId());
            clock.advance(Duration.ofSeconds(60));
            room.expireTabuTurn();
        }
        assertEquals(3, explainersOfTeam0.size(), "Jeder in Team 0 hat einmal erklärt");
        assertEquals(3, watchersOfTeam1.size(), "Jeder in Team 1 hat einmal aufgepasst");
    }

    @Test
    void hostKannDenZugStartenWennDerErklaererOfflineIst() {
        Room room = started(30, "A", "B", "C", "D");
        room.startTurn("p1");
        assertEquals(Phase.TURN, room.phase());
    }

    // ---- Spielende -----------------------------------------------------

    @Test
    void sieg() {
        Room room = started(10, "A", "B", "C", "D");
        TabuGame game = game(room);
        room.startTurn(game.explainerId());
        int team = game.currentTeam();
        for (int i = 0; i < 10; i++) {
            room.wordCorrect(game.explainerId());
        }
        assertEquals(Phase.RESULT, room.phase());
        assertEquals(team, game.winnerTeam());
        RoomView.TabuView view = room.viewFor("p2").tabu();
        assertEquals(team, view.winnerTeam());
        assertEquals(10, view.lastTurn().size());
        assertThrows(GameException.class, () -> room.wordCorrect(game.explainerId()));
    }

    @Test
    void nochmalStartetEinNeuesSpiel() {
        Room room = started(10, "A", "B", "C", "D");
        room.startTurn(game(room).explainerId());
        for (int i = 0; i < 10; i++) {
            room.wordCorrect(game(room).explainerId());
        }
        assertThrows(GameException.class, () -> room.nextRound("p1", new Random(2)));
        allReady(room);
        room.nextRound("p1", new Random(2));
        assertEquals(Phase.TURN_READY, room.phase());
        assertNull(game(room).winnerTeam());
        assertEquals(0, game(room).score(0));
    }

    // ---- Karten --------------------------------------------------------

    @Test
    void kartenSindVollstaendig() {
        List<TabuCards.Card> cards = TabuCards.all();
        assertTrue(cards.size() >= 150);
        assertEquals(cards.size(), cards.stream().map(TabuCards.Card::word).distinct().count(), "Keine doppelten Begriffe");
        for (TabuCards.Card card : cards) {
            assertNotNull(card.word());
            assertEquals(5, card.forbidden().size(), card.word());
        }
    }

    @Test
    void keineKarteKommtDoppeltBisAlleDranWaren() {
        Room room = started(100, "A", "B", "C", "D");
        TabuGame game = game(room);
        room.startTurn(game.explainerId());
        Set<String> seen = new HashSet<>();
        // Abwechselnd richtig und überspringen, damit keiner die 100 Punkte erreicht
        for (int i = 0; i < 150; i++) {
            assertTrue(seen.add(game.card().word()), "Doppelt: " + game.card().word());
            if (i % 2 == 0) {
                room.wordCorrect(game.explainerId());
            } else {
                room.wordSkip(game.explainerId());
            }
        }
    }
}
