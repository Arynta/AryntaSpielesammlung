package de.kruschinski.werwolf.game;

import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class NobodyIsPerfectTest {

    private final MutableClock clock = new MutableClock(Instant.parse("2026-10-30T18:00:00Z"));

    private Room started(int questionCount, String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
        }
        room.selectGame("p1", GameType.NOBODY_IS_PERFECT);
        room.configureNobodyIsPerfect("p1", questionCount);
        room.players().forEach(p -> room.setReady(p.id(), true));
        room.start("p1", new Random(3));
        return room;
    }

    private static NobodyIsPerfectGame game(Room room) {
        return (NobodyIsPerfectGame) room.game();
    }

    private static String choiceOf(NobodyIsPerfectGame game, String authorId) {
        return game.choices().stream().filter(c -> java.util.Objects.equals(c.authorId(), authorId)).findFirst().orElseThrow().id();
    }

    private static String truth(NobodyIsPerfectGame game) {
        return choiceOf(game, null);
    }

    /** p1, p2 und p3 schreiben je eine Antwort. */
    private static void allWrite(Room room) {
        room.submitAnswer("p1", "Lüge von Anna");
        room.submitAnswer("p2", "Lüge von Ben");
        room.submitAnswer("p3", "Lüge von Cem");
    }

    // ---- Ablauf ----------------------------------------------------------

    @Test
    void startetMitDerErstenFrage() {
        Room room = started(5, "Anna", "Ben", "Cem");
        assertEquals(Phase.WRITING, room.phase());
        assertEquals(1, room.round());
        RoomView.NobodyIsPerfectView view = room.viewFor("p1").nobodyIsPerfect();
        assertEquals(5, view.questionCount());
        assertNotNull(view.question());
        assertNull(view.answer(), "Die echte Antwort bleibt bis zur Auflösung geheim");
        assertTrue(view.choices().isEmpty());
    }

    @Test
    void gehtZumTippenWennAlleGeschriebenHaben() {
        Room room = started(5, "Anna", "Ben", "Cem");
        room.submitAnswer("p1", "Lüge von Anna");
        room.submitAnswer("p2", "Lüge von Ben");
        assertEquals(Phase.WRITING, room.phase());
        assertEquals(List.of("p1", "p2"), room.viewFor("p3").nobodyIsPerfect().answeredIds());

        room.submitAnswer("p3", "Lüge von Cem");
        assertEquals(Phase.GUESSING, room.phase());
        RoomView.NobodyIsPerfectView view = room.viewFor("p1").nobodyIsPerfect();
        assertEquals(List.of("A", "B", "C", "D"), view.choices().stream().map(RoomView.NobodyIsPerfectChoice::id).toList());
        assertTrue(view.choices().stream().anyMatch(c -> c.text().equals(game(room).question().answer())));
        assertEquals(choiceOf(game(room), "p1"), view.yourChoiceId());
        assertNull(view.answer());
    }

    @Test
    void antwortWirdBereinigtUndGeprueft() {
        Room room = started(5, "Anna", "Ben", "Cem");
        assertThrows(GameException.class, () -> room.submitAnswer("p1", "   "));
        assertThrows(GameException.class, () -> room.submitAnswer("p1", "x".repeat(NobodyIsPerfectOptions.MAX_ANSWER_LENGTH + 1)));
        room.submitAnswer("p1", "  Eine   Lüge ​ ");
        assertEquals("Eine Lüge", room.viewFor("p1").nobodyIsPerfect().yourAnswer());
        room.submitAnswer("p1", "Doch was anderes");
        assertEquals("Doch was anderes", room.viewFor("p1").nobodyIsPerfect().yourAnswer());
    }

    @Test
    void aufDieEigeneAntwortDarfManNichtTippen() {
        Room room = started(5, "Anna", "Ben", "Cem");
        allWrite(room);
        String own = choiceOf(game(room), "p1");
        assertThrows(GameException.class, () -> room.guessAnswer("p1", own));
        assertThrows(GameException.class, () -> room.guessAnswer("p1", "Z"));
    }

    @Test
    void punkteFuerRichtigeTippsUndGelungeneTaeuschungen() {
        Room room = started(5, "Anna", "Ben", "Cem");
        allWrite(room);
        NobodyIsPerfectGame game = game(room);
        room.guessAnswer("p1", truth(game));               // Anna liegt richtig: +1 Anna
        room.guessAnswer("p2", choiceOf(game, "p1"));      // Ben fällt auf Anna rein: +1 Anna
        room.guessAnswer("p3", choiceOf(game, "p1"));      // Cem auch: +1 Anna

        assertEquals(Phase.REVEAL, room.phase());
        assertEquals(3, game.score("p1"));
        assertEquals(0, game.score("p2"));
        assertEquals(0, game.score("p3"));

        RoomView.NobodyIsPerfectView view = room.viewFor("p2").nobodyIsPerfect();
        assertEquals(game.question().answer(), view.answer());
        RoomView.NobodyIsPerfectReveal annasLie = view.reveal().stream().filter(r -> "p1".equals(r.authorId())).findFirst().orElseThrow();
        assertEquals(List.of("p2", "p3"), annasLie.guesserIds());
        RoomView.NobodyIsPerfectReveal real = view.reveal().stream().filter(RoomView.NobodyIsPerfectReveal::correct).findFirst().orElseThrow();
        assertNull(real.authorId());
        assertEquals(List.of("p1"), real.guesserIds());
        assertEquals(3, view.scores().getFirst().gained());
    }

    @Test
    void naechsteFrageUndSpielende() {
        Room room = started(3, "Anna", "Ben", "Cem");
        Set<String> questions = new HashSet<>();
        for (int i = 1; i <= 3; i++) {
            assertEquals(i, room.round());
            questions.add(game(room).question().question());
            allWrite(room);
            String truth = truth(game(room));
            room.players().forEach(p -> room.guessAnswer(p.id(), truth));
            if (i < 3) {
                assertEquals(Phase.REVEAL, room.phase());
                assertFalse(game(room).betweenRounds());
                assertThrows(GameException.class, () -> room.nextQuestion("p2"), "Nur die Spielleitung");
                room.nextQuestion("p1");
                assertNull(room.viewFor("p1").nobodyIsPerfect().yourAnswer());
            }
        }
        assertEquals(Phase.RESULT, room.phase());
        assertEquals(3, questions.size(), "Keine Frage doppelt");
        assertEquals(3, game(room).score("p1"));
        assertThrows(GameException.class, () -> room.nextQuestion("p1"));

        room.players().forEach(p -> room.setReady(p.id(), true));
        room.nextRound("p1", new Random(4));
        assertEquals(Phase.WRITING, room.phase());
        assertEquals(0, game(room).score("p1"));
        assertFalse(questions.contains(game(room).question().question()), "Neues Spiel, neue Fragen");
    }

    @Test
    void offlineSpielerHaltenNichtAuf() {
        Room room = started(5, "Anna", "Ben", "Cem");
        room.submitAnswer("p1", "Lüge von Anna");
        room.submitAnswer("p2", "Lüge von Ben");
        room.setConnected("p3", false);
        assertEquals(Phase.GUESSING, room.phase());
        assertEquals(3, game(room).choices().size());

        room.guessAnswer("p1", truth(game(room)));
        room.setConnected("p3", true);
        room.guessAnswer("p2", truth(game(room)));
        assertEquals(Phase.GUESSING, room.phase(), "Cem ist wieder da und darf noch tippen");
        room.guessAnswer("p3", choiceOf(game(room), "p1"));
        assertEquals(Phase.REVEAL, room.phase());
    }

    @Test
    void spielleitungKannNichtLaengerWarten() {
        Room room = started(5, "Anna", "Ben", "Cem");
        assertThrows(GameException.class, () -> room.skipWaiting("p1"), "Ohne eine einzige Antwort geht es nicht weiter");
        room.submitAnswer("p2", "Lüge von Ben");
        assertThrows(GameException.class, () -> room.skipWaiting("p2"));
        room.skipWaiting("p1");
        assertEquals(Phase.GUESSING, room.phase());

        room.guessAnswer("p1", choiceOf(game(room), "p2"));
        room.skipWaiting("p1");
        assertEquals(Phase.REVEAL, room.phase());
        assertEquals(1, game(room).score("p2"));
    }

    @Test
    void erfinderBleibenBisZurAufloesungGeheim() {
        Room room = started(5, "Anna", "Ben", "Cem");
        allWrite(room);
        RoomView.NobodyIsPerfectView view = room.viewFor("p2").nobodyIsPerfect();
        assertTrue(view.reveal().isEmpty());
        assertNull(view.answer());
    }

    @Test
    void fragenzahlNurInGrenzen() {
        Room room = new Room("TEST", clock);
        room.addPlayer("Anna");
        assertThrows(GameException.class, () -> room.configureNobodyIsPerfect("p1", NobodyIsPerfectOptions.MIN_QUESTIONS - 1));
        assertThrows(GameException.class, () -> room.configureNobodyIsPerfect("p1", NobodyIsPerfectOptions.MAX_QUESTIONS + 1));
        room.configureNobodyIsPerfect("p1", 12);
        assertEquals(12, room.viewFor("p1").nobodyIsPerfectSettings().questionCount());
    }

    @Test
    void fragenSindVollstaendig() {
        List<NobodyIsPerfectQuestions.Question> all = NobodyIsPerfectQuestions.all();
        assertTrue(all.size() >= 60);
        assertEquals(all.size(), all.stream().map(NobodyIsPerfectQuestions.Question::question).distinct().count(), "Keine doppelten Fragen");
        for (NobodyIsPerfectQuestions.Question q : all) {
            assertFalse(q.question().isBlank());
            assertFalse(q.answer().isBlank(), q.question());
            assertTrue(q.answer().length() <= NobodyIsPerfectOptions.MAX_ANSWER_LENGTH, q.question());
        }
    }
}
