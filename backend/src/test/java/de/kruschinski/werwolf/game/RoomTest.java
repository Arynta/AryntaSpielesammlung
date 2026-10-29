package de.kruschinski.werwolf.game;

import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Random;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RoomTest {

    private final Clock clock = Clock.fixed(Instant.parse("2026-10-29T18:00:00Z"), ZoneOffset.UTC);

    /**
     * Raum mit Werwolf als Spiel, weil die meisten Tests hier Werwolf prüfen.
     * Das Limit steht auf dem Maximum, damit auch Tests mit vielen Spielern reinpassen.
     */
    private Room roomWith(String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
            if (room.players().size() == 1) {
                room.setPlayerLimit("p1", Room.MAX_PLAYERS);
            }
        }
        if (names.length > 0) {
            room.selectGame("p1", GameType.WERWOLF);
        }
        return room;
    }

    private static void allReady(Room room) {
        room.players().forEach(p -> room.setReady(p.id(), true));
    }

    private Room startedWerwolf(String... names) {
        Room room = roomWith(names);
        allReady(room);
        room.start("p1", new Random(42));
        return room;
    }

    // ---- Lobby ---------------------------------------------------------

    @Test
    void ersterSpielerWirdSpielleitung() {
        Room room = roomWith("Richard", "Anna");
        assertEquals("p1", room.hostId());
    }

    @Test
    void namenMuessenEindeutigSein() {
        Room room = roomWith("Richard");
        assertThrows(GameException.class, () -> room.addPlayer("  richard "));
    }

    @Test
    void leererNameWirdAbgelehnt() {
        Room room = roomWith();
        assertThrows(GameException.class, () -> room.addPlayer("   "));
    }

    @Test
    void unsichtbareZeichenWerdenEntfernt() {
        Room room = roomWith("Anna");
        // Zero-Width-Space, Schreibrichtungs-Umkehr und geschütztes Leerzeichen
        assertThrows(GameException.class, () -> room.addPlayer("An​na"));
        assertThrows(GameException.class, () -> room.addPlayer("‮Anna"));
        assertEquals("Ben Bo", room.addPlayer("Ben  Bo\u0007").name());
    }

    @Test
    void nurUnsichtbareZeichenSindKeinName() {
        Room room = roomWith();
        assertThrows(GameException.class, () -> room.addPlayer("​‍⁠"));
    }

    @Test
    void raumLimitSchuetztDenServer() {
        RoomRegistry registry = new RoomRegistry(clock, new Random(7));
        for (int i = 0; i < RoomRegistry.MAX_ROOMS; i++) {
            registry.createRoom();
        }
        assertThrows(GameException.class, registry::createRoom);
    }

    @Test
    void impostorIstVorausgewaehlt() {
        assertEquals(GameType.IMPOSTOR, new Room("TEST", clock).selectedGame());
    }

    // ---- Kicken --------------------------------------------------------

    @Test
    void hostKannInDerLobbyKicken() {
        Room room = roomWith("A", "B", "C");
        room.kick("p1", "p2");
        assertEquals(List.of("A", "C"), room.players().stream().map(Player::name).toList());
    }

    @Test
    void nurDerHostKannKicken() {
        Room room = roomWith("A", "B", "C");
        assertThrows(GameException.class, () -> room.kick("p2", "p3"));
    }

    @Test
    void hostKannSichNichtSelbstKicken() {
        Room room = roomWith("A", "B");
        assertThrows(GameException.class, () -> room.kick("p1", "p1"));
    }

    @Test
    void imLaufendenSpielWirdNichtGekickt() {
        Room room = startedWerwolf("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.kick("p1", "p2"));
    }

    @Test
    void gekickteKoennenMitDemCodeWiederRein() {
        Room room = roomWith("A", "B");
        room.kick("p1", "p2");
        room.addPlayer("B");
        assertEquals(2, room.players().size());
    }

    // ---- Spielerlimit --------------------------------------------------

    @Test
    void limitIstAnfangsSieben() {
        Room room = new Room("TEST", clock);
        room.addPlayer("A");
        assertEquals(7, room.viewFor("p1").playerLimit().value());
        for (String name : List.of("B", "C", "D", "E", "F", "G")) {
            room.addPlayer(name);
        }
        assertThrows(GameException.class, () -> room.addPlayer("H"));
    }

    @Test
    void volleRaeumeNehmenNiemandenMehrAuf() {
        Room room = roomWith("A", "B", "C");
        room.setPlayerLimit("p1", 3);
        assertThrows(GameException.class, () -> room.addPlayer("D"));
    }

    @Test
    void limitNichtUnterAktuellerSpielerzahl() {
        Room room = roomWith("A", "B", "C", "D");
        assertEquals(4, room.viewFor("p1").playerLimit().min());
        assertThrows(GameException.class, () -> room.setPlayerLimit("p1", 3));
    }

    @Test
    void limitBleibtImErlaubtenBereich() {
        Room room = roomWith("A");
        assertThrows(GameException.class, () -> room.setPlayerLimit("p1", Room.MIN_PLAYER_LIMIT - 1));
        assertThrows(GameException.class, () -> room.setPlayerLimit("p1", Room.MAX_PLAYERS + 1));
        room.setPlayerLimit("p1", Room.MIN_PLAYER_LIMIT);
        assertEquals(Room.MIN_PLAYER_LIMIT, room.playerLimit());
    }

    @Test
    void nurDerHostSetztDasLimit() {
        Room room = roomWith("A", "B");
        assertThrows(GameException.class, () -> room.setPlayerLimit("p2", 5));
    }

    @Test
    void nurSpielleitungDarfSpielWaehlen() {
        Room room = roomWith("A", "B");
        assertThrows(GameException.class, () -> room.selectGame("p2", GameType.IMPOSTOR));
        room.selectGame("p1", GameType.IMPOSTOR);
        assertEquals(GameType.IMPOSTOR, room.selectedGame());
    }

    @Test
    void spielwechselSetztBereitZurueck() {
        Room room = roomWith("A", "B");
        allReady(room);
        room.selectGame("p1", GameType.IMPOSTOR);
        room.players().forEach(p -> assertFalse(p.ready()));
    }

    @Test
    void gleichesSpielNochmalWaehlenSetztBereitNichtZurueck() {
        Room room = roomWith("A", "B");
        allReady(room);
        room.selectGame("p1", GameType.WERWOLF);
        room.players().forEach(p -> assertTrue(p.ready()));
    }

    @Test
    void ansichtZeigtStartHinweis() {
        Room room = roomWith("A", "B", "C");
        RoomView view = room.viewFor("p1");
        assertFalse(view.canStart());
        assertEquals("Noch 1 Spieler, dann kann es losgehen.", view.startHint());

        room.addPlayer("D");
        room.setReady("p1", true);
        assertEquals("Warte, bis alle bereit sind (1 von 4).", room.viewFor("p1").startHint());

        allReady(room);
        assertTrue(room.viewFor("p2").canStart());
        assertNull(room.viewFor("p2").startHint());
    }

    @Test
    void offlineSpielerBlockierenDenStartNicht() {
        Room room = roomWith("A", "B", "C", "D");
        room.setConnected("p4", false);
        room.setReady("p1", true);
        room.setReady("p2", true);
        room.setReady("p3", true);
        room.start("p1", new Random(1));
        assertEquals(Phase.NIGHT, room.phase());
    }

    // ---- Start ---------------------------------------------------------

    @Test
    void zuWenigeSpielerKoennenNichtStarten() {
        Room room = roomWith("A", "B", "C");
        allReady(room);
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
        assertEquals(Phase.LOBBY, room.phase());
    }

    @Test
    void ohneBereitKannNichtGestartetWerden() {
        Room room = roomWith("A", "B", "C", "D");
        room.setReady("p1", true);
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
    }

    @Test
    void nurSpielleitungDarfStarten() {
        Room room = roomWith("A", "B", "C", "D");
        allReady(room);
        assertThrows(GameException.class, () -> room.start("p2", new Random(1)));
    }

    @Test
    void startSetztBereitZurueck() {
        Room room = startedWerwolf("A", "B", "C", "D");
        room.players().forEach(p -> assertFalse(p.ready()));
    }

    @Test
    void imLaufendenSpielKannNiemandMehrBeitreten() {
        Room room = startedWerwolf("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.addPlayer("E"));
    }

    @Test
    void imLaufendenSpielGibtEsKeinBereit() {
        Room room = startedWerwolf("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.setReady("p2", true));
    }

    @Test
    void imLaufendenSpielKannManDasSpielNichtWechseln() {
        Room room = startedWerwolf("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.selectGame("p1", GameType.IMPOSTOR));
    }

    // ---- Werwolf -------------------------------------------------------

    @Test
    void rollenverteilungPasstZurSpielerzahl() {
        List<String> seer = List.of(WerwolfRoles.SEER);
        assertEquals(1, count(RoleDistribution.cardsFor(4, null, seer), WerwolfRoles.WEREWOLF));
        assertEquals(1, count(RoleDistribution.cardsFor(7, null, seer), WerwolfRoles.WEREWOLF));
        assertEquals(2, count(RoleDistribution.cardsFor(8, null, seer), WerwolfRoles.WEREWOLF));
        assertEquals(3, count(RoleDistribution.cardsFor(12, null, seer), WerwolfRoles.WEREWOLF));
        for (int n = GameType.WERWOLF.minPlayers(); n <= Room.MAX_PLAYERS; n++) {
            List<Role> roles = RoleDistribution.cardsFor(n, null, seer);
            assertEquals(n, roles.size());
            assertEquals(1, count(roles, WerwolfRoles.SEER));
        }
    }

    @Test
    void standardIstAutomatischMitSeherin() {
        RoomView.WerwolfSettings settings = roomWith("A", "B", "C", "D").viewFor("p2").werwolfSettings();
        assertNull(settings.werewolfCount());
        assertEquals(1, settings.effectiveWerewolfCount());
        assertEquals(List.of(WerwolfRoles.SEER), settings.selectedRoles());
        assertFalse(settings.hostIsGameMaster());
    }

    @Test
    void startVerteiltRollenUndBeginntMitNacht() {
        Room room = startedWerwolf("A", "B", "C", "D", "E", "F", "G", "H");

        assertEquals(Phase.NIGHT, room.phase());
        assertEquals(1, room.round());
        WerwolfGame game = (WerwolfGame) room.game();
        List<Role> roles = room.players().stream().map(p -> game.roleOf(p.id())).toList();
        assertFalse(roles.contains(null));
        assertEquals(2, count(roles, WerwolfRoles.WEREWOLF));
    }

    @Test
    void ansichtVerraetKeineFremdenRollen() {
        Room room = startedWerwolf("A", "B", "C", "D", "E", "F", "G", "H");
        WerwolfGame game = (WerwolfGame) room.game();

        for (Player p : room.players()) {
            RoomView view = room.viewFor(p.id());
            assertNull(view.impostor());
            assertNull(view.werwolf().overview(), "Nur die Spielleitung sieht alle Rollen");
            assertEquals(game.roleOf(p.id()).id(), view.werwolf().role().id());
            if (game.roleOf(p.id()).wolfPack()) {
                assertEquals(1, view.werwolf().knownWolves().size(), "Werwolf soll den anderen Werwolf kennen");
            } else {
                assertTrue(view.werwolf().knownWolves().isEmpty(), "Nur Werwölfe kennen Werwölfe");
            }
        }
    }

    @Test
    void gewaehlteRollenKommenInsSpiel() {
        Room room = roomWith("A", "B", "C", "D", "E", "F");
        room.configureWerwolf("p1", 2, List.of("JAEGER", "HEXE"), false);
        allReady(room);
        room.start("p1", new Random(1));

        WerwolfGame game = (WerwolfGame) room.game();
        List<Role> roles = room.players().stream().map(p -> game.roleOf(p.id())).toList();
        assertEquals(2, count(roles, WerwolfRoles.WEREWOLF));
        assertEquals(1, count(roles, "HEXE"));
        assertEquals(1, count(roles, "JAEGER"));
        assertEquals(0, count(roles, WerwolfRoles.SEER));
        assertEquals(2, count(roles, WerwolfRoles.VILLAGER));
        assertTrue(game.leftover().isEmpty());
        // Reihenfolge wie in der Rollenliste, egal wie sie geschickt wurde
        assertEquals(List.of("HEXE", "JAEGER"), room.viewFor("p1").werwolfSettings().selectedRoles());
    }

    @Test
    void zuVieleRollenBlockierenDenStart() {
        Room room = roomWith("A", "B", "C", "D");
        room.configureWerwolf("p1", 2, List.of(WerwolfRoles.SEER, "HEXE", "JAEGER"), false);
        allReady(room);
        assertEquals("Zu viele Rollen: 5 Rollen für 4 Spieler. Nimm Rollen raus oder weniger Werwölfe.",
                room.viewFor("p1").startHint());
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
    }

    @Test
    void falscheRollenauswahlWirdAbgelehnt() {
        Room room = roomWith("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.configureWerwolf("p1", null, List.of("QUATSCH"), false));
        assertThrows(GameException.class, () -> room.configureWerwolf("p1", null, List.of(WerwolfRoles.VILLAGER), false));
        assertThrows(GameException.class, () -> room.configureWerwolf("p1", 0, List.of(), false));
        assertThrows(GameException.class, () -> room.configureWerwolf("p2", null, List.of(), false));
    }

    @Test
    void diebSiehtDieZweiUebrigenKarten() {
        assertEquals(6, RoleDistribution.cardsFor(4, null, List.of(WerwolfRoles.THIEF)).size());
        for (int seed = 0; seed < 30; seed++) {
            Room room = roomWith("A", "B", "C", "D", "E");
            room.configureWerwolf("p1", null, List.of(WerwolfRoles.THIEF), false);
            allReady(room);
            room.start("p1", new Random(seed));
            WerwolfGame game = (WerwolfGame) room.game();
            assertEquals(2, game.leftover().size());
            for (Player p : room.players()) {
                RoomView.WerwolfView view = room.viewFor(p.id()).werwolf();
                boolean thief = game.roleOf(p.id()).id().equals(WerwolfRoles.THIEF);
                assertEquals(thief ? 2 : 0, view.leftoverRoles().size());
            }
        }
    }

    @Test
    void guenstlingKenntDasRudelAberDasRudelNichtIhn() {
        Room room = roomWith("A", "B", "C", "D", "E", "F");
        room.configureWerwolf("p1", 1, List.of("URWOLF", "GUENSTLING"), false);
        allReady(room);
        room.start("p1", new Random(9));
        WerwolfGame game = (WerwolfGame) room.game();

        for (Player p : room.players()) {
            Role role = game.roleOf(p.id());
            List<String> known = room.viewFor(p.id()).werwolf().knownWolves();
            if (role.id().equals("GUENSTLING")) {
                assertEquals(2, known.size());
            } else if (role.wolfPack()) {
                assertEquals(1, known.size(), "Werwolf und Urwolf kennen sich, den Günstling nicht");
            } else {
                assertTrue(known.isEmpty());
            }
        }
    }

    @Test
    void spielleitungSiehtAlleRollenUndSpieltNichtMit() {
        Room room = roomWith("A", "B", "C", "D", "E");
        room.configureWerwolf("p1", null, List.of(WerwolfRoles.SEER), true);
        allReady(room);
        room.start("p1", new Random(4));

        RoomView.WerwolfView host = room.viewFor("p1").werwolf();
        assertTrue(host.gameMaster());
        assertNull(host.role());
        assertEquals(4, host.overview().size());
        assertTrue(host.overview().stream().noneMatch(a -> a.playerId().equals("p1")));
        assertNull(((WerwolfGame) room.game()).roleOf("p1"));
    }

    @Test
    void spielleitungBrauchtEinenSpielerMehr() {
        Room room = roomWith("A", "B", "C", "D");
        room.configureWerwolf("p1", null, List.of(WerwolfRoles.SEER), true);
        allReady(room);
        assertEquals("Noch 1 Spieler (ohne Spielleitung), dann kann es losgehen.", room.viewFor("p1").startHint());
    }

    @Test
    void rollendateiIstVollstaendig() {
        assertEquals(19, WerwolfRoles.specialRoles().size());
        for (Role role : WerwolfRoles.specialRoles()) {
            assertFalse(role.name().isBlank());
            assertFalse(role.description().isBlank());
            assertNotEquals(role.team(), WerwolfRoles.teamName(role.team()), "Team " + role.team() + " fehlt");
        }
    }

    @Test
    void phasenWechselnUndRundenZaehlenHoch() {
        Room room = startedWerwolf("A", "B", "C", "D");
        room.nextPhase("p1");
        assertEquals(Phase.DAY, room.phase());
        room.nextPhase("p1");
        assertEquals(Phase.NIGHT, room.phase());
        assertEquals(2, room.round());
    }

    @Test
    void zurueckInDieLobbyBeendetDasSpiel() {
        Room room = startedWerwolf("A", "B", "C", "D");
        room.backToLobby("p1");
        assertEquals(Phase.LOBBY, room.phase());
        assertNull(room.game());
        assertNull(room.viewFor("p1").werwolf());
    }

    // ---- Raum ----------------------------------------------------------

    @Test
    void wennSpielleitungGehtUebernimmtDerNaechste() {
        Room room = roomWith("A", "B");
        room.leave("p1");
        assertEquals("p2", room.hostId());
        assertEquals(1, room.players().size());
    }

    @Test
    void wiederEinsteigenPerSecret() {
        Room room = roomWith("A");
        Player a = room.players().get(0);
        assertEquals(a.id(), room.findBySecret(a.secret()).orElseThrow().id());
        assertTrue(room.findBySecret("falsch").isEmpty());
    }

    @Test
    void raumcodesSindVierZeichenUndFindbar() {
        RoomRegistry registry = new RoomRegistry(clock, new Random(7));
        Room room = registry.createRoom();
        assertEquals(4, room.code().length());
        assertTrue(registry.find(room.code().toLowerCase()).isPresent());
    }

    @Test
    void alteRaeumeWerdenAufgeraeumt() {
        MutableClock mutable = new MutableClock(clock.instant());
        RoomRegistry registry = new RoomRegistry(mutable, new Random(7));
        registry.createRoom();
        mutable.advance(Duration.ofHours(7));
        assertEquals(1, registry.removeIdleRooms(Duration.ofHours(6)));
        assertEquals(0, registry.size());
    }

    private static long count(List<Role> roles, String roleId) {
        return roles.stream().filter(r -> r.id().equals(roleId)).count();
    }

    private static final class MutableClock extends Clock {
        private Instant now;

        MutableClock(Instant start) {
            this.now = start;
        }

        void advance(Duration d) {
            now = now.plus(d);
        }

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
