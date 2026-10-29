package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.ImpostorWords.SecretWord;

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
 * Ein Spielraum. Er verwaltet die Lobby (Spieler, Host, Spielauswahl, Bereit) und gibt
 * Spielaktionen an das laufende {@link Game} weiter.
 *
 * <p>Alle Methoden sind synchronized, weil mehrere Handys gleichzeitig Nachrichten schicken
 * können. Für ein paar Freunde ist das mehr als schnell genug.
 */
public class Room {

    public static final int MAX_PLAYERS = 20;
    public static final int DEFAULT_PLAYER_LIMIT = 7;
    /** Kleiner darf der Host das Limit nicht stellen, sonst passt kein Spiel mehr rein. */
    public static final int MIN_PLAYER_LIMIT = 3;
    public static final int MAX_NAME_LENGTH = 20;
    public static final int MAX_WORD_LENGTH = 30;

    private final String code;
    private final Clock clock;
    private final Map<String, Player> players = new LinkedHashMap<>(); // Reihenfolge = Beitrittsreihenfolge
    private final List<String> usedWords = new ArrayList<>();
    private String hostId;
    private GameType selectedGame = GameType.IMPOSTOR;
    private int playerLimit = DEFAULT_PLAYER_LIMIT;
    private boolean impostorSeesCategory = true;
    /** Aus diesen Kategorien kommen die Impostor-Wörter. Reihenfolge wie in der Wortliste. */
    private List<String> impostorCategories = ImpostorWords.categoryNames();
    /** Vom Host vorgegebenes Wort für die nächste Impostor-Runde, sonst {@code null}. */
    private String customWord;
    /** {@code null}, solange alle in der Lobby sind. */
    private Game game;
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
        return game == null ? Phase.LOBBY : game.phase();
    }

    public synchronized int round() {
        return game == null ? 0 : game.round();
    }

    public synchronized Game game() {
        return game;
    }

    public synchronized GameType selectedGame() {
        return selectedGame;
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

    // ---- Spieler -------------------------------------------------------

    public synchronized Player addPlayer(String rawName) {
        if (game != null) {
            throw new GameException("Das Spiel läuft schon. Warte, bis alle zurück in der Lobby sind.");
        }
        if (players.size() >= playerLimit) {
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
        if (game != null) {
            setConnected(playerId, false);
            return;
        }
        players.remove(player.id());
        if (playerId.equals(hostId)) {
            hostId = firstPlayerId();
        }
        touch();
    }

    /** Host wirft jemanden raus. Nur in der Lobby, damit keine laufende Runde kaputtgeht. */
    public synchronized void kick(String requesterId, String targetId) {
        requireHost(requesterId);
        requireLobby();
        if (requesterId.equals(targetId)) {
            throw new GameException("Du kannst dich nicht selbst entfernen.");
        }
        players.remove(require(targetId).id());
        touch();
    }

    public synchronized void setPlayerLimit(String requesterId, int limit) {
        requireHost(requesterId);
        int lowest = lowestPlayerLimit();
        if (limit < lowest || limit > MAX_PLAYERS) {
            throw new GameException("Das Spielerlimit muss zwischen " + lowest + " und " + MAX_PLAYERS + " liegen.");
        }
        playerLimit = limit;
        touch();
    }

    public synchronized int playerLimit() {
        return playerLimit;
    }

    public synchronized void setConnected(String playerId, boolean connected) {
        Player player = players.get(playerId);
        if (player == null) {
            return;
        }
        player.setConnected(connected);
        // Wer offline geht, soll eine laufende Abstimmung nicht blockieren
        if (game instanceof ImpostorGame impostor) {
            impostor.closeVotingIfComplete();
        }
        touch();
    }

    public synchronized void setReady(String playerId, boolean ready) {
        Player player = require(playerId);
        if (game != null && !game.betweenRounds()) {
            throw new GameException("Gerade läuft eine Runde.");
        }
        player.setReady(ready);
        touch();
    }

    // ---- Lobby: Spielauswahl -------------------------------------------

    public synchronized void selectGame(String requesterId, GameType type) {
        requireHost(requesterId);
        requireLobby();
        if (type != selectedGame) {
            selectedGame = type;
            resetReady();
        }
        touch();
    }

    /** Ein leeres {@code rawCustomWord} bedeutet: Wort aus der eingebauten Liste nehmen. */
    public synchronized void configureImpostor(String requesterId, boolean seesCategory, String rawCustomWord) {
        requireHost(requesterId);
        requireLobby();
        String word = cleanWord(rawCustomWord);
        boolean changed = seesCategory != impostorSeesCategory || !Optional.ofNullable(word).equals(Optional.ofNullable(customWord));
        impostorSeesCategory = seesCategory;
        customWord = word;
        if (changed) {
            resetReady();
        }
        touch();
    }

    public synchronized void setImpostorCategories(String requesterId, List<String> categories) {
        requireHost(requesterId);
        requireLobby();
        if (categories == null || categories.isEmpty()) {
            throw new GameException("Bitte wähle mindestens eine Kategorie.");
        }
        List<String> known = ImpostorWords.categoryNames();
        if (!known.containsAll(categories)) {
            throw new GameException("Diese Kategorie gibt es nicht.");
        }
        List<String> selected = known.stream().filter(categories::contains).toList();
        if (!selected.equals(impostorCategories)) {
            impostorCategories = selected;
            resetReady();
        }
        touch();
    }

    // ---- Spielablauf ---------------------------------------------------

    public synchronized void start(String requesterId, RandomGenerator random) {
        requireHost(requesterId);
        if (game != null) {
            throw new GameException("Das Spiel läuft schon.");
        }
        requireStartable();
        game = switch (selectedGame) {
            case WERWOLF -> new WerwolfGame(new ArrayList<>(players.values()), random);
            case IMPOSTOR -> newImpostorRound(1, random);
        };
        resetReady();
        touch();
    }

    /** Werwolf: zwischen Nacht und Tag umschalten. */
    public synchronized void nextPhase(String requesterId) {
        requireHost(requesterId);
        requireGame(WerwolfGame.class).nextPhase();
        touch();
    }

    /** Impostor: Hinweise sind gegeben, jetzt wird abgestimmt. */
    public synchronized void startVoting(String requesterId) {
        requireHost(requesterId);
        requireGame(ImpostorGame.class).startVoting();
        touch();
    }

    public synchronized void vote(String playerId, String targetId) {
        require(playerId);
        requireGame(ImpostorGame.class).vote(playerId, targetId);
        touch();
    }

    /** Impostor: neue Runde mit neuem Wort, wenn alle bereit sind. */
    public synchronized void nextRound(String requesterId, RandomGenerator random) {
        requireHost(requesterId);
        ImpostorGame current = requireGame(ImpostorGame.class);
        if (!current.betweenRounds()) {
            throw new GameException("Die Runde ist noch nicht vorbei.");
        }
        requireStartable();
        game = newImpostorRound(current.round() + 1, random);
        resetReady();
        touch();
    }

    /** Zurück in die Lobby, z. B. um ein anderes Spiel zu wählen. */
    public synchronized void backToLobby(String requesterId) {
        requireHost(requesterId);
        players.values().removeIf(p -> !p.connected());
        players.values().forEach(p -> p.setAlive(true));
        if (!players.containsKey(hostId)) {
            hostId = firstPlayerId();
        }
        game = null;
        resetReady();
        touch();
    }

    // ---- Ansicht -------------------------------------------------------

    /** Baut die Ansicht für genau einen Spieler. Fremde Rollen und Wörter stehen hier nie drin. */
    public synchronized RoomView viewFor(String playerId) {
        Player me = require(playerId);
        boolean isHost = me.id().equals(hostId);

        List<RoomView.PlayerView> publicPlayers = players.values().stream()
                .map(p -> new RoomView.PlayerView(p.id(), p.name(), p.alive(), p.connected(), p.ready()))
                .toList();

        boolean canChooseNext = game == null || game.betweenRounds();
        String startHint = canChooseNext ? startBlocker() : null;

        RoomView.ImpostorSettings settings = new RoomView.ImpostorSettings(
                impostorSeesCategory, customWord != null, isHost ? customWord : null,
                ImpostorWords.categoryNames(), impostorCategories);

        return new RoomView(
                code,
                selectedGame,
                RoomView.GameOption.all(),
                settings,
                new RoomView.PlayerLimit(playerLimit, lowestPlayerLimit(), MAX_PLAYERS),
                phase(),
                round(),
                hostId,
                publicPlayers,
                canChooseNext && startHint == null,
                startHint,
                new RoomView.You(me.id(), me.name(), isHost, me.ready()),
                game instanceof WerwolfGame werwolf ? werwolf.viewFor(me.id()) : null,
                game instanceof ImpostorGame impostor ? impostor.viewFor(me.id()) : null);
    }

    // ---- Hilfsmethoden -------------------------------------------------

    /** Warum noch nicht gestartet werden kann, oder {@code null}, wenn alles passt. */
    private String startBlocker() {
        boolean hostSitsOut = selectedGame == GameType.IMPOSTOR && customWord != null;
        int playing = players.size() - (hostSitsOut ? 1 : 0);
        int missing = selectedGame.minPlayers() - playing;
        if (missing > 0) {
            return hostSitsOut
                    ? "Noch " + missing + " Spieler (ohne Spielleitung), dann kann es losgehen."
                    : "Noch " + missing + " Spieler, dann kann es losgehen.";
        }

        List<Player> online = players.values().stream().filter(Player::connected).toList();
        long ready = online.stream().filter(Player::ready).count();
        if (ready < online.size()) {
            return "Warte, bis alle bereit sind (" + ready + " von " + online.size() + ").";
        }
        return null;
    }

    private int lowestPlayerLimit() {
        return Math.max(MIN_PLAYER_LIMIT, players.size());
    }

    private void requireStartable() {
        String blocker = startBlocker();
        if (blocker != null) {
            throw new GameException(blocker);
        }
    }

    private ImpostorGame newImpostorRound(int round, RandomGenerator random) {
        String gameMasterId = customWord != null ? hostId : null;
        SecretWord secret = customWord != null
                ? new SecretWord(customWord, null)
                : ImpostorWords.pick(random, usedWords, impostorCategories);

        List<Player> participants = players.values().stream()
                .filter(p -> !p.id().equals(gameMasterId))
                .toList();
        ImpostorGame next = new ImpostorGame(participants, gameMasterId, secret, impostorSeesCategory, round, random);

        // Ein eigenes Wort gilt nur für eine Runde, danach spielt der Host wieder mit
        customWord = null;
        usedWords.add(secret.word());
        return next;
    }

    private <T extends Game> T requireGame(Class<T> type) {
        if (!type.isInstance(game)) {
            throw new GameException("Das geht in diesem Spiel gerade nicht.");
        }
        return type.cast(game);
    }

    private void requireLobby() {
        if (game != null) {
            throw new GameException("Das geht nur in der Lobby.");
        }
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

    private void resetReady() {
        players.values().forEach(p -> p.setReady(false));
    }

    private String firstPlayerId() {
        return players.isEmpty() ? null : players.keySet().iterator().next();
    }

    private void touch() {
        lastActivity = clock.instant();
    }

    /**
     * Entfernt Steuerzeichen und unsichtbare Zeichen (z. B. Zero-Width-Space, Schreibrichtungs-Umkehr),
     * damit sich niemand mit "Anna" plus unsichtbarem Zeichen als Anna ausgeben kann.
     * Jede Art von Leerraum wird zu einem normalen Leerzeichen.
     */
    static String normalizeText(String raw) {
        if (raw == null) {
            return "";
        }
        return raw.replaceAll("[\\p{Cc}\\p{Cf}\\p{Co}\\p{Cn}&&[^\\s]]", "")
                .replaceAll("[\\s\\p{Z}]+", " ")
                .strip();
    }

    static String cleanName(String rawName) {
        String name = normalizeText(rawName);
        if (name.isEmpty()) {
            throw new GameException("Bitte gib einen Namen ein.");
        }
        if (name.length() > MAX_NAME_LENGTH) {
            throw new GameException("Der Name darf höchstens " + MAX_NAME_LENGTH + " Zeichen lang sein.");
        }
        return name;
    }

    /** Leeres Wort → {@code null}, also eingebaute Liste. */
    static String cleanWord(String rawWord) {
        String word = normalizeText(rawWord);
        if (word.isEmpty()) {
            return null;
        }
        if (word.length() > MAX_WORD_LENGTH) {
            throw new GameException("Das Wort darf höchstens " + MAX_WORD_LENGTH + " Zeichen lang sein.");
        }
        return word;
    }
}
