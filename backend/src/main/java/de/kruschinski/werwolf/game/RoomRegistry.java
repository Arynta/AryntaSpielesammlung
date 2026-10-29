package de.kruschinski.werwolf.game;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.random.RandomGenerator;

/**
 * Hält alle offenen Räume im Arbeitsspeicher. Startet der Server neu (z. B. weil
 * Render ihn schlafen gelegt hat), sind die Räume weg. Für Spieleabende reicht das.
 */
public class RoomRegistry {

    /** Ohne I, L, O, 0, 1, damit man den Code gut vorlesen kann. */
    private static final String CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final int CODE_LENGTH = 4;

    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    private final Clock clock;
    private final RandomGenerator random;

    public RoomRegistry() {
        this(Clock.systemUTC(), new SecureRandom());
    }

    public RoomRegistry(Clock clock, RandomGenerator random) {
        this.clock = clock;
        this.random = random;
    }

    public RandomGenerator random() {
        return random;
    }

    public Room createRoom() {
        for (int attempt = 0; attempt < 100; attempt++) {
            String code = randomCode();
            Room room = new Room(code, clock);
            if (rooms.putIfAbsent(code, room) == null) {
                return room;
            }
        }
        throw new GameException("Konnte keinen freien Raumcode finden. Versuch es nochmal.");
    }

    public Optional<Room> find(String code) {
        if (code == null) {
            return Optional.empty();
        }
        return Optional.ofNullable(rooms.get(code.strip().toUpperCase()));
    }

    public Room require(String code) {
        return find(code).orElseThrow(() -> new GameException("Diesen Raum gibt es nicht (mehr)."));
    }

    public void removeIfEmpty(Room room) {
        if (room.isEmpty()) {
            rooms.remove(room.code(), room);
        }
    }

    /** Wirft Räume weg, in denen länger nichts passiert ist. Gibt die Anzahl entfernter Räume zurück. */
    public int removeIdleRooms(Duration maxIdle) {
        Instant cutoff = clock.instant().minus(maxIdle);
        int before = rooms.size();
        rooms.values().removeIf(room -> room.lastActivity().isBefore(cutoff));
        return before - rooms.size();
    }

    public int size() {
        return rooms.size();
    }

    private String randomCode() {
        StringBuilder sb = new StringBuilder(CODE_LENGTH);
        for (int i = 0; i < CODE_LENGTH; i++) {
            sb.append(CODE_ALPHABET.charAt(random.nextInt(CODE_ALPHABET.length())));
        }
        return sb.toString();
    }
}
