// Spiegelt die Java-Klassen im Backend (RoomView, GameType, Phase).

typedef Json = Map<String, dynamic>;

/// Namen wie auf der Leitung: `GameType.nobodyIsPerfect` ↔ `NOBODY_IS_PERFECT`.
enum GameType {
  werwolf('WERWOLF'),
  impostor('IMPOSTOR'),
  tabu('TABU'),
  nobodyIsPerfect('NOBODY_IS_PERFECT'),
  buzzer('BUZZER');

  const GameType(this.wire);
  final String wire;
  static GameType parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

enum Phase {
  lobby('LOBBY'),
  night('NIGHT'),
  day('DAY'),
  word('WORD'),
  voting('VOTING'),
  result('RESULT'),
  turnReady('TURN_READY'),
  turn('TURN'),
  writing('WRITING'),
  guessing('GUESSING'),
  reveal('REVEAL'),
  buzzer('BUZZER');

  const Phase(this.wire);
  final String wire;
  static Phase parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

enum ImpostorPart {
  crew('CREW'),
  impostor('IMPOSTOR'),
  gameMaster('GAME_MASTER');

  const ImpostorPart(this.wire);
  final String wire;
  static ImpostorPart parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

enum CardOutcome {
  correct('CORRECT'),
  skipped('SKIPPED'),
  buzzed('BUZZED');

  const CardOutcome(this.wire);
  final String wire;
  static CardOutcome parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

List<T> _list<T>(Object? raw, T Function(Json) parse) => [for (final item in raw as List) parse(item as Json)];

List<String> _strings(Object? raw) => List<String>.from(raw as List);

T? _optional<T>(Object? raw, T Function(Json) parse) => raw == null ? null : parse(raw as Json);

class PlayerView {
  PlayerView.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      alive = j['alive'] as bool,
      connected = j['connected'] as bool,
      ready = j['ready'] as bool;
  final String id;
  final String name;
  final bool alive;
  final bool connected;
  final bool ready;
}

class You {
  You.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      host = j['host'] as bool,
      ready = j['ready'] as bool;
  final String id;
  final String name;
  final bool host;
  final bool ready;
}

class GameOption {
  GameOption.fromJson(Json j)
    : type = GameType.parse(j['type']),
      name = j['name'] as String,
      description = j['description'] as String,
      minPlayers = j['minPlayers'] as int;
  final GameType type;
  final String name;
  final String description;
  final int minPlayers;
}

class ImpostorSettings {
  ImpostorSettings.fromJson(Json j)
    : impostorSeesCategory = j['impostorSeesCategory'] as bool,
      customWordSet = j['customWordSet'] as bool,
      customWord = j['customWord'] as String?,
      allCategories = _strings(j['allCategories']),
      selectedCategories = _strings(j['selectedCategories']),
      impostorCount = j['impostorCount'] as int,
      maxImpostorCount = j['maxImpostorCount'] as int,
      randomStartPlayer = j['randomStartPlayer'] as bool;
  final bool impostorSeesCategory;
  final bool customWordSet;

  /// Nur beim Host gefüllt.
  final String? customWord;
  final List<String> allCategories;
  final List<String> selectedCategories;
  final int impostorCount;
  final int maxImpostorCount;
  final bool randomStartPlayer;
}

class WerwolfSettings {
  WerwolfSettings.fromJson(Json j)
    : werewolfCount = j['werewolfCount'] as int?,
      effectiveWerewolfCount = j['effectiveWerewolfCount'] as int,
      allRoles = _list(j['allRoles'], RoleCard.fromJson),
      selectedRoles = _strings(j['selectedRoles']),
      hostIsGameMaster = j['hostIsGameMaster'] as bool;

  /// null = automatisch passend zur Spielerzahl.
  final int? werewolfCount;
  final int effectiveWerewolfCount;
  final List<RoleCard> allRoles;
  final List<String> selectedRoles;
  final bool hostIsGameMaster;
}

class TabuSettings {
  TabuSettings.fromJson(Json j)
    : turnSeconds = j['turnSeconds'] as int,
      autoTeams = j['autoTeams'] as bool,
      teamCount = j['teamCount'] as int,
      targetScore = j['targetScore'] as int,
      teams = [for (final team in j['teams'] as List) _strings(team)];
  final int turnSeconds;
  final bool autoTeams;
  final int teamCount;
  final int targetScore;

  /// Spieler-IDs pro Team, wenn jeder selbst wählt.
  final List<List<String>> teams;
}

class TabuTeam {
  TabuTeam.fromJson(Json j)
    : name = j['name'] as String,
      playerIds = _strings(j['playerIds']),
      score = j['score'] as int;
  final String name;
  final List<String> playerIds;
  final int score;
}

class TabuCard {
  const TabuCard(this.word, this.forbidden);
  TabuCard.fromJson(Json j) : word = j['word'] as String, forbidden = _strings(j['forbidden']);
  final String word;
  final List<String> forbidden;
}

class CardResult {
  const CardResult(this.word, this.outcome, this.scoringTeam);
  CardResult.fromJson(Json j)
    : word = j['word'] as String,
      outcome = CardOutcome.parse(j['outcome']),
      scoringTeam = j['scoringTeam'] as int?;
  final String word;
  final CardOutcome outcome;

  /// null: niemand bekam einen Punkt (Buzzer).
  final int? scoringTeam;
}

class TabuView {
  TabuView.fromJson(Json j)
    : teams = _list(j['teams'], TabuTeam.fromJson),
      currentTeam = j['currentTeam'] as int,
      watcherTeam = j['watcherTeam'] as int,
      explainerId = j['explainerId'] as String,
      watcherId = j['watcherId'] as String,
      yourTeam = j['yourTeam'] as int?,
      remainingMs = j['remainingMs'] as int,
      turnSeconds = j['turnSeconds'] as int,
      targetScore = j['targetScore'] as int,
      card = _optional(j['card'], TabuCard.fromJson),
      turnResults = _list(j['turnResults'], CardResult.fromJson),
      lastTurn = _list(j['lastTurn'], CardResult.fromJson),
      winnerTeam = j['winnerTeam'] as int?;
  final List<TabuTeam> teams;
  final int currentTeam;
  final int watcherTeam;
  final String explainerId;
  final String watcherId;
  final int? yourTeam;

  /// Restzeit des laufenden Zugs beim Absenden der Ansicht.
  final int remainingMs;
  final int turnSeconds;
  final int targetScore;

  /// Nur für Erklärer und Aufpasser.
  final TabuCard? card;
  final List<CardResult> turnResults;
  final List<CardResult> lastTurn;
  final int? winnerTeam;
}

class NobodyIsPerfectSettings {
  NobodyIsPerfectSettings.fromJson(Json j) : questionCount = j['questionCount'] as int;
  final int questionCount;
}

class NobodyIsPerfectChoice {
  NobodyIsPerfectChoice.fromJson(Json j) : id = j['id'] as String, text = j['text'] as String;
  final String id;
  final String text;
}

class NobodyIsPerfectReveal {
  NobodyIsPerfectReveal.fromJson(Json j)
    : id = j['id'] as String,
      text = j['text'] as String,
      correct = j['correct'] as bool,
      authorId = j['authorId'] as String?,
      guesserIds = _strings(j['guesserIds']);
  final String id;
  final String text;
  final bool correct;

  /// null bei der echten Antwort.
  final String? authorId;
  final List<String> guesserIds;
}

class NobodyIsPerfectScore {
  NobodyIsPerfectScore.fromJson(Json j)
    : playerId = j['playerId'] as String,
      score = j['score'] as int,
      gained = j['gained'] as int;
  final String playerId;
  final int score;

  /// Punkte für die zuletzt aufgelöste Frage.
  final int gained;
}

/// choices ab dem Tippen, answer und reveal erst nach der Auflösung.
class NobodyIsPerfectView {
  NobodyIsPerfectView.fromJson(Json j)
    : questionNumber = j['questionNumber'] as int,
      questionCount = j['questionCount'] as int,
      question = j['question'] as String,
      answer = j['answer'] as String?,
      participantIds = _strings(j['participantIds']),
      answeredIds = _strings(j['answeredIds']),
      yourAnswer = j['yourAnswer'] as String?,
      choices = _list(j['choices'], NobodyIsPerfectChoice.fromJson),
      yourChoiceId = j['yourChoiceId'] as String?,
      guessedIds = _strings(j['guessedIds']),
      yourGuess = j['yourGuess'] as String?,
      reveal = _list(j['reveal'], NobodyIsPerfectReveal.fromJson),
      scores = _list(j['scores'], NobodyIsPerfectScore.fromJson);
  final int questionNumber;
  final int questionCount;
  final String question;
  final String? answer;
  final List<String> participantIds;
  final List<String> answeredIds;
  final String? yourAnswer;
  final List<NobodyIsPerfectChoice> choices;
  final String? yourChoiceId;
  final List<String> guessedIds;
  final String? yourGuess;
  final List<NobodyIsPerfectReveal> reveal;
  final List<NobodyIsPerfectScore> scores;
}

class BuzzerSettings {
  BuzzerSettings.fromJson(Json j) : lockout = j['lockout'] as bool;
  final bool lockout;
}

class BuzzerPress {
  BuzzerPress.fromJson(Json j)
    : playerId = j['playerId'] as String,
      rank = j['rank'] as int,
      offsetMs = j['offsetMs'] as int;
  final String playerId;
  final int rank;

  /// Wie viel später als der Erste gedrückt wurde.
  final int offsetMs;
}

/// presses (die ganze Reihenfolge) sieht nur die Spielleitung.
class BuzzerView {
  BuzzerView.fromJson(Json j)
    : lockout = j['lockout'] as bool,
      presses = _list(j['presses'], BuzzerPress.fromJson),
      yourRank = j['yourRank'] as int?,
      canPress = j['canPress'] as bool;
  final bool lockout;
  final List<BuzzerPress> presses;
  final int? yourRank;
  final bool canPress;
}

class PlayerLimit {
  PlayerLimit.fromJson(Json j) : value = j['value'] as int, min = j['min'] as int, max = j['max'] as int;
  final int value;

  /// Kleinster Wert, den der Host gerade einstellen darf.
  final int min;
  final int max;
}

class RoleCard {
  const RoleCard({
    required this.id,
    required this.name,
    required this.team,
    required this.teamName,
    required this.description,
  });
  RoleCard.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      team = j['team'] as String,
      teamName = j['teamName'] as String,
      description = j['description'] as String;
  final String id;
  final String name;
  final String team;
  final String teamName;
  final String description;
}

class RoleAssignment {
  RoleAssignment.fromJson(Json j)
    : playerId = j['playerId'] as String,
      playerName = j['playerName'] as String,
      role = RoleCard.fromJson(j['role'] as Json);
  final String playerId;
  final String playerName;
  final RoleCard role;
}

/// Mitspieler: role, knownWolves, beim Dieb leftoverRoles. Spielleitung: gameMaster, overview, leftoverRoles.
class WerwolfView {
  WerwolfView.fromJson(Json j)
    : gameMaster = j['gameMaster'] as bool,
      role = _optional(j['role'], RoleCard.fromJson),
      knownWolves = _strings(j['knownWolves']),
      leftoverRoles = _strings(j['leftoverRoles']),
      overview = j['overview'] == null ? null : _list(j['overview'], RoleAssignment.fromJson);
  final bool gameMaster;
  final RoleCard? role;
  final List<String> knownWolves;
  final List<String> leftoverRoles;
  final List<RoleAssignment>? overview;
}

class VoteCount {
  VoteCount.fromJson(Json j)
    : playerId = j['playerId'] as String,
      name = j['name'] as String,
      votes = j['votes'] as int;
  final String playerId;
  final String name;
  final int votes;
}

class ImpostorResult {
  ImpostorResult.fromJson(Json j)
    : impostorIds = _strings(j['impostorIds']),
      impostorNames = _strings(j['impostorNames']),
      word = j['word'] as String,
      category = j['category'] as String?,
      impostorCaught = j['impostorCaught'] as bool,
      votes = _list(j['votes'], VoteCount.fromJson);
  final List<String> impostorIds;
  final List<String> impostorNames;
  final String word;
  final String? category;
  final bool impostorCaught;
  final List<VoteCount> votes;
}

class ImpostorView {
  ImpostorView.fromJson(Json j)
    : part = ImpostorPart.parse(j['part']),
      word = j['word'] as String?,
      category = j['category'] as String?,
      fellowImpostors = _strings(j['fellowImpostors']),
      startPlayerId = j['startPlayerId'] as String?,
      gameMasterId = j['gameMasterId'] as String?,
      participantIds = _strings(j['participantIds']),
      votedIds = _strings(j['votedIds']),
      yourVote = j['yourVote'] as String?,
      result = _optional(j['result'], ImpostorResult.fromJson);
  final ImpostorPart part;
  final String? word;
  final String? category;
  final List<String> fellowImpostors;
  final String? startPlayerId;
  final String? gameMasterId;
  final List<String> participantIds;
  final List<String> votedIds;
  final String? yourVote;
  final ImpostorResult? result;
}

class RoomView {
  RoomView.fromJson(Json j)
    : code = j['code'] as String,
      game = GameType.parse(j['game']),
      games = _list(j['games'], GameOption.fromJson),
      impostorSettings = ImpostorSettings.fromJson(j['impostorSettings'] as Json),
      werwolfSettings = WerwolfSettings.fromJson(j['werwolfSettings'] as Json),
      tabuSettings = TabuSettings.fromJson(j['tabuSettings'] as Json),
      nobodyIsPerfectSettings = NobodyIsPerfectSettings.fromJson(j['nobodyIsPerfectSettings'] as Json),
      buzzerSettings = BuzzerSettings.fromJson(j['buzzerSettings'] as Json),
      playerLimit = PlayerLimit.fromJson(j['playerLimit'] as Json),
      phase = Phase.parse(j['phase']),
      round = j['round'] as int,
      hostId = j['hostId'] as String,
      players = _list(j['players'], PlayerView.fromJson),
      canStart = j['canStart'] as bool,
      startHint = j['startHint'] as String?,
      you = You.fromJson(j['you'] as Json),
      werwolf = _optional(j['werwolf'], WerwolfView.fromJson),
      impostor = _optional(j['impostor'], ImpostorView.fromJson),
      tabu = _optional(j['tabu'], TabuView.fromJson),
      nobodyIsPerfect = _optional(j['nobodyIsPerfect'], NobodyIsPerfectView.fromJson),
      buzzer = _optional(j['buzzer'], BuzzerView.fromJson);
  final String code;
  final GameType game;
  final List<GameOption> games;
  final ImpostorSettings impostorSettings;
  final WerwolfSettings werwolfSettings;
  final TabuSettings tabuSettings;
  final NobodyIsPerfectSettings nobodyIsPerfectSettings;
  final BuzzerSettings buzzerSettings;
  final PlayerLimit playerLimit;
  final Phase phase;
  final int round;
  final String hostId;
  final List<PlayerView> players;
  final bool canStart;
  final String? startHint;
  final You you;
  final WerwolfView? werwolf;
  final ImpostorView? impostor;
  final TabuView? tabu;
  final NobodyIsPerfectView? nobodyIsPerfect;
  final BuzzerView? buzzer;

  /// Name zu einer Spieler-ID, "?" wenn es den Spieler nicht mehr gibt.
  String nameOf(String id) {
    for (final p in players) {
      if (p.id == id) return p.name;
    }
    return '?';
  }
}

/// Was der Server schickt.
sealed class ServerMessage {
  const ServerMessage();

  /// Wirft bei unbekanntem Typ oder fehlenden Feldern.
  factory ServerMessage.fromJson(Json j) => switch (j['type']) {
    'joined' => Joined(j['code'] as String, j['secret'] as String),
    'state' => StateMessage(RoomView.fromJson(j['state'] as Json)),
    'left' => const LeftRoom(),
    'kicked' => const Kicked(),
    'error' => ErrorMessage(j['message'] as String),
    'pong' => const Pong(),
    final type => throw FormatException('Unbekannte Nachricht: $type'),
  };
}

class Joined extends ServerMessage {
  const Joined(this.code, this.secret);
  final String code;
  final String secret;
}

class StateMessage extends ServerMessage {
  const StateMessage(this.state);
  final RoomView state;
}

class LeftRoom extends ServerMessage {
  const LeftRoom();
}

class Kicked extends ServerMessage {
  const Kicked();
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.message);
  final String message;
}

class Pong extends ServerMessage {
  const Pong();
}

/// Was das Handy schickt.
class ClientMessage {
  ClientMessage._(String type, [Json fields = const {}]) : json = {'type': type, ...fields};
  final Json json;
  String get type => json['type'] as String;

  ClientMessage.create(String name) : this._('create', {'name': name});
  ClientMessage.join(String code, String name) : this._('join', {'code': code, 'name': name});
  ClientMessage.rejoin(String code, String secret) : this._('rejoin', {'code': code, 'secret': secret});
  ClientMessage.leave() : this._('leave');
  ClientMessage.selectGame(GameType game) : this._('selectGame', {'game': game.wire});
  ClientMessage.setReady(bool ready) : this._('setReady', {'ready': ready});
  ClientMessage.configureImpostor({required bool impostorSeesCategory, required String customWord})
    : this._('configureImpostor', {'impostorSeesCategory': impostorSeesCategory, 'customWord': customWord});
  ClientMessage.start() : this._('start');
  ClientMessage.nextPhase() : this._('nextPhase');
  ClientMessage.startVoting() : this._('startVoting');
  ClientMessage.vote(String targetId) : this._('vote', {'targetId': targetId});
  ClientMessage.kick(String targetId) : this._('kick', {'targetId': targetId});
  ClientMessage.setPlayerLimit(int playerLimit) : this._('setPlayerLimit', {'playerLimit': playerLimit});
  ClientMessage.setImpostorCategories(List<String> categories)
    : this._('setImpostorCategories', {'categories': categories});
  ClientMessage.setImpostorOptions({required int impostorCount, required bool randomStartPlayer})
    : this._('setImpostorOptions', {'impostorCount': impostorCount, 'randomStartPlayer': randomStartPlayer});
  ClientMessage.configureWerwolf({
    required int? werewolfCount,
    required List<String> roles,
    required bool hostIsGameMaster,
  }) : this._('configureWerwolf', {
         'werewolfCount': werewolfCount,
         'roles': roles,
         'hostIsGameMaster': hostIsGameMaster,
       });
  ClientMessage.configureTabu({
    required int turnSeconds,
    required bool autoTeams,
    required int teamCount,
    required int targetScore,
  }) : this._('configureTabu', {
         'turnSeconds': turnSeconds,
         'autoTeams': autoTeams,
         'teamCount': teamCount,
         'targetScore': targetScore,
       });
  ClientMessage.chooseTeam(int team, {String? targetId}) : this._('chooseTeam', {'team': team, 'targetId': ?targetId});
  ClientMessage.startTurn() : this._('startTurn');
  ClientMessage.wordCorrect() : this._('wordCorrect');
  ClientMessage.wordSkip() : this._('wordSkip');
  ClientMessage.buzz() : this._('buzz');
  ClientMessage.configureNobodyIsPerfect(int questionCount)
    : this._('configureNobodyIsPerfect', {'questionCount': questionCount});
  ClientMessage.submitAnswer(String answer) : this._('submitAnswer', {'answer': answer});
  ClientMessage.guessAnswer(String choice) : this._('guessAnswer', {'choice': choice});
  ClientMessage.skipWaiting() : this._('skipWaiting');
  ClientMessage.nextQuestion() : this._('nextQuestion');
  ClientMessage.configureBuzzer(bool lockout) : this._('configureBuzzer', {'lockout': lockout});
  ClientMessage.pressBuzzer() : this._('pressBuzzer');
  ClientMessage.releaseBuzzer() : this._('releaseBuzzer');
  ClientMessage.nextRound() : this._('nextRound');
  ClientMessage.backToLobby() : this._('backToLobby');
  ClientMessage.ping() : this._('ping');
}
