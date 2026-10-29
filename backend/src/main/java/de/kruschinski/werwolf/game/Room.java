package de.kruschinski.werwolf.game;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.random.RandomGenerator;

/**
 * Ein Spielraum. Alle Methoden sind synchronized, weil mehrere Handys gleichzeitig
 * Nachrichten schicken können. Für ein paar Freunde ist das mehr als schnell genug.
 */
public class Room {

    public static final int MIN_PLAYERS = 4;
    public static final int MAX_PLAYERS = 20;
    public static final int MAX_NAME_LENGTH = 20;

    private final String code;
    private final Clock clock;
    private final Map<String, Player> players = new LinkedHashMap<>(); // Reihenfolge = Beitrittsreihenfolge
    private String hostId;
    private Phase phase = Phase.LOBBY;
    private int round = 0;
    private int nextPlayerNumber = 1;
    private Instant lastActivity;

    public Room(String code, Clock clock) {
        this.code = code;
        this.clock = clock;
        this.lastActivity = clock.instant();
    }

    public String code() {
        return code;
    }

    public synchronized Phase phase() {
        return phase;
    }

    public synchronized int round() {
        return round;
    }

    public synchronized String hostId() {
        return hostId;
    }

    public synchronized Instant lastActivity() {
        return lastActivity;
    }

    public synchronized boolean isEmpty() {
        return players.isEmpty();
    }

    public synchronized List<Player> players() {
        return List.copyOf(players.values());
    }

    public synchronized Player addPlayer(String rawName) {
        if (phase != Phase.LOBBY) {
            throw new GameException("Das Spiel läuft schon. Warte auf die nächste Runde.");
        }
        if (players.size() >= MAX_PLAYERS) {
            throw new GameException("Der Raum ist voll.");
        }
        String name = cleanName(rawName);
        boolean taken = players.values().stream().anyMatch(p -> p.name().equalsIgnoreCase(name));
        if (taken) {
            throw new GameException("Der Name \"" + name + "\" ist schon vergeben.");
        }

        Player player = new Player("p" + nextPlayerNumber++, UUID.randomUUID().toString(), name);
        players.put(player.id(), player);
        if (hostId == null) {
            hostId = player.id();
        }
        touch();
        return player;
    }

    public synchronized Optional<Player> findBySecret(String secret) {
        if (secret == null) {
            return Optional.empty();
        }
        return players.values().stream().filter(p -> p.secret().equals(secret)).findFirst();
    }

    /** Spieler verlässt den Raum. Im laufenden Spiel bleibt er drin und gilt nur als offline. */
    public synchronized void leave(String playerId) {
        Player player = require(playerId);
        if (phase != Phase.LOBBY) {
            player.setConnected(false);
            touch();
            return;
        }
        players.remove(playerId);
        if (playerId.equals(hostId)) {
            hostId = players.isEmpty() ? null : players.keySet().iterator().next();
        }
        touch();
    }

    public synchronized void setConnected(String playerId, boolean connected) {
        Player player = players.get(playerId);
        if (player != null) {
            player.setConnected(connected);
            touch();
        }
    }

    public synchronized void start(String requesterId, RandomGenerator random) {
        requireHost(requesterId);
        if (phase != Phase.LOBBY) {
            throw new GameException("Das Spiel läuft schon.");
        }
        List<Player> list = new ArrayList<>(players.values());
        List<Role> roles = RoleDistribution.shuffledRolesFor(list.size(), random);
        for (int i = 0; i < list.size(); i++) {
            list.get(i).setRole(roles.get(i));
            list.get(i).setAlive(true);
        }
        phase = Phase.NIGHT;
        round = 1;
        touch();
    }

    /**
     * Schaltet zwischen Nacht und Tag um. Das ist die Stelle, an der du die eigentlichen
     * Spielregeln einbaust (Abstimmungen auswerten, Opfer bestimmen, Siegbedingung prüfen).
     */
    public synchronized void nextPhase(String requesterId) {
        requireHost(requesterId);
        switch (phase) {
            case LOBBY -> throw new GameException("Das Spiel wurde noch nicht gestartet.");
            case NIGHT -> phase = Phase.DAY;
            case DAY -> {
                phase = Phase.NIGHT;
                round++;
            }
        }
        touch();
    }

    /** Zurück in die Lobby, z. B. für eine neue Runde mit denselben Leuten. */
    public synchronized void backToLobby(String requesterId) {
        requireHost(requesterId);
        players.values().removeIf(p -> !p.connected());
        for (Player p : players.values()) {
            p.setRole(null);
            p.setAlive(true);
        }
        if (!players.containsKey(hostId)) {
            hostId = players.isEmpty() ? null : players.keySet().iterator().next();
        }
        phase = Phase.LOBBY;
        round = 0;
        touch();
    }

    /** Baut die Ansicht für genau einen Spieler. Fremde Rollen stehen hier nie drin. */
    public synchronized RoomView viewFor(String playerId) {
        Player me = require(playerId);

        List<RoomView.PlayerView> publicPlayers = players.values().stream()
                .map(p -> new RoomView.PlayerView(p.id(), p.name(), p.alive(), p.connected()))
                .toList();

        List<String> fellowWerewolves = List.of();
        if (me.role() == Role.WERWOLF) {
            fellowWerewolves = players.values().stream()
                    .filter(p -> p.role() == Role.WERWOLF && !p.id().equals(me.id()))
                    .map(Player::name)
                    .toList();
        }

        Role role = me.role();
        RoomView.You you = new RoomView.You(
                me.id(),
                me.name(),
                me.id().equals(hostId),
                role,
                role == null ? null : role.displayName(),
                role == null ? null : role.description(),
                fellowWerewolves);

        return new RoomView(code, phase, round, hostId, publicPlayers, you);
    }

    private void requireHost(String requesterId) {
        if (!requesterId.equals(hostId)) {
            throw new GameException("Das darf nur die Spielleitung.");
        }
    }

    private Player require(String playerId) {
        Player player = players.get(playerId);
        if (player == null) {
            throw new GameException("Du bist nicht (mehr) in diesem Raum.");
        }
        return player;
    }

    private void touch() {
        lastActivity = clock.instant();
    }

    static String cleanName(String rawName) {
        String name = rawName == null ? "" : rawName.strip().replaceAll("\\s+", " ");
        if (name.isEmpty()) {
            throw new GameException("Bitte gib einen Namen ein.");
        }
        if (name.length() > MAX_NAME_LENGTH) {
            throw new GameException("Der Name darf höchstens " + MAX_NAME_LENGTH + " Zeichen lang sein.");
        }
        return name;
    }
}
