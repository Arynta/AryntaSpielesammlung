package de.kruschinski.werwolf.ws;

import de.kruschinski.werwolf.game.GameException;
import de.kruschinski.werwolf.game.GameType;
import de.kruschinski.werwolf.game.Player;
import de.kruschinski.werwolf.game.Room;
import de.kruschinski.werwolf.game.RoomRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Nimmt alle WebSocket-Nachrichten der Handys entgegen und schickt nach jeder Änderung
 * jedem Spieler im Raum seine eigene Ansicht ({@code state}).
 */
@Component
public class GameSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(GameSocketHandler.class);

    /** Wer sitzt an welcher Verbindung? */
    private record Seat(String roomCode, String playerId) {
        String key() {
            return roomCode + ":" + playerId;
        }
    }

    private final RoomRegistry rooms;
    private final JsonMapper json;

    /** Session-ID → threadsichere Session. */
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    /** Session-ID → Platz im Raum. */
    private final Map<String, Seat> seatsBySession = new ConcurrentHashMap<>();
    /** "RAUM:spielerId" → aktuelle Session dieses Spielers. */
    private final Map<String, WebSocketSession> sessionsBySeat = new ConcurrentHashMap<>();

    public GameSocketHandler(RoomRegistry rooms, JsonMapper json) {
        this.rooms = rooms;
        this.json = json;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        // Der Decorator sorgt dafür, dass zwei Threads nicht gleichzeitig in dieselbe Verbindung schreiben
        sessions.put(session.getId(), new ConcurrentWebSocketSessionDecorator(session, 5_000, 64 * 1024));
    }

    @Override
    protected void handleTextMessage(WebSocketSession rawSession, TextMessage message) {
        WebSocketSession session = sessions.getOrDefault(rawSession.getId(), rawSession);
        ClientMessage msg = parse(message);
        if (msg == null) {
            sendUnexpectedError(session);
            return;
        }

        try {
            handle(session, msg);
        } catch (GameException e) {
            send(session, Map.of("type", "error", "message", e.getMessage()));
        } catch (Exception e) {
            log.warn("Fehler bei Nachricht vom Typ {}", msg.type(), e);
            sendUnexpectedError(session);
        }
    }

    /** Liefert {@code null}, wenn die Nachricht kein gültiges JSON ist. */
    private ClientMessage parse(TextMessage message) {
        try {
            return json.readValue(message.getPayload(), ClientMessage.class);
        } catch (JacksonException e) {
            // Weder Inhalt noch Jackson-Meldung loggen: beides kann Spielernamen enthalten
            log.warn("Unlesbare Nachricht verworfen ({} Zeichen)", message.getPayloadLength());
            return null;
        }
    }

    private void sendUnexpectedError(WebSocketSession session) {
        send(session, Map.of("type", "error", "message", "Da ist etwas schiefgelaufen."));
    }

    private void handle(WebSocketSession session, ClientMessage msg) {
        String type = msg.type() == null ? "" : msg.type();
        switch (type) {
            case "ping" -> send(session, Map.of("type", "pong"));

            case "create" -> {
                Room room = rooms.createRoom();
                try {
                    Player player = room.addPlayer(msg.name());
                    sitDown(session, room, player);
                } catch (GameException e) {
                    rooms.removeIfEmpty(room);
                    throw e;
                }
            }

            case "join" -> {
                Room room = rooms.require(msg.code());
                sitDown(session, room, room.addPlayer(msg.name()));
            }

            case "rejoin" -> {
                Room room = rooms.require(msg.code());
                Player player = room.findBySecret(msg.secret())
                        .orElseThrow(() -> new GameException("Du bist nicht (mehr) in diesem Raum."));
                room.setConnected(player.id(), true);
                sitDown(session, room, player);
            }

            case "leave" -> {
                Seat seat = requireSeat(session);
                Room room = rooms.require(seat.roomCode());
                room.leave(seat.playerId());
                standUp(session);
                send(session, Map.of("type", "left"));
                rooms.removeIfEmpty(room);
                broadcast(room);
            }

            case "selectGame" -> {
                GameType game = parseGameType(msg.game());
                withRoom(session, (room, playerId) -> room.selectGame(playerId, game));
            }
            case "setReady" -> withRoom(session,
                    (room, playerId) -> room.setReady(playerId, Boolean.TRUE.equals(msg.ready())));
            case "configureImpostor" -> withRoom(session, (room, playerId) -> room.configureImpostor(
                    playerId, Boolean.TRUE.equals(msg.impostorSeesCategory()), msg.customWord()));
            case "setImpostorCategories" -> withRoom(session,
                    (room, playerId) -> room.setImpostorCategories(playerId, msg.categories()));
            case "setImpostorOptions" -> {
                if (msg.impostorCount() == null) {
                    throw new GameException("Bitte gib die Anzahl der Impostor an.");
                }
                withRoom(session, (room, playerId) -> room.setImpostorOptions(
                        playerId, msg.impostorCount(), Boolean.TRUE.equals(msg.randomStartPlayer())));
            }
            case "configureWerwolf" -> withRoom(session, (room, playerId) -> room.configureWerwolf(
                    playerId, msg.werewolfCount(), msg.roles(), Boolean.TRUE.equals(msg.hostIsGameMaster())));
            case "setPlayerLimit" -> {
                if (msg.playerLimit() == null) {
                    throw new GameException("Bitte gib ein Spielerlimit an.");
                }
                withRoom(session, (room, playerId) -> room.setPlayerLimit(playerId, msg.playerLimit()));
            }
            case "kick" -> withRoom(session, (room, playerId) -> {
                room.kick(playerId, msg.targetId());
                sendOff(room, msg.targetId());
            });

            case "start" -> withRoom(session, (room, playerId) -> room.start(playerId, rooms.random()));
            case "nextPhase" -> withRoom(session, Room::nextPhase);
            case "startVoting" -> withRoom(session, Room::startVoting);
            case "vote" -> withRoom(session, (room, playerId) -> room.vote(playerId, msg.targetId()));
            case "nextRound" -> withRoom(session, (room, playerId) -> room.nextRound(playerId, rooms.random()));
            case "backToLobby" -> withRoom(session, Room::backToLobby);

            default -> throw new GameException("Unbekannte Aktion: " + type);
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session.getId());
        Seat seat = seatsBySession.remove(session.getId());
        if (seat == null) {
            return;
        }
        // Nur offline markieren, wenn der Spieler nicht schon mit einer neuen Verbindung zurück ist
        WebSocketSession current = sessionsBySeat.get(seat.key());
        if (current != null && current.getId().equals(session.getId())) {
            sessionsBySeat.remove(seat.key());
            rooms.find(seat.roomCode()).ifPresent(room -> {
                room.setConnected(seat.playerId(), false);
                broadcast(room);
            });
        }
    }

    // ---------------------------------------------------------------------

    private static GameType parseGameType(String raw) {
        try {
            return GameType.valueOf(raw == null ? "" : raw.strip().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new GameException("Dieses Spiel gibt es nicht.");
        }
    }

    private interface RoomAction {
        void apply(Room room, String playerId);
    }

    private void withRoom(WebSocketSession session, RoomAction action) {
        Seat seat = requireSeat(session);
        Room room = rooms.require(seat.roomCode());
        action.apply(room, seat.playerId());
        broadcast(room);
    }

    private void sitDown(WebSocketSession session, Room room, Player player) {
        leavePreviousRoom(session, room);
        standUp(session);
        Seat seat = new Seat(room.code(), player.id());
        seatsBySession.put(session.getId(), seat);
        sessionsBySeat.put(seat.key(), session);
        send(session, Map.of("type", "joined", "code", room.code(), "secret", player.secret()));
        broadcast(room);
    }

    /**
     * Wechselt eine Verbindung in einen anderen Raum, verlässt sie den alten. Sonst bliebe dort ein
     * Spieler zurück, der als online gilt, nie bereit wird und den Raum nie leer werden lässt.
     */
    private void leavePreviousRoom(WebSocketSession session, Room next) {
        Seat previous = seatsBySession.get(session.getId());
        if (previous == null || previous.roomCode().equals(next.code())) {
            return;
        }
        rooms.find(previous.roomCode()).ifPresent(oldRoom -> {
            boolean stillSeated = oldRoom.players().stream().anyMatch(p -> p.id().equals(previous.playerId()));
            if (stillSeated) {
                oldRoom.leave(previous.playerId());
            }
            standUp(session);
            rooms.removeIfEmpty(oldRoom);
            broadcast(oldRoom);
        });
    }

    /** Meldet die Verbindung eines gekickten Spielers ab, damit sein Handy auf die Startseite geht. */
    private void sendOff(Room room, String playerId) {
        WebSocketSession kicked = sessionsBySeat.get(new Seat(room.code(), playerId).key());
        if (kicked == null) {
            return;
        }
        standUp(kicked);
        send(kicked, Map.of("type", "kicked"));
    }

    private void standUp(WebSocketSession session) {
        Seat old = seatsBySession.remove(session.getId());
        if (old != null) {
            sessionsBySeat.remove(old.key(), session);
        }
    }

    private Seat requireSeat(WebSocketSession session) {
        Seat seat = seatsBySession.get(session.getId());
        if (seat == null) {
            throw new GameException("Du bist in keinem Raum.");
        }
        return seat;
    }

    /** Schickt jedem verbundenen Spieler im Raum seine persönliche Ansicht. */
    private void broadcast(Room room) {
        for (Player player : room.players()) {
            WebSocketSession target = sessionsBySeat.get(room.code() + ":" + player.id());
            if (target != null) {
                send(target, Map.of("type", "state", "state", room.viewFor(player.id())));
            }
        }
    }

    private void send(WebSocketSession session, Object payload) {
        if (!session.isOpen()) {
            return;
        }
        try {
            session.sendMessage(new TextMessage(json.writeValueAsString(payload)));
        } catch (IOException | IllegalStateException e) {
            log.debug("Konnte Nachricht nicht senden an {}", session.getId(), e);
        }
    }
}
