package de.kruschinski.werwolf.game;

import de.kruschinski.werwolf.game.ImpostorWords.SecretWord;
import de.kruschinski.werwolf.i18n.Language;
import de.kruschinski.werwolf.i18n.Text;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
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
    /** Spiele, die man noch nicht wählen kann ("Bald verfügbar"). */
    private final Set<GameType> lockedGames;
    private final Map<String, Player> players = new LinkedHashMap<>(); // Reihenfolge = Beitrittsreihenfolge
    private final List<String> usedWords = new ArrayList<>();
    private String hostId;
    private GameType selectedGame = GameType.IMPOSTOR;
    private int playerLimit = DEFAULT_PLAYER_LIMIT;
    private ImpostorOptions impostorOptions = ImpostorOptions.DEFAULT;
    /** IDs der Kategorien, aus denen die Impostor-Wörter kommen. Reihenfolge wie in der Wortliste. */
    private List<String> impostorCategories = ImpostorWords.categoryIds();
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
    private boolean buzzerLockout = true;
    private GeoBingoOptions geoBingoOptions = GeoBingoOptions.DEFAULT;
    /** Geo-Bingo-Orte, die in diesem Raum schon dran waren. */
    private final List<String> usedPlaces = new ArrayList<>();
    /** Gemeinsames Tageslimit aller Räume für Google Street View. */
    private final StreetViewBudget streetViewBudget;
    /**
     * Spieler, für die schon ein Google-Viewer gebucht ist. Die App behält ihren Viewer über alle Runden
     * und springt nur zur nächsten Stadt, deshalb zählt jeder Spieler pro Raum nur einmal.
     */
    private final Set<String> googleViewers = new HashSet<>();
    /** {@code null}, solange alle in der Lobby sind. */
    private Game game;
    private int nextPlayerNumber = 1;
    private Instant lastActivity;

    public Room(String code, Clock clock) {
        this(code, clock, Set.of());
    }

    public Room(String code, Clock clock, Set<GameType> lockedGames) {
        this(code, clock, lockedGames, StreetViewBudget.off());
    }

    public Room(String code, Clock clock, Set<GameType> lockedGames, StreetViewBudget streetViewBudget) {
        this.code = code;
        this.clock = clock;
        this.lockedGames = Set.copyOf(lockedGames);
        this.streetViewBudget = streetViewBudget;
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

    /** Sitzt noch jemand mit offener Verbindung im Raum? Verlassene Räume bleiben bis zum Aufräumen stehen. */
    public synchronized boolean hasConnectedPlayers() {
        return players.values().stream().anyMatch(Player::connected);
    }

    public synchronized List<Player> players() {
        return List.copyOf(players.values());
    }

    // ---- Spieler -------------------------------------------------------

    public synchronized Player addPlayer(String rawName) {
        if (game != null) {
            throw new GameException("error.room.running");
        }
        if (players.size() >= playerLimit) {
            throw new GameException("error.room.full");
        }
        String name = cleanName(rawName);
        boolean taken = players.values().stream().anyMatch(p -> p.name().equalsIgnoreCase(name));
        if (taken) {
            throw new GameException("error.name.taken", name);
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
            throw new GameException("error.room.kickSelf");
        }
        players.remove(require(targetId).id());
        chosenTeams.remove(targetId);
        touch();
    }

    public synchronized void setPlayerLimit(String requesterId, int limit) {
        requireHost(requesterId);
        int lowest = lowestPlayerLimit();
        if (limit < lowest || limit > MAX_PLAYERS) {
            throw new GameException("error.room.playerLimit", lowest, MAX_PLAYERS);
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
        if (game instanceof GeoBingoGame geoBingo) {
            geoBingo.resolveCompleteClaims();
        }
        touch();
    }

    public synchronized void setLanguage(String playerId, Language language) {
        require(playerId).setLanguage(language);
    }

    public synchronized void setReady(String playerId, boolean ready) {
        Player player = require(playerId);
        if (game != null && !game.betweenRounds()) {
            throw new GameException("error.room.roundRunning");
        }
        player.setReady(ready);
        touch();
    }

    // ---- Lobby: Spielauswahl -------------------------------------------

    public synchronized void selectGame(String requesterId, GameType type) {
        requireHost(requesterId);
        requireLobby();
        if (lockedGames.contains(type)) {
            throw new GameException(lockedHint(type));
        }
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
            throw new GameException("error.werwolf.count", MAX_PLAYERS - 1);
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
            throw new GameException("error.impostor.noCategory");
        }
        List<String> known = ImpostorWords.categoryIds();
        if (!new HashSet<>(known).containsAll(categories)) {
            throw new GameException("error.impostor.unknownCategory");
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

    public synchronized void configureBuzzer(String requesterId, boolean lockout) {
        requireHost(requesterId);
        requireLobby();
        if (lockout != buzzerLockout) {
            buzzerLockout = lockout;
            resetReady();
        }
        touch();
    }

    public synchronized void configureGeoBingo(String requesterId, int minutes, int size) {
        requireHost(requesterId);
        requireLobby();
        changeGeoBingoOptions(geoBingoOptions.withTimeAndSize(minutes, size));
    }

    /** Eigene Begriffe für die Karte, die ganze Liste auf einmal. */
    public synchronized void setGeoBingoMotifs(String requesterId, List<String> motifs) {
        requireHost(requesterId);
        requireLobby();
        changeGeoBingoOptions(geoBingoOptions.withMotifs(motifs));
    }

    private void changeGeoBingoOptions(GeoBingoOptions options) {
        if (!options.equals(geoBingoOptions)) {
            geoBingoOptions = options;
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
            throw new GameException("error.tabu.unknownTeam");
        }
        chosenTeams.put(playerId, team);
        touch();
    }

    // ---- Spielablauf ---------------------------------------------------

    public synchronized void start(String requesterId, RandomGenerator random) {
        requireHost(requesterId);
        if (game != null) {
            throw new GameException("error.room.alreadyStarted");
        }
        requireStartable();
        game = switch (selectedGame) {
            case WERWOLF -> {
                String gameMasterId = hostSitsOut() ? hostId : null;
                yield new WerwolfGame(playersExcept(gameMasterId), gameMasterId, werewolfCount, werwolfRoles, random);
            }
            case IMPOSTOR -> newImpostorRound(1, random);
            case TABU -> new TabuGame(tabuTeams(random), tabuOptions, contentLanguage(), random);
            case NOBODY_IS_PERFECT -> newNobodyIsPerfect(random);
            case BUZZER -> new BuzzerGame(playersExcept(hostId), buzzerLockout);
            case GEO_BINGO -> newGeoBingo(1, random);
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
            throw new GameException("error.room.roundNotOver");
        }
        requireStartable();
        game = switch (game) {
            case ImpostorGame impostor -> newImpostorRound(impostor.round() + 1, random);
            case TabuGame ignored -> new TabuGame(tabuTeams(random), tabuOptions, contentLanguage(), random);
            case NobodyIsPerfectGame ignored -> newNobodyIsPerfect(random);
            case GeoBingoGame geoBingo -> newGeoBingo(geoBingo.round() + 1, random);
            case WerwolfGame ignored -> throw new GameException("error.room.notNow");
            case BuzzerGame ignored -> throw new GameException("error.room.notNow");
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
                NobodyIsPerfectQuestions.pick(contentLanguage(), nobodyIsPerfectOptions.questionCount(), usedQuestions, random);
        questions.forEach(q -> usedQuestions.add(q.question()));
        return new NobodyIsPerfectGame(List.copyOf(players.values()), questions, random);
    }

    // ---- Buzzer --------------------------------------------------------

    public synchronized void pressBuzzer(String requesterId) {
        require(requesterId);
        requireGame(BuzzerGame.class).press(requesterId, clock.instant());
        touch();
    }

    /** Spielleitung: Liste leeren, alle dürfen wieder drücken. */
    public synchronized void releaseBuzzer(String requesterId) {
        requireHost(requesterId);
        requireGame(BuzzerGame.class).release();
        touch();
    }

    // ---- Geo-Bingo -----------------------------------------------------

    public synchronized void claimGeoBingoField(String requesterId, int field, GeoBingoGame.Spot spot) {
        require(requesterId);
        runningGeoBingo().claim(requesterId, field, spot, clock.instant());
        touch();
    }

    public synchronized void voteGeoBingo(String requesterId, String claimId, boolean accept) {
        require(requesterId);
        runningGeoBingo().vote(requesterId, claimId, accept);
        touch();
    }

    /** Für die Uhr im Server: beendet Abstimmungen und das Spiel pünktlich. {@code true}, wenn sich etwas geändert hat. */
    public synchronized boolean expireGeoBingo() {
        return game instanceof GeoBingoGame geoBingo && geoBingo.expire(clock.instant());
    }

    /** Wann sich im laufenden Geo-Bingo als Nächstes von selbst etwas ändert. */
    public synchronized Optional<Instant> geoBingoDeadline() {
        return game instanceof GeoBingoGame geoBingo ? Optional.ofNullable(geoBingo.nextDeadline()) : Optional.empty();
    }

    /** Erst abgelaufene Fristen abarbeiten, damit niemand nach Spielende noch etwas meldet. */
    private GeoBingoGame runningGeoBingo() {
        GeoBingoGame geoBingo = requireGame(GeoBingoGame.class);
        geoBingo.expire(clock.instant());
        return geoBingo;
    }

    private GeoBingoGame newGeoBingo(int round, RandomGenerator random) {
        GeoBingoData.Place place = GeoBingoData.pickPlace(contentLanguage(), usedPlaces, random);
        usedPlaces.add(place.name());
        int size = geoBingoOptions.size();
        List<String> board = GeoBingoData.pickMotifs(contentLanguage(), geoBingoOptions.motifs(), size * size, random);
        return new GeoBingoGame(List.copyOf(players.values()), place, streetViewSource(), board, geoBingoOptions,
                round, clock.instant());
    }

    /**
     * Google, wenn das Tageslimit noch für alle reicht, die in diesem Raum noch keinen Google-Viewer haben.
     * Sonst Mapillary für die ganze Runde, damit alle dieselben Bilder sehen und Funde zeigen können.
     */
    private StreetViewSource streetViewSource() {
        if (!streetViewBudget.enabled()) {
            return StreetViewSource.MAPILLARY;
        }
        List<String> fresh = players.keySet().stream().filter(id -> !googleViewers.contains(id)).toList();
        if (!fresh.isEmpty() && !streetViewBudget.reserve(fresh.size())) {
            return StreetViewSource.MAPILLARY;
        }
        googleViewers.addAll(fresh);
        return StreetViewSource.GOOGLE;
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
        Language language = me.language();
        boolean isHost = me.id().equals(hostId);

        List<RoomView.PlayerView> publicPlayers = players.values().stream()
                .map(p -> new RoomView.PlayerView(p.id(), p.name(), p.alive(), p.connected(), p.ready()))
                .toList();

        boolean canChooseNext = game == null || game.betweenRounds();
        Text startHint = canChooseNext ? startBlocker() : null;

        RoomView.ImpostorSettings impostorSettings = new RoomView.ImpostorSettings(
                impostorOptions.impostorSeesCategory(), customWord != null, isHost ? customWord : null,
                ImpostorWords.categoryIds(), ImpostorWords.categoryNames(language), impostorCategories,
                impostorOptions.impostorCount(), ImpostorOptions.MAX_IMPOSTORS, impostorOptions.randomStartPlayer());

        int werwolfPlayers = players.size() - (werwolfHostIsGameMaster ? 1 : 0);
        RoomView.WerwolfSettings werwolfSettings = new RoomView.WerwolfSettings(
                werewolfCount, RoleDistribution.werewolves(werwolfPlayers, werewolfCount),
                WerwolfRoles.specialRoles().stream().map(r -> RoomView.RoleCard.of(r, language)).toList(),
                werwolfRoles, werwolfHostIsGameMaster);

        RoomView.TabuSettings tabuSettings = new RoomView.TabuSettings(
                tabuOptions.turnSeconds(), tabuOptions.autoTeams(), tabuOptions.teamCount(),
                tabuOptions.targetScore(), chosenTeamIds());

        return new RoomView(
                code,
                selectedGame,
                RoomView.GameOption.all(lockedGames, language),
                impostorSettings,
                werwolfSettings,
                tabuSettings,
                new RoomView.NobodyIsPerfectSettings(nobodyIsPerfectOptions.questionCount()),
                new RoomView.BuzzerSettings(buzzerLockout),
                new RoomView.GeoBingoSettings(geoBingoOptions.minutes(), GeoBingoOptions.MIN_MINUTES,
                        GeoBingoOptions.MAX_MINUTES, geoBingoOptions.size(), GeoBingoOptions.MIN_SIZE,
                        GeoBingoOptions.MAX_SIZE, geoBingoOptions.motifs(), GeoBingoOptions.MAX_MOTIFS,
                        GeoBingoOptions.MAX_MOTIF_LENGTH),
                new RoomView.PlayerLimit(playerLimit, lowestPlayerLimit(), MAX_PLAYERS),
                phase(),
                round(),
                hostId,
                publicPlayers,
                canChooseNext && startHint == null,
                startHint == null ? null : startHint.in(language),
                new RoomView.You(me.id(), me.name(), isHost, me.ready()),
                game instanceof WerwolfGame werwolf ? werwolf.viewFor(me.id(), language) : null,
                game instanceof ImpostorGame impostor ? impostor.viewFor(me.id()) : null,
                game instanceof TabuGame tabu ? tabu.viewFor(me.id(), clock.instant(), language) : null,
                game instanceof NobodyIsPerfectGame nobodyIsPerfect ? nobodyIsPerfect.viewFor(me.id()) : null,
                game instanceof BuzzerGame buzzer ? buzzer.viewFor(me.id(), isHost) : null,
                game instanceof GeoBingoGame geoBingo ? geoBingo.viewFor(me.id(), clock.instant()) : null);
    }

    // ---- Hilfsmethoden -------------------------------------------------

    /** Warum noch nicht gestartet werden kann, oder {@code null}, wenn alles passt. */
    private Text startBlocker() {
        // Falls das voreingestellte Spiel selbst gesperrt ist
        if (lockedGames.contains(selectedGame)) {
            return lockedHint(selectedGame);
        }
        boolean hostSitsOut = hostSitsOut();
        int playing = players.size() - (hostSitsOut ? 1 : 0);
        int missing = selectedGame.minPlayers() - playing;
        if (missing > 0) {
            return hostSitsOut
                    ? Text.of("hint.missingPlayersWithoutGameMaster", missing)
                    : Text.of("hint.missingPlayers", missing);
        }
        Text settingsProblem = switch (selectedGame) {
            case WERWOLF -> RoleDistribution.problem(playing, werewolfCount, werwolfRoles);
            case IMPOSTOR -> impostorOptions.problem(playing);
            case TABU -> tabuProblem();
            case NOBODY_IS_PERFECT, BUZZER, GEO_BINGO -> null;
        };
        if (settingsProblem != null) {
            return settingsProblem;
        }

        List<Player> online = players.values().stream().filter(Player::connected).toList();
        long ready = online.stream().filter(Player::ready).count();
        if (ready < online.size()) {
            return Text.of("hint.waitForReady", ready, online.size());
        }
        return null;
    }

    private Text tabuProblem() {
        List<Integer> sizes = chosenTeamIds().stream().map(List::size).toList();
        int unassigned = players.size() - sizes.stream().mapToInt(Integer::intValue).sum();
        return tabuOptions.problem(players.size(), sizes, unassigned);
    }

    /** Spielt der Host diesmal nicht mit, weil er ein eigenes Wort gewählt hat, Werwolf leitet oder den Buzzer bedient? */
    private boolean hostSitsOut() {
        return switch (selectedGame) {
            case IMPOSTOR -> customWord != null;
            case WERWOLF -> werwolfHostIsGameMaster;
            case BUZZER -> true;
            case TABU, NOBODY_IS_PERFECT, GEO_BINGO -> false;
        };
    }

    private static Text lockedHint(GameType type) {
        return Text.of("hint.locked", type.displayName());
    }

    /** Wörter, Karten, Fragen und Orte kommen in der Sprache der Spielleitung, damit alle dasselbe sehen. */
    private Language contentLanguage() {
        return players.get(hostId).language();
    }

    private List<Player> playersExcept(String playerId) {
        return players.values().stream().filter(p -> !p.id().equals(playerId)).toList();
    }

    private int lowestPlayerLimit() {
        return Math.max(MIN_PLAYER_LIMIT, players.size());
    }

    private void requireStartable() {
        Text blocker = startBlocker();
        if (blocker != null) {
            throw new GameException(blocker);
        }
    }

    private ImpostorGame newImpostorRound(int round, RandomGenerator random) {
        String gameMasterId = customWord != null ? hostId : null;
        SecretWord secret = customWord != null
                ? new SecretWord(customWord, null)
                : ImpostorWords.pick(contentLanguage(), random, usedWords, impostorCategories);

        ImpostorGame next = new ImpostorGame(playersExcept(gameMasterId), gameMasterId, secret, impostorOptions, round, random);

        // Ein eigenes Wort gilt nur für eine Runde, danach spielt der Host wieder mit
        customWord = null;
        usedWords.add(secret.word());
        return next;
    }

    private <T extends Game> T requireGame(Class<T> type) {
        if (!type.isInstance(game)) {
            throw new GameException("error.room.notNow");
        }
        return type.cast(game);
    }

    private void requireLobby() {
        if (game != null) {
            throw new GameException("error.room.lobbyOnly");
        }
    }

    private void requireHost(String requesterId) {
        if (!requesterId.equals(hostId)) {
            throw new GameException("error.room.hostOnly");
        }
    }

    private Player require(String playerId) {
        Player player = players.get(playerId);
        if (player == null) {
            throw new GameException("error.room.notInRoom");
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
            throw new GameException("error.name.empty");
        }
        if (name.length() > MAX_NAME_LENGTH) {
            throw new GameException("error.name.tooLong", MAX_NAME_LENGTH);
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
            throw new GameException("error.impostor.wordTooLong", MAX_WORD_LENGTH);
        }
        return word;
    }
}
