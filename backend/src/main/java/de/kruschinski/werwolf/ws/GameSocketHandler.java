package de.kruschinski.werwolf.ws;

import de.kruschinski.werwolf.game.GameException;
import de.kruschinski.werwolf.game.GameType;
import de.kruschinski.werwolf.game.GeoBingoGame;
import de.kruschinski.werwolf.game.Player;
import de.kruschinski.werwolf.game.Room;
import de.kruschinski.werwolf.game.RoomRegistry;
import de.kruschinski.werwolf.i18n.Language;
import de.kruschinski.werwolf.i18n.Text;
import org.jspecify.annotations.NonNull;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.time.Clock;
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
    /** Beendet Tabu-Züge pünktlich, auch wenn gerade niemand etwas drückt. */
    private final TaskScheduler scheduler;

    /** Session-ID → threadsichere Session. */
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    /** Session-ID → Platz im Raum. */
    private final Map<String, Seat> seatsBySession = new ConcurrentHashMap<>();
    /** "RAUM:spielerId" → aktuelle Session dieses Spielers. */
    private final Map<String, WebSocketSession> sessionsBySeat = new ConcurrentHashMap<>();
    /** Session-ID → Sprache des Handys, für Fehlermeldungen auch ohne Raum. */
    private final Map<String, Language> languagesBySession = new ConcurrentHashMap<>();
    /** Session-ID → Bremse gegen Skripte. */
    private final Map<String, ConnectionGuard> guardsBySession = new ConcurrentHashMap<>();
    /** Session-ID → Adresse des Handys, für das Raumlimit pro Adresse. */
    private final Map<String, String> addressesBySession = new ConcurrentHashMap<>();
    private final int maxMessagesPerSecond;
    private final int maxUnknownCodes;
    /** Kopfzeile mit der echten Adresse hinter einem Proxy (z. B. X-Forwarded-For), leer = Socket-Adresse. */
    private final String clientIpHeader;

    public GameSocketHandler(RoomRegistry rooms, JsonMapper json, TaskScheduler scheduler,
                             @Value("${app.limits.messages-per-second}") int maxMessagesPerSecond,
                             @Value("${app.limits.unknown-codes}") int maxUnknownCodes,
                             @Value("${app.client-ip-header:}") String clientIpHeader) {
        this.rooms = rooms;
        this.json = json;
        this.scheduler = scheduler;
        this.maxMessagesPerSecond = maxMessagesPerSecond;
        this.maxUnknownCodes = maxUnknownCodes;
        this.clientIpHeader = clientIpHeader;
    }

    @Override
    public void afterConnectionEstablished(@NonNull WebSocketSession session) {
        // Der Decorator sorgt dafür, dass zwei Threads nicht gleichzeitig in dieselbe Verbindung schreiben
        sessions.put(session.getId(), new ConcurrentWebSocketSessionDecorator(session, 5_000, 64 * 1024));
        guardsBySession.put(session.getId(), new ConnectionGuard(Clock.systemUTC(), maxMessagesPerSecond, maxUnknownCodes));
        addressesBySession.put(session.getId(), clientAddress(session));
    }

    @Override
    protected void handleTextMessage(@NonNull WebSocketSession rawSession, @NonNull TextMessage message) {
        WebSocketSession session = sessions.getOrDefault(rawSession.getId(), rawSession);
        ConnectionGuard guard = guardsBySession.get(session.getId());
        if (guard != null && !guard.allowMessage()) {
            log.warn("Verbindung wegen zu vieler Nachrichten geschlossen");
            closeForAbuse(session);
            return;
        }
        ClientMessage msg = parse(message);
        if (msg == null) {
            sendUnexpectedError(session);
            return;
        }

        if (msg.language() != null) {
            languagesBySession.put(session.getId(), Language.parse(msg.language()));
        }
        try {
            handle(session, msg);
        } catch (GameException e) {
            send(session, Map.of("type", "error", "message", e.messageIn(languageOf(session)), "key", e.key()));
            if ("error.rooms.unknown".equals(e.key()) && guard != null && !guard.allowUnknownCode()) {
                log.warn("Verbindung wegen zu vieler unbekannter Raumcodes geschlossen");
                closeForAbuse(session);
            }
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
        send(session, Map.of("type", "error", "message", Text.of("error.unexpected").in(languageOf(session))));
    }

    private void handle(WebSocketSession session, ClientMessage msg) {
        String type = msg.type() == null ? "" : msg.type();
        switch (type) {
            case "ping" -> send(session, Map.of("type", "pong"));

            case "create" -> {
                Room room = rooms.createRoom(addressesBySession.get(session.getId()));
                try {
                    Player player = room.addPlayer(msg.name());
                    room.setLanguage(player.id(), languageOf(session));
                    sitDown(session, room, player);
                } catch (GameException e) {
                    rooms.removeIfEmpty(room);
                    throw e;
                }
            }

            case "join" -> {
                Room room = rooms.require(msg.code());
                Player player = room.addPlayer(msg.name());
                room.setLanguage(player.id(), languageOf(session));
                sitDown(session, room, player);
            }

            case "rejoin" -> {
                Room room = rooms.require(msg.code());
                Player player = room.findBySecret(msg.secret())
                        .orElseThrow(() -> new GameException("error.room.notInRoom"));
                room.setConnected(player.id(), true);
                room.setLanguage(player.id(), languageOf(session));
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

            case "setLanguage" -> {
                // Auf der Startseite gibt es noch keinen Raum, dann reicht die gemerkte Sprache
                if (seatsBySession.containsKey(session.getId())) {
                    withRoom(session, (room, playerId) -> room.setLanguage(playerId, languageOf(session)));
                }
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
                    throw new GameException("error.impostor.countMissing");
                }
                withRoom(session, (room, playerId) -> room.setImpostorOptions(
                        playerId, msg.impostorCount(), Boolean.TRUE.equals(msg.randomStartPlayer())));
            }
            case "configureWerwolf" -> withRoom(session, (room, playerId) -> room.configureWerwolf(
                    playerId, msg.werewolfCount(), msg.roles(), Boolean.TRUE.equals(msg.hostIsGameMaster())));
            case "configureTabu" -> {
                if (msg.turnSeconds() == null || msg.teamCount() == null || msg.targetScore() == null) {
                    throw new GameException("error.tabu.settingsMissing");
                }
                withRoom(session, (room, playerId) -> room.configureTabu(playerId, msg.turnSeconds(),
                        Boolean.TRUE.equals(msg.autoTeams()), msg.teamCount(), msg.targetScore()));
            }
            case "chooseTeam" -> {
                if (msg.team() == null) {
                    throw new GameException("error.tabu.teamMissing");
                }
                withRoom(session, (room, playerId) -> room.chooseTeam(playerId, msg.targetId(), msg.team()));
            }
            case "startTurn" -> withRoom(session, (room, playerId) -> {
                room.startTurn(playerId);
                scheduleTurnEnd(room);
            });
            case "wordCorrect" -> withRoom(session, Room::wordCorrect);
            case "wordSkip" -> withRoom(session, Room::wordSkip);
            case "buzz" -> withRoom(session, Room::buzz);
            case "configureNobodyIsPerfect" -> {
                if (msg.questionCount() == null) {
                    throw new GameException("error.nip.countMissing");
                }
                withRoom(session, (room, playerId) -> room.configureNobodyIsPerfect(playerId, msg.questionCount()));
            }
            case "submitAnswer" -> withRoom(session, (room, playerId) -> room.submitAnswer(playerId, msg.answer()));
            case "guessAnswer" -> withRoom(session, (room, playerId) -> room.guessAnswer(playerId, msg.choice()));
            case "skipWaiting" -> withRoom(session, Room::skipWaiting);
            case "nextQuestion" -> withRoom(session, Room::nextQuestion);
            case "configureBuzzer" -> withRoom(session,
                    (room, playerId) -> room.configureBuzzer(playerId, Boolean.TRUE.equals(msg.lockout())));
            case "pressBuzzer" -> withRoom(session, Room::pressBuzzer);
            case "releaseBuzzer" -> withRoom(session, Room::releaseBuzzer);
            case "configureGeoBingo" -> {
                if (msg.minutes() == null) {
                    throw new GameException("error.geoBingo.minutesMissing");
                }
                withRoom(session, (room, playerId) -> room.configureGeoBingo(playerId, msg.minutes()));
            }
            case "claimGeoBingoField" -> {
                if (msg.field() == null || msg.x() == null || msg.y() == null || msg.zoom() == null) {
                    throw new GameException("error.geoBingo.claimMissing");
                }
                GeoBingoGame.Spot spot = new GeoBingoGame.Spot(msg.imageId(), msg.x(), msg.y(), msg.zoom());
                withRoom(session, (room, playerId) -> {
                    room.claimGeoBingoField(playerId, msg.field(), spot);
                    scheduleGeoBingo(room);
                });
            }
            case "voteGeoBingo" -> {
                if (msg.accept() == null) {
                    throw new GameException("error.geoBingo.voteMissing");
                }
                withRoom(session, (room, playerId) -> room.voteGeoBingo(playerId, msg.claimId(), msg.accept()));
            }
            case "setPlayerLimit" -> {
                if (msg.playerLimit() == null) {
                    throw new GameException("error.room.playerLimitMissing");
                }
                withRoom(session, (room, playerId) -> room.setPlayerLimit(playerId, msg.playerLimit()));
            }
            case "kick" -> withRoom(session, (room, playerId) -> {
                room.kick(playerId, msg.targetId());
                sendOff(room, msg.targetId());
            });

            case "start" -> withRoom(session, (room, playerId) -> {
                room.start(playerId, rooms.random());
                scheduleGeoBingo(room);
            });
            case "nextPhase" -> withRoom(session, Room::nextPhase);
            case "startVoting" -> withRoom(session, Room::startVoting);
            case "vote" -> withRoom(session, (room, playerId) -> room.vote(playerId, msg.targetId()));
            case "nextRound" -> withRoom(session, (room, playerId) -> {
                room.nextRound(playerId, rooms.random());
                scheduleGeoBingo(room);
            });
            case "backToLobby" -> withRoom(session, Room::backToLobby);

            default -> throw new GameException("error.unknownAction", type);
        }
    }

    // Die Verbindung ist hier schon zu, die entfernten Sessions muss niemand mehr schließen
    @SuppressWarnings("resource")
    @Override
    public void afterConnectionClosed(@NonNull WebSocketSession session, @NonNull CloseStatus status) {
        sessions.remove(session.getId());
        languagesBySession.remove(session.getId());
        guardsBySession.remove(session.getId());
        addressesBySession.remove(session.getId());
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

    private void scheduleTurnEnd(Room room) {
        room.tabuTurnEndsAt().ifPresent(endsAt -> scheduler.schedule(() -> {
            if (room.expireTabuTurn()) {
                broadcast(room);
            }
        }, endsAt));
    }

    /**
     * Weckt sich zur nächsten Geo-Bingo-Frist (Abstimmung oder Spielende). Jede Meldung plant ihre eigene
     * Frist, doppelte Weckrufe schaden nicht, weil {@link Room#expireGeoBingo()} dann nichts ändert.
     */
    private void scheduleGeoBingo(Room room) {
        room.geoBingoDeadline().ifPresent(at -> scheduler.schedule(() -> {
            if (room.expireGeoBingo()) {
                broadcast(room);
                scheduleGeoBingo(room);
            }
        }, at));
    }

    private static GameType parseGameType(String raw) {
        try {
            return GameType.valueOf(raw == null ? "" : raw.strip().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new GameException("error.unknownGame");
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

    private Language languageOf(WebSocketSession session) {
        return languagesBySession.getOrDefault(session.getId(), Language.DE);
    }

    /**
     * Hinter einem Proxy steht die echte Adresse in einer Kopfzeile. Genommen wird der erste Eintrag:
     * Ist er gefälscht, greift nur das Raumlimit nicht. Der letzte Eintrag könnte dagegen die Adresse
     * des Proxys sein, dann teilten sich alle Spieler ein Limit.
     */
    private String clientAddress(WebSocketSession session) {
        if (!clientIpHeader.isBlank()) {
            String forwarded = session.getHandshakeHeaders().getFirst(clientIpHeader);
            if (forwarded != null && !forwarded.isBlank()) {
                return forwarded.split(",")[0].strip();
            }
        }
        InetSocketAddress remote = session.getRemoteAddress();
        return remote == null ? "unbekannt" : remote.getHostString();
    }

    private void closeForAbuse(WebSocketSession session) {
        try {
            session.close(CloseStatus.POLICY_VIOLATION);
        } catch (IOException e) {
            log.debug("Konnte Verbindung {} nicht schließen", session.getId(), e);
        }
    }

    private void sitDown(WebSocketSession session, Room room, Player player) {
        ConnectionGuard guard = guardsBySession.get(session.getId());
        if (guard != null) {
            guard.joined();
        }
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
            throw new GameException("error.noRoom");
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
