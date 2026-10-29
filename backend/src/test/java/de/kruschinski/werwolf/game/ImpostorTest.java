package de.kruschinski.werwolf.game;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
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

class ImpostorTest {

    private final Clock clock = Clock.fixed(Instant.parse("2026-10-29T18:00:00Z"), ZoneOffset.UTC);

    private Room lobby(String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
        }
        room.selectGame("p1", GameType.IMPOSTOR);
        return room;
    }

    private static void allReady(Room room) {
        room.players().forEach(p -> room.setReady(p.id(), true));
    }

    private Room started(String... names) {
        Room room = lobby(names);
        allReady(room);
        room.start("p1", new Random(3));
        return room;
    }

    private static ImpostorGame game(Room room) {
        return (ImpostorGame) room.game();
    }

    /** Erster Mitspieler, der weder der Impostor noch in {@code except} ist. */
    private static String crewMember(Room room, String... except) {
        Set<String> skip = Set.of(except);
        return room.players().stream()
                .map(Player::id)
                .filter(id -> !id.equals(game(room).impostorId()) && !skip.contains(id))
                .findFirst()
                .orElseThrow();
    }

    /** Vier Spieler in der Abstimmung: der Impostor und die Mitspieler a, b, c. */
    private record Four(Room room, String impostor, String a, String b, String c) {
    }

    private Four votingWithFour() {
        Room room = started("A", "B", "C", "D");
        room.startVoting("p1");
        String a = crewMember(room);
        String b = crewMember(room, a);
        String c = crewMember(room, a, b);
        return new Four(room, game(room).impostorId(), a, b, c);
    }

    private Room finishedRound() {
        Room room = started("A", "B", "C");
        room.startVoting("p1");
        String impostor = game(room).impostorId();
        for (Player p : room.players()) {
            room.vote(p.id(), p.id().equals(impostor) ? crewMember(room) : impostor);
        }
        assertEquals(Phase.RESULT, room.phase());
        return room;
    }

    // ---- Start ---------------------------------------------------------

    @Test
    void dreiSpielerReichen() {
        Room room = started("A", "B", "C");
        assertEquals(Phase.WORD, room.phase());
        assertEquals(1, room.round());
    }

    @Test
    void zweiSpielerReichenNicht() {
        Room room = lobby("A", "B");
        allReady(room);
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
    }

    @Test
    void genauEinImpostorUndAlleAnderenKennenDasWort() {
        Room room = started("A", "B", "C", "D", "E");

        int impostors = 0;
        for (Player p : room.players()) {
            RoomView.ImpostorView view = room.viewFor(p.id()).impostor();
            if (view.part() == ImpostorGame.Part.IMPOSTOR) {
                impostors++;
                assertNull(view.word(), "Der Impostor darf das Wort nicht sehen");
            } else {
                assertEquals(ImpostorGame.Part.CREW, view.part());
                assertEquals(game(room).secret().word(), view.word());
            }
        }
        assertEquals(1, impostors);
    }

    @Test
    void niemandErfaehrtVorDerAufloesungWerDerImpostorIst() {
        Room room = started("A", "B", "C", "D");
        room.startVoting("p1");
        for (Player p : room.players()) {
            assertNull(room.viewFor(p.id()).impostor().result());
        }
    }

    @Test
    void impostorSiehtKategorieNurWennEingeschaltet() {
        Room mitKategorie = started("A", "B", "C");
        String impostor = game(mitKategorie).impostorId();
        assertNotNull(mitKategorie.viewFor(impostor).impostor().category());

        Room ohneKategorie = lobby("A", "B", "C");
        ohneKategorie.configureImpostor("p1", false, "");
        allReady(ohneKategorie);
        ohneKategorie.start("p1", new Random(3));
        String impostor2 = game(ohneKategorie).impostorId();
        assertNull(ohneKategorie.viewFor(impostor2).impostor().category());
    }

    // ---- Eigenes Wort --------------------------------------------------

    @Test
    void eigenesWortSiehtNurDerHost() {
        Room room = lobby("A", "B", "C", "D");
        room.configureImpostor("p1", true, "  Leuchtturm ");

        assertEquals("Leuchtturm", room.viewFor("p1").impostorSettings().customWord());
        assertNull(room.viewFor("p2").impostorSettings().customWord());
        assertTrue(room.viewFor("p2").impostorSettings().customWordSet());
    }

    @Test
    void mitEigenemWortSpieltDerHostNichtMit() {
        Room room = lobby("A", "B", "C", "D");
        room.configureImpostor("p1", true, "Leuchtturm");
        allReady(room);
        room.start("p1", new Random(3));

        RoomView.ImpostorView hostView = room.viewFor("p1").impostor();
        assertEquals(ImpostorGame.Part.GAME_MASTER, hostView.part());
        assertEquals("Leuchtturm", hostView.word());
        assertFalse(hostView.participantIds().contains("p1"));
        assertNotEquals("p1", game(room).impostorId());
    }

    @Test
    void mitEigenemWortBrauchtEsDreiSpielerOhneHost() {
        Room room = lobby("A", "B", "C");
        room.configureImpostor("p1", true, "Leuchtturm");
        allReady(room);
        assertEquals("Noch 1 Spieler (ohne Spielleitung), dann kann es losgehen.", room.viewFor("p1").startHint());
        assertThrows(GameException.class, () -> room.start("p1", new Random(3)));
    }

    @Test
    void eigenesWortGiltNurEineRunde() {
        Room room = lobby("A", "B", "C", "D");
        room.configureImpostor("p1", true, "Leuchtturm");
        allReady(room);
        room.start("p1", new Random(3));
        assertNull(room.viewFor("p1").impostorSettings().customWord());
    }

    @Test
    void zuLangesWortWirdAbgelehnt() {
        Room room = lobby("A", "B", "C");
        assertThrows(GameException.class,
                () -> room.configureImpostor("p1", true, "x".repeat(Room.MAX_WORD_LENGTH + 1)));
    }

    @Test
    void einstellungAendernSetztBereitZurueck() {
        Room room = lobby("A", "B", "C");
        allReady(room);
        room.configureImpostor("p1", false, "");
        room.players().forEach(p -> assertFalse(p.ready()));
    }

    // ---- Abstimmung ----------------------------------------------------

    @Test
    void abstimmenGehtErstNachStartDerAbstimmung() {
        Room room = started("A", "B", "C");
        assertThrows(GameException.class, () -> room.vote("p1", "p2"));
    }

    @Test
    void nichtFuerSichSelbstStimmen() {
        Room room = started("A", "B", "C");
        room.startVoting("p1");
        assertThrows(GameException.class, () -> room.vote("p1", "p1"));
    }

    @Test
    void mehrheitFindetDenImpostor() {
        Room room = finishedRound();
        RoomView.ImpostorResult result = room.viewFor("p2").impostor().result();
        assertTrue(result.impostorCaught());
        assertEquals(game(room).impostorId(), result.impostorId());
        assertEquals(game(room).secret().word(), result.word());
    }

    @Test
    void knappeMehrheitReicht() {
        Four f = votingWithFour();
        f.room().vote(f.b(), f.impostor());
        f.room().vote(f.c(), f.impostor());
        f.room().vote(f.impostor(), f.a());
        f.room().vote(f.a(), f.b());
        // Impostor 2, a 1, b 1
        assertEquals(Phase.RESULT, f.room().phase());
        assertTrue(game(f.room()).impostorCaught());
    }

    @Test
    void beiGleichstandGewinntDerImpostor() {
        Four f = votingWithFour();
        f.room().vote(f.c(), f.impostor());
        f.room().vote(f.a(), f.impostor());
        f.room().vote(f.impostor(), f.a());
        f.room().vote(f.b(), f.a());
        // Impostor 2, a 2
        assertEquals(Phase.RESULT, f.room().phase());
        assertFalse(game(f.room()).impostorCaught());
    }

    @Test
    void mehrheitLiegtFalsch() {
        Four f = votingWithFour();
        f.room().vote(f.a(), f.impostor());
        f.room().vote(f.impostor(), f.b());
        f.room().vote(f.c(), f.b());
        f.room().vote(f.b(), f.c());
        // Impostor 1, b 2, c 1
        assertEquals(Phase.RESULT, f.room().phase());
        assertFalse(game(f.room()).impostorCaught());
    }

    @Test
    void stimmeKannGeaendertWerden() {
        Four f = votingWithFour();
        f.room().vote(f.a(), f.b());
        f.room().vote(f.a(), f.impostor());
        assertEquals(f.impostor(), f.room().viewFor(f.a()).impostor().yourVote());
        assertEquals(Phase.VOTING, f.room().phase());
    }

    @Test
    void offlineSpielerBlockierenDieAbstimmungNicht() {
        Four f = votingWithFour();
        f.room().vote(f.a(), f.impostor());
        f.room().vote(f.b(), f.impostor());
        f.room().vote(f.impostor(), f.a());
        assertEquals(Phase.VOTING, f.room().phase());

        f.room().setConnected(f.c(), false);
        assertEquals(Phase.RESULT, f.room().phase());
    }

    @Test
    void ansichtZeigtWerSchonAbgestimmtHatAberNichtWofuer() {
        Room room = started("A", "B", "C");
        room.startVoting("p1");
        String voter = crewMember(room);
        String target = game(room).impostorId();
        room.vote(voter, target);

        RoomView.ImpostorView other = room.viewFor(target).impostor();
        assertEquals(List.of(voter), other.votedIds());
        assertNull(other.yourVote());
        assertEquals(target, room.viewFor(voter).impostor().yourVote());
    }

    // ---- Nächste Runde -------------------------------------------------

    @Test
    void naechsteRundeErstWennAlleBereit() {
        Room room = finishedRound();
        assertThrows(GameException.class, () -> room.nextRound("p1", new Random(4)));

        allReady(room);
        String oldWord = game(room).secret().word();
        room.nextRound("p1", new Random(4));

        assertEquals(Phase.WORD, room.phase());
        assertEquals(2, room.round());
        assertNotEquals(oldWord, game(room).secret().word(), "Ein Wort soll nicht direkt wiederkommen");
    }

    @Test
    void bereitGehtNurZwischenDenRunden() {
        Room room = started("A", "B", "C");
        assertThrows(GameException.class, () -> room.setReady("p2", true));
    }

    @Test
    void zurueckInDieLobbyNachDerAufloesung() {
        Room room = finishedRound();
        room.backToLobby("p1");
        assertEquals(Phase.LOBBY, room.phase());
        assertEquals(GameType.IMPOSTOR, room.selectedGame());
    }

    @Test
    void wortlisteHatKeineDoppelten() {
        List<String> words = ImpostorWords.allWords().stream().map(ImpostorWords.SecretWord::word).toList();
        assertEquals(words.size(), Set.copyOf(words).size());
        assertTrue(words.size() >= 100);
    }
}
