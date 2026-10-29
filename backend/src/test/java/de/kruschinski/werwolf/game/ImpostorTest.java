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

    /** Der Impostor, wenn es genau einen gibt. */
    private static String impostorOf(Room room) {
        Set<String> ids = game(room).impostorIds();
        assertEquals(1, ids.size());
        return ids.iterator().next();
    }

    /** Erster Mitspieler, der weder der Impostor noch in {@code except} ist. */
    private static String crewMember(Room room, String... except) {
        Set<String> skip = Set.of(except);
        return room.players().stream()
                .map(Player::id)
                .filter(id -> !id.equals(impostorOf(room)) && !skip.contains(id))
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
        return new Four(room, impostorOf(room), a, b, c);
    }

    private Room finishedRound() {
        Room room = started("A", "B", "C");
        room.startVoting("p1");
        String impostor = impostorOf(room);
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
        String impostor = impostorOf(mitKategorie);
        assertNotNull(mitKategorie.viewFor(impostor).impostor().category());

        Room ohneKategorie = lobby("A", "B", "C");
        ohneKategorie.configureImpostor("p1", false, "");
        allReady(ohneKategorie);
        ohneKategorie.start("p1", new Random(3));
        String impostor2 = impostorOf(ohneKategorie);
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
        assertNotEquals("p1", impostorOf(room));
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
        assertEquals(impostorOf(room), result.impostorIds().getFirst());
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
        String target = impostorOf(room);
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

    // ---- Kategorien ----------------------------------------------------

    @Test
    void anfangsSindAlleKategorienGewaehlt() {
        RoomView.ImpostorSettings settings = lobby("A").viewFor("p1").impostorSettings();
        assertEquals(ImpostorWords.categoryNames(), settings.selectedCategories());
        assertEquals(ImpostorWords.categoryNames(), settings.allCategories());
    }

    @Test
    void wortKommtNurAusGewaehltenKategorien() {
        Room room = lobby("A", "B", "C");
        room.setImpostorCategories("p1", List.of("Tiere"));
        for (int round = 1; round <= 5; round++) {
            allReady(room);
            if (round == 1) {
                room.start("p1", new Random(round));
            } else {
                room.nextRound("p1", new Random(round));
            }
            assertEquals("Tiere", game(room).secret().category());
            finishVoting(room);
        }
    }

    @Test
    void mindestensEineKategorie() {
        Room room = lobby("A");
        assertThrows(GameException.class, () -> room.setImpostorCategories("p1", List.of()));
    }

    @Test
    void unbekannteKategorieWirdAbgelehnt() {
        Room room = lobby("A");
        assertThrows(GameException.class, () -> room.setImpostorCategories("p1", List.of("Tiere", "Quatsch")));
    }

    @Test
    void nurDerHostWaehltKategorien() {
        Room room = lobby("A", "B");
        assertThrows(GameException.class, () -> room.setImpostorCategories("p2", List.of("Tiere")));
    }

    @Test
    void kategorienAendernSetztBereitZurueck() {
        Room room = lobby("A", "B", "C");
        allReady(room);
        room.setImpostorCategories("p1", List.of("Orte", "Tiere"));
        room.players().forEach(p -> assertFalse(p.ready()));
        // Reihenfolge wie in der Wortliste, egal wie sie geschickt wurde
        assertEquals(List.of("Tiere", "Orte"), room.viewFor("p1").impostorSettings().selectedCategories());
    }

    private static void finishVoting(Room room) {
        room.startVoting("p1");
        String impostor = impostorOf(room);
        for (Player p : room.players()) {
            room.vote(p.id(), p.id().equals(impostor) ? crewMember(room) : impostor);
        }
    }

    // ---- Mehrere Impostor und Startspieler -----------------------------

    private Room startedWithOptions(int impostors, boolean randomStart, int seed, String... names) {
        Room room = lobby(names);
        room.setPlayerLimit("p1", Room.MAX_PLAYERS);
        room.setImpostorOptions("p1", impostors, randomStart);
        allReady(room);
        room.start("p1", new Random(seed));
        return room;
    }

    @Test
    void mehrereImpostorKennenSichGegenseitig() {
        Room room = startedWithOptions(2, true, 3, "A", "B", "C", "D", "E", "F");
        Set<String> impostors = game(room).impostorIds();
        assertEquals(2, impostors.size());
        for (Player p : room.players()) {
            List<String> fellows = room.viewFor(p.id()).impostor().fellowImpostors();
            if (impostors.contains(p.id())) {
                assertEquals(1, fellows.size());
                assertNotEquals(p.name(), fellows.getFirst());
            } else {
                assertTrue(fellows.isEmpty(), "Die Crew erfährt nichts über die Impostor");
            }
        }
    }

    @Test
    void zweiImpostorBrauchenSechsMitspieler() {
        Room room = lobby("A", "B", "C", "D", "E");
        room.setImpostorOptions("p1", 2, true);
        allReady(room);
        assertEquals("Für 2 Impostor braucht es mindestens 6 Mitspieler.", room.viewFor("p1").startHint());
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
    }

    @Test
    void impostorAnzahlHatGrenzen() {
        Room room = lobby("A", "B", "C");
        assertThrows(GameException.class, () -> room.setImpostorOptions("p1", 0, true));
        assertThrows(GameException.class, () -> room.setImpostorOptions("p1", ImpostorOptions.MAX_IMPOSTORS + 1, true));
        assertThrows(GameException.class, () -> room.setImpostorOptions("p2", 1, true));
    }

    @Test
    void impostorOptionenSetzenBereitZurueck() {
        Room room = lobby("A", "B", "C");
        allReady(room);
        room.setImpostorOptions("p1", 1, false);
        room.players().forEach(p -> assertFalse(p.ready()));
        assertFalse(room.viewFor("p2").impostorSettings().randomStartPlayer());
    }

    @Test
    void startspielerIstNieEinImpostor() {
        for (int seed = 0; seed < 40; seed++) {
            Room room = startedWithOptions(2, true, seed, "A", "B", "C", "D", "E", "F");
            String start = game(room).startPlayerId();
            assertNotNull(start);
            assertFalse(game(room).impostorIds().contains(start));
            assertEquals(start, room.viewFor("p2").impostor().startPlayerId());
        }
    }

    @Test
    void ohneStartspielerWirdKeinerGelost() {
        Room room = startedWithOptions(1, false, 3, "A", "B", "C");
        assertNull(game(room).startPlayerId());
    }

    @Test
    void einErwischterImpostorReichtFuerDieCrew() {
        Room room = startedWithOptions(2, true, 5, "A", "B", "C", "D", "E", "F");
        room.startVoting("p1");
        String target = game(room).impostorIds().iterator().next();
        String other = room.players().stream().map(Player::id).filter(id -> !id.equals(target)).findFirst().orElseThrow();
        for (Player p : room.players()) {
            room.vote(p.id(), p.id().equals(target) ? other : target);
        }
        RoomView.ImpostorResult result = room.viewFor("p1").impostor().result();
        assertTrue(result.impostorCaught());
        assertEquals(2, result.impostorNames().size());
    }

    @Test
    void wortlisteHatKeineDoppelten() {
        List<String> words = ImpostorWords.allWords().stream().map(ImpostorWords.SecretWord::word).toList();
        assertEquals(words.size(), Set.copyOf(words).size());
        assertTrue(words.size() >= 100);
    }
}
