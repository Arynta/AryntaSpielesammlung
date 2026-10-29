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
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RoomTest {

    private final Clock clock = Clock.fixed(Instant.parse("2026-10-29T18:00:00Z"), ZoneOffset.UTC);

    private Room roomWith(String... names) {
        Room room = new Room("TEST", clock);
        for (String name : names) {
            room.addPlayer(name);
        }
        return room;
    }

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
    void rollenverteilungPasstZurSpielerzahl() {
        assertEquals(1, count(RoleDistribution.rolesFor(4), Role.WERWOLF));
        assertEquals(1, count(RoleDistribution.rolesFor(7), Role.WERWOLF));
        assertEquals(2, count(RoleDistribution.rolesFor(8), Role.WERWOLF));
        assertEquals(3, count(RoleDistribution.rolesFor(12), Role.WERWOLF));
        for (int n = Room.MIN_PLAYERS; n <= Room.MAX_PLAYERS; n++) {
            List<Role> roles = RoleDistribution.rolesFor(n);
            assertEquals(n, roles.size());
            assertEquals(1, count(roles, Role.SEHERIN));
        }
    }

    @Test
    void zuWenigeSpielerKoennenNichtStarten() {
        Room room = roomWith("A", "B", "C");
        assertThrows(GameException.class, () -> room.start("p1", new Random(1)));
        assertEquals(Phase.LOBBY, room.phase());
    }

    @Test
    void nurSpielleitungDarfStarten() {
        Room room = roomWith("A", "B", "C", "D");
        assertThrows(GameException.class, () -> room.start("p2", new Random(1)));
    }

    @Test
    void startVerteiltRollenUndBeginntMitNacht() {
        Room room = roomWith("A", "B", "C", "D", "E", "F", "G", "H");
        room.start("p1", new Random(42));

        assertEquals(Phase.NIGHT, room.phase());
        assertEquals(1, room.round());
        List<Role> roles = room.players().stream().map(Player::role).toList();
        assertEquals(2, count(roles, Role.WERWOLF));
        assertFalse(roles.contains(null));
    }

    @Test
    void ansichtVerraetKeineFremdenRollen() {
        Room room = roomWith("A", "B", "C", "D", "E", "F", "G", "H");
        room.start("p1", new Random(42));

        for (Player p : room.players()) {
            RoomView view = room.viewFor(p.id());
            assertEquals(p.role(), view.you().role());
            if (p.role() == Role.WERWOLF) {
                assertEquals(1, view.you().fellowWerewolves().size(), "Werwolf soll den anderen Werwolf kennen");
            } else {
                assertTrue(view.you().fellowWerewolves().isEmpty(), "Nur Werwölfe kennen Werwölfe");
            }
        }
    }

    @Test
    void phasenWechselnUndRundenZaehlenHoch() {
        Room room = roomWith("A", "B", "C", "D");
        room.start("p1", new Random(1));
        room.nextPhase("p1");
        assertEquals(Phase.DAY, room.phase());
        room.nextPhase("p1");
        assertEquals(Phase.NIGHT, room.phase());
        assertEquals(2, room.round());
    }

    @Test
    void imLaufendenSpielKannNiemandMehrBeitreten() {
        Room room = roomWith("A", "B", "C", "D");
        room.start("p1", new Random(1));
        assertThrows(GameException.class, () -> room.addPlayer("E"));
    }

    @Test
    void zurueckInDieLobbyLoeschtRollen() {
        Room room = roomWith("A", "B", "C", "D");
        room.start("p1", new Random(1));
        room.backToLobby("p1");
        assertEquals(Phase.LOBBY, room.phase());
        room.players().forEach(p -> assertNull(p.role()));
    }

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

    private static long count(List<Role> roles, Role role) {
        return roles.stream().filter(r -> r == role).count();
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
