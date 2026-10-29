package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.ImpostorWords.SecretWord;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
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
    private ImpostorOptions impostorOptions = ImpostorOptions.DEFAULT;
    /** Aus diesen Kategorien kommen die Impostor-Wörter. Reihenfolge wie in der Wortliste. */
    private List<String> impostorCategories = ImpostorWords.categoryNames();
    /** Vom Host vorgegebenes Wort für die nächste Impostor-Runde, sonst {@code null}. */
    private String customWord;
    /** {@code null} heißt: automatisch passend zur Spielerzahl. */
    private Integer werewolfCount;
    private List<String> werwolfRoles = List.of(WerwolfRoles.SEER);
    private boolean werwolfHostIsGameMaster;
    private TabuOptions tabuOptions = TabuOptions.DEFAULT;
    /** Selbst gewählte Teams (Spieler-ID → Team-Nummer), nur wenn die Teams nicht automatisch sind. */
    private final Map<String, Integer> chosenTeams = new HashMap<>();
    private NobodyIsPerfectOptions nobodyIsPerfectOptions = NobodyIsPerfectOptions.DEFAULT;
    /** Nobody-is-Perfect-Fragen, die in diesem Raum schon dran waren. */
    private final List<String> usedQuestions = new ArrayList<>();
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
        chosenTeams.remove(player.id());
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
        chosenTeams.remove(targetId);
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
        if (game instanceof NobodyIsPerfectGame nobodyIsPerfect) {
            nobodyIsPerfect.closeStageIfComplete();
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
        ImpostorOptions options = impostorOptions.withImpostorSeesCategory(seesCategory);
        boolean changed = !options.equals(impostorOptions) || !Optional.ofNullable(word).equals(Optional.ofNullable(customWord));
        impostorOptions = options;
        customWord = word;
        if (changed) {
            resetReady();
        }
        touch();
    }

    public synchronized void setImpostorOptions(String requesterId, int impostorCount, boolean randomStartPlayer) {
        requireHost(requesterId);
        requireLobby();
        ImpostorOptions options = new ImpostorOptions(impostorCount, impostorOptions.impostorSeesCategory(), randomStartPlayer);
        if (!options.equals(impostorOptions)) {
            impostorOptions = options;
            resetReady();
        }
        touch();
    }

    /** {@code count} ist {@code null} für eine automatische Anzahl Werwölfe. */
    public synchronized void configureWerwolf(String requesterId, Integer count, List<String> roles, boolean hostIsGameMaster) {
        requireHost(requesterId);
        requireLobby();
        if (count != null && (count < 1 || count >= MAX_PLAYERS)) {
            throw new GameException("Es kann 1 bis " + (MAX_PLAYERS - 1) + " Werwölfe geben.");
        }
        List<String> selected = WerwolfRoles.normalizeSpecialRoles(roles);
        boolean changed = !Objects.equals(count, werewolfCount) || !selected.equals(werwolfRoles)
                || hostIsGameMaster != werwolfHostIsGameMaster;
        werewolfCount = count;
        werwolfRoles = selected;
        werwolfHostIsGameMaster = hostIsGameMaster;
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

    public synchronized void configureTabu(String requesterId, int turnSeconds, boolean autoTeams,
                                                 int teamCount, int targetScore) {
        requireHost(requesterId);
        requireLobby();
        TabuOptions options = new TabuOptions(turnSeconds, autoTeams, teamCount, targetScore);
        if (!options.equals(tabuOptions)) {
            tabuOptions = options;
            chosenTeams.values().removeIf(team -> team >= teamCount);
            resetReady();
        }
        touch();
    }

    public synchronized void configureNobodyIsPerfect(String requesterId, int questionCount) {
        requireHost(requesterId);
        requireLobby();
        NobodyIsPerfectOptions options = new NobodyIsPerfectOptions(questionCount);
        if (!options.equals(nobodyIsPerfectOptions)) {
            nobodyIsPerfectOptions = options;
            resetReady();
        }
        touch();
    }

    /** Jeder wählt sein Team selbst. Der Host darf auch andere verschieben ({@code targetId}). */
    public synchronized void chooseTeam(String requesterId, String targetId, int team) {
        require(requesterId);
        requireLobby();
        String playerId = targetId == null ? requesterId : targetId;
        if (!playerId.equals(requesterId)) {
            requireHost(requesterId);
        }
        require(playerId);
        if (team < 0 || team >= tabuOptions.teamCount()) {
            throw new GameException("Dieses Team gibt es nicht.");
        }
        chosenTeams.put(playerId, team);
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
            case WERWOLF -> {
                String gameMasterId = hostSitsOut() ? hostId : null;
                yield new WerwolfGame(playersExcept(gameMasterId), gameMasterId, werewolfCount, werwolfRoles, random);
            }
            case IMPOSTOR -> newImpostorRound(1, random);
            case TABU -> new TabuGame(tabuTeams(random), tabuOptions, random);
            case NOBODY_IS_PERFECT -> newNobodyIsPerfect(random);
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

    /** Impostor: neue Runde mit neuem Wort. Tabu, Nobody is Perfect: neues Spiel. Alles erst, wenn alle bereit sind. */
    public synchronized void nextRound(String requesterId, RandomGenerator random) {
        requireHost(requesterId);
        if (game == null || !game.betweenRounds()) {
            throw new GameException("Die Runde ist noch nicht vorbei.");
        }
        requireStartable();
        game = switch (game) {
            case ImpostorGame impostor -> newImpostorRound(impostor.round() + 1, random);
            case TabuGame ignored -> new TabuGame(tabuTeams(random), tabuOptions, random);
            case NobodyIsPerfectGame ignored -> newNobodyIsPerfect(random);
            case WerwolfGame ignored -> throw new GameException("Das geht in diesem Spiel gerade nicht.");
        };
        resetReady();
        touch();
    }

    // ---- Nobody is Perfect ---------------------------------------------

    public synchronized void submitAnswer(String requesterId, String answer) {
        require(requesterId);
        requireGame(NobodyIsPerfectGame.class).submitAnswer(requesterId, answer);
        touch();
    }

    public synchronized void guessAnswer(String requesterId, String choiceId) {
        require(requesterId);
        requireGame(NobodyIsPerfectGame.class).guess(requesterId, choiceId);
        touch();
    }

    /** Spielleitung: nicht länger auf die warten, die noch schreiben oder tippen. */
    public synchronized void skipWaiting(String requesterId) {
        requireHost(requesterId);
        requireGame(NobodyIsPerfectGame.class).skipWaiting();
        touch();
    }

    public synchronized void nextQuestion(String requesterId) {
        requireHost(requesterId);
        requireGame(NobodyIsPerfectGame.class).nextQuestion();
        touch();
    }

    private NobodyIsPerfectGame newNobodyIsPerfect(RandomGenerator random) {
        List<NobodyIsPerfectQuestions.Question> questions =
                NobodyIsPerfectQuestions.pick(nobodyIsPerfectOptions.questionCount(), usedQuestions, random);
        questions.forEach(q -> usedQuestions.add(q.question()));
        return new NobodyIsPerfectGame(List.copyOf(players.values()), questions, random);
    }

    // ---- Tabu ----------------------------------------------------

    public synchronized void startTurn(String requesterId) {
        require(requesterId);
        TabuGame tabu = requireGame(TabuGame.class);
        tabu.startTurn(requesterId, requesterId.equals(hostId), clock.instant());
        touch();
    }

    public synchronized void wordCorrect(String requesterId) {
        runningTabu(requesterId).ifPresent(g -> g.correct(requesterId));
    }

    public synchronized void wordSkip(String requesterId) {
        runningTabu(requesterId).ifPresent(g -> g.skip(requesterId));
    }

    public synchronized void buzz(String requesterId) {
        runningTabu(requesterId).ifPresent(g -> g.buzz(requesterId));
    }

    /** Für die Uhr im Server: beendet den Zug, wenn die Zeit um ist. {@code true}, wenn sich etwas geändert hat. */
    public synchronized boolean expireTabuTurn() {
        return game instanceof TabuGame tabu && tabu.expireTurn(clock.instant());
    }

    /** Wann der laufende Zug endet, falls gerade einer läuft. */
    public synchronized Optional<Instant> tabuTurnEndsAt() {
        return game instanceof TabuGame tabu ? Optional.ofNullable(tabu.turnEndsAt()) : Optional.empty();
    }

    /**
     * Ist die Zeit schon um, endet zuerst der Zug und der Knopfdruck kommt zu spät ({@code empty}).
     * Sonst gibt es das Spiel zurück, damit die Aktion ausgeführt wird.
     */
    private Optional<TabuGame> runningTabu(String requesterId) {
        require(requesterId);
        TabuGame tabu = requireGame(TabuGame.class);
        touch();
        return tabu.expireTurn(clock.instant()) ? Optional.empty() : Optional.of(tabu);
    }

    private List<List<Player>> tabuTeams(RandomGenerator random) {
        int teamCount = tabuOptions.teamCount();
        List<List<Player>> teams = new ArrayList<>();
        for (int i = 0; i < teamCount; i++) {
            teams.add(new ArrayList<>());
        }
        List<Player> all = new ArrayList<>(players.values());
        if (tabuOptions.autoTeams()) {
            Shuffle.inPlace(all, random);
            for (int i = 0; i < all.size(); i++) {
                teams.get(i % teamCount).add(all.get(i));
            }
        } else {
            all.forEach(p -> teams.get(chosenTeams.get(p.id())).add(p));
        }
        return teams;
    }

    /** Spieler-IDs pro Team, so wie sie gerade gewählt sind. */
    private List<List<String>> chosenTeamIds() {
        List<List<String>> teams = new ArrayList<>();
        for (int i = 0; i < tabuOptions.teamCount(); i++) {
            int team = i;
            teams.add(players.keySet().stream().filter(id -> Integer.valueOf(team).equals(chosenTeams.get(id))).toList());
        }
        return teams;
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

        RoomView.ImpostorSettings impostorSettings = new RoomView.ImpostorSettings(
                impostorOptions.impostorSeesCategory(), customWord != null, isHost ? customWord : null,
                ImpostorWords.categoryNames(), impostorCategories,
                impostorOptions.impostorCount(), ImpostorOptions.MAX_IMPOSTORS, impostorOptions.randomStartPlayer());

        int werwolfPlayers = players.size() - (werwolfHostIsGameMaster ? 1 : 0);
        RoomView.WerwolfSettings werwolfSettings = new RoomView.WerwolfSettings(
                werewolfCount, RoleDistribution.werewolves(werwolfPlayers, werewolfCount),
                WerwolfRoles.specialRoles().stream().map(RoomView.RoleCard::of).toList(),
                werwolfRoles, werwolfHostIsGameMaster);

        RoomView.TabuSettings tabuSettings = new RoomView.TabuSettings(
                tabuOptions.turnSeconds(), tabuOptions.autoTeams(), tabuOptions.teamCount(),
                tabuOptions.targetScore(), chosenTeamIds());

        return new RoomView(
                code,
                selectedGame,
                RoomView.GameOption.all(),
                impostorSettings,
                werwolfSettings,
                tabuSettings,
                new RoomView.NobodyIsPerfectSettings(nobodyIsPerfectOptions.questionCount()),
                new RoomView.PlayerLimit(playerLimit, lowestPlayerLimit(), MAX_PLAYERS),
                phase(),
                round(),
                hostId,
                publicPlayers,
                canChooseNext && startHint == null,
                startHint,
                new RoomView.You(me.id(), me.name(), isHost, me.ready()),
                game instanceof WerwolfGame werwolf ? werwolf.viewFor(me.id()) : null,
                game instanceof ImpostorGame impostor ? impostor.viewFor(me.id()) : null,
                game instanceof TabuGame tabu ? tabu.viewFor(me.id(), clock.instant()) : null,
                game instanceof NobodyIsPerfectGame nobodyIsPerfect ? nobodyIsPerfect.viewFor(me.id()) : null);
    }

    // ---- Hilfsmethoden -------------------------------------------------

    /** Warum noch nicht gestartet werden kann, oder {@code null}, wenn alles passt. */
    private String startBlocker() {
        boolean hostSitsOut = hostSitsOut();
        int playing = players.size() - (hostSitsOut ? 1 : 0);
        int missing = selectedGame.minPlayers() - playing;
        if (missing > 0) {
            return hostSitsOut
                    ? "Noch " + missing + " Spieler (ohne Spielleitung), dann kann es losgehen."
                    : "Noch " + missing + " Spieler, dann kann es losgehen.";
        }
        String settingsProblem = switch (selectedGame) {
            case WERWOLF -> RoleDistribution.problem(playing, werewolfCount, werwolfRoles);
            case IMPOSTOR -> impostorOptions.problem(playing);
            case TABU -> tabuProblem();
            case NOBODY_IS_PERFECT -> null;
        };
        if (settingsProblem != null) {
            return settingsProblem;
        }

        List<Player> online = players.values().stream().filter(Player::connected).toList();
        long ready = online.stream().filter(Player::ready).count();
        if (ready < online.size()) {
            return "Warte, bis alle bereit sind (" + ready + " von " + online.size() + ").";
        }
        return null;
    }

    private String tabuProblem() {
        List<Integer> sizes = chosenTeamIds().stream().map(List::size).toList();
        int unassigned = players.size() - sizes.stream().mapToInt(Integer::intValue).sum();
        return tabuOptions.problem(players.size(), sizes, unassigned);
    }

    /** Spielt der Host diesmal nicht mit, weil er ein eigenes Wort gewählt hat oder Werwolf leitet? */
    private boolean hostSitsOut() {
        return switch (selectedGame) {
            case IMPOSTOR -> customWord != null;
            case WERWOLF -> werwolfHostIsGameMaster;
            case TABU, NOBODY_IS_PERFECT -> false;
        };
    }

    private List<Player> playersExcept(String playerId) {
        return players.values().stream().filter(p -> !p.id().equals(playerId)).toList();
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

        ImpostorGame next = new ImpostorGame(playersExcept(gameMasterId), gameMasterId, secret, impostorOptions, round, random);

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
