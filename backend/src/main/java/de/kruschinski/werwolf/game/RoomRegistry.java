package de.kruschinski.werwolf.game;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
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
    /** Schützt den kleinen Server (512 MB) davor, dass ein Skript ihn mit Räumen vollstopft. */
    public static final int MAX_ROOMS = 200;

    private final Map<String, Room> rooms = new ConcurrentHashMap<>();
    /** Raumcode → Adresse, von der aus der Raum erstellt wurde. Nur für das Limit pro Adresse. */
    private final Map<String, String> creatorByCode = new ConcurrentHashMap<>();
    private final Clock clock;
    private final RandomGenerator random;
    /** Spiele, die noch nicht gewählt werden können ("Bald verfügbar"). */
    private final Set<GameType> lockedGames;
    /** So viele Räume darf eine Adresse gleichzeitig offen haben, damit niemand allein alle {@link #MAX_ROOMS} belegt. */
    private final int maxRoomsPerAddress;

    public RoomRegistry(Set<GameType> lockedGames, int maxRoomsPerAddress) {
        this(Clock.systemUTC(), new SecureRandom(), lockedGames, maxRoomsPerAddress);
    }

    public RoomRegistry(Clock clock, RandomGenerator random) {
        this(clock, random, Set.of(), Integer.MAX_VALUE);
    }

    public RoomRegistry(Clock clock, RandomGenerator random, Set<GameType> lockedGames, int maxRoomsPerAddress) {
        this.clock = clock;
        this.random = random;
        this.lockedGames = Set.copyOf(lockedGames);
        this.maxRoomsPerAddress = maxRoomsPerAddress;
    }

    public RandomGenerator random() {
        return random;
    }

    public Room createRoom() {
        return createRoom(null);
    }

    /** {@code address}: woher die Anfrage kommt, {@code null} heißt ohne Limit pro Adresse. */
    public synchronized Room createRoom(String address) {
        if (rooms.size() >= MAX_ROOMS) {
            throw new GameException("error.rooms.tooMany");
        }
        if (address != null && openRoomsOf(address) >= maxRoomsPerAddress) {
            throw new GameException("error.rooms.tooManyFromAddress");
        }
        for (int attempt = 0; attempt < 100; attempt++) {
            String code = randomCode();
            Room room = new Room(code, clock, lockedGames);
            if (rooms.putIfAbsent(code, room) == null) {
                if (address != null) {
                    creatorByCode.put(code, address);
                }
                return room;
            }
        }
        throw new GameException("error.rooms.noFreeCode");
    }

    /**
     * Zählt nur Räume, in denen noch jemand verbunden ist. Sonst sperrten verlassene Räume eine Adresse bis
     * zu 6 Stunden, und hinter Mobilfunk-Anbietern teilen sich viele Menschen eine Adresse.
     */
    private long openRoomsOf(String address) {
        // Geschlossene Räume vergessen, egal ob sie leer wurden oder abgelaufen sind
        creatorByCode.keySet().retainAll(rooms.keySet());
        return creatorByCode.entrySet().stream()
                .filter(e -> e.getValue().equals(address))
                .filter(e -> rooms.get(e.getKey()) instanceof Room room && room.hasConnectedPlayers())
                .count();
    }

    public Optional<Room> find(String code) {
        if (code == null) {
            return Optional.empty();
        }
        return Optional.ofNullable(rooms.get(code.strip().toUpperCase()));
    }

    public Room require(String code) {
        return find(code).orElseThrow(() -> new GameException("error.rooms.unknown"));
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
