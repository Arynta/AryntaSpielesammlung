package de.kruschinski.werwolf.ws;

import de.kruschinski.werwolf.game.GameException;
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
        try {
            ClientMessage msg = json.readValue(message.getPayload(), ClientMessage.class);
            handle(session, msg);
        } catch (GameException e) {
            send(session, Map.of("type", "error", "message", e.getMessage()));
        } catch (Exception e) {
            log.warn("Fehler bei Nachricht {}", message.getPayload(), e);
            send(session, Map.of("type", "error", "message", "Da ist etwas schiefgelaufen."));
        }
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

            case "start" -> withRoom(session, (room, playerId) -> room.start(playerId, rooms.random()));
            case "nextPhase" -> withRoom(session, Room::nextPhase);
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
        standUp(session); // falls die Verbindung vorher in einem anderen Raum war
        Seat seat = new Seat(room.code(), player.id());
        seatsBySession.put(session.getId(), seat);
        sessionsBySeat.put(seat.key(), session);
        send(session, Map.of("type", "joined", "code", room.code(), "secret", player.secret()));
        broadcast(room);
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
