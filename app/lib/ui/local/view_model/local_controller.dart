// Lokaler Modus: Ein Handy wird reihum weitergegeben, jeder sieht kurz seine Karte.
// Läuft komplett auf dem Gerät, ohne Server. Nur die Einrichtung (Namen, Einstellungen) wird gespeichert.
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../data/services/storage/storage_base.dart';
import '../../../data/repositories/game_data.dart';
import '../../../domain/rules/local_games.dart' as rules;
import '../../../domain/models/models.dart';

const _storageKey = 'arynta.local';
const _defaultPlayers = 5;

/// Spiele, die es auch lokal gibt.
const localGameTypes = [GameType.impostor, GameType.werwolf, GameType.tabu, GameType.nobodyIsPerfect];

/// Löscht die gespeicherte Einrichtung (für „Meine Daten löschen“).
void forgetLocalSetup(Storage storage) => storage.write(_storageKey, null);

class LocalSetup {
  LocalSetup() : categories = gameData.categoryNames, roles = [seer];

  /// Gespeicherte Werte können von einer älteren Version stammen, deshalb absichern.
  factory LocalSetup.load(Storage storage) {
    final setup = LocalSetup();
    final saved = storage.readJson(_storageKey);
    if (saved is! Map) return setup;

    int number(String key, int fallback, int min, int max) {
      final value = saved[key];
      return value is num && value != 0 ? value.toInt().clamp(min, max) : fallback.clamp(min, max);
    }

    List<Object?> list(String key) {
      final value = saved[key];
      return value is List ? value : const [];
    }

    setup.game = localGameTypes.where((g) => g.wire == saved['game']).firstOrNull ?? GameType.impostor;
    setup.playerCount = number('playerCount', _defaultPlayers, minPlayers[GameType.impostor]!, maxPlayers);
    setup.names = [for (final n in list('names')) n?.toString() ?? ''];
    setup.impostorCount = number('impostorCount', 1, 1, maxImpostorsOverall);
    setup.seesCategory = saved['seesCategory'] != false;
    setup.randomStartPlayer = saved['randomStartPlayer'] != false;
    final categories = [
      for (final c in gameData.categoryNames)
        if (list('categories').contains(c)) c,
    ];
    if (categories.isNotEmpty) setup.categories = categories;
    final werewolfCount = saved['werewolfCount'];
    setup.werewolfCount = werewolfCount is num ? werewolfCount.toInt().clamp(1, maxPlayers - 1) : null;
    if (saved.containsKey('roles')) setup.roles = rules.normalizeRoles(list('roles').whereType<String>());
    setup.turnSeconds = number('turnSeconds', 60, Tabu.minTurnSeconds, Tabu.maxTurnSeconds);
    setup.autoTeams = saved['autoTeams'] != false;
    setup.teamCount = number('teamCount', Tabu.minTeams, Tabu.minTeams, Tabu.maxTeams);
    setup.targetScore = number('targetScore', 30, Tabu.minTargetScore, Tabu.maxTargetScore);
    setup.teams = [for (final t in list('teams')) t is num && t >= 0 && t < setup.teamCount ? t.toInt() : null];
    setup.questionCount = number(
      'questionCount',
      NobodyIsPerfectRules.defaultQuestions,
      NobodyIsPerfectRules.minQuestions,
      NobodyIsPerfectRules.maxQuestions,
    );
    return setup;
  }

  GameType game = GameType.impostor;
  int playerCount = _defaultPlayers;

  /// Eingegebene Namen, leere werden zu „Spieler 1“ usw.
  List<String> names = [];
  int impostorCount = 1;
  bool seesCategory = true;
  bool randomStartPlayer = true;
  List<String> categories;

  /// null = automatisch.
  int? werewolfCount;
  List<String> roles;
  int turnSeconds = 60;
  bool autoTeams = true;
  int teamCount = Tabu.minTeams;
  int targetScore = 30;

  /// Pro Platz das selbst gewählte Team, null = noch keins.
  List<int?> teams = [];
  int questionCount = NobodyIsPerfectRules.defaultQuestions;

  void save(Storage storage) => storage.writeJson(_storageKey, {
    'game': game.wire,
    'playerCount': playerCount,
    'names': names,
    'impostorCount': impostorCount,
    'seesCategory': seesCategory,
    'randomStartPlayer': randomStartPlayer,
    'categories': categories,
    'werewolfCount': werewolfCount,
    'roles': roles,
    'turnSeconds': turnSeconds,
    'autoTeams': autoTeams,
    'teamCount': teamCount,
    'targetScore': targetScore,
    'teams': teams,
    'questionCount': questionCount,
  });

  String? get problem {
    final duplicate = rules.duplicateName(rules.playerNames(playerCount, names));
    if (duplicate != null) return 'Der Name „$duplicate“ kommt doppelt vor.';
    return switch (game) {
      GameType.tabu => rules.tabuProblem(playerCount, teamCount, autoTeams, teams),
      GameType.nobodyIsPerfect => null,
      GameType.impostor => rules.impostorProblem(playerCount, impostorCount),
      _ => rules.werwolfProblem(playerCount, werewolfCount, roles),
    };
  }

  int get maxImpostors => (playerCount ~/ 2 - 1).clamp(1, maxImpostorsOverall);
}

enum Stage {
  setup,
  pass,
  card,
  table,
  reveal,
  tabuReady,
  tabuTurn,
  tabuOver,
  fibPass,
  fibWrite,
  fibGuess,
  fibReveal,
  fibOver,
}

class LocalController extends ChangeNotifier {
  LocalController({
    required this.storage,
    required this.toast,
    required this.confirm,
    required this.exit,
    rules.Random? random,
  }) : setup = LocalSetup.load(storage),
       _random = random ?? rules.systemRandom;

  final Storage storage;
  final void Function(String text) toast;
  final Future<bool> Function(String question, String yesLabel) confirm;
  final void Function() exit;
  final rules.Random _random;

  final LocalSetup setup;
  Stage stage = Stage.setup;

  /// Namen der laufenden Runde, in Weitergabe-Reihenfolge.
  List<String> players = [];

  /// Wer gerade das Handy hat.
  int index = 0;
  rules.ImpostorDeal? impostor;
  rules.WerwolfDeal? werwolf;
  final List<String> _usedWords = [];
  bool overviewOpen = false;
  rules.TabuMatch? match;

  /// Wann der laufende Tabu-Zug endet.
  DateTime? deadline;
  rules.NobodyIsPerfectMatch? fib;
  final List<String> _usedQuestions = [];

  /// Was gerade im Antwortfeld steht.
  final answerInput = TextEditingController();

  Timer? _turnTimer;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    answerInput.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // ---- Einrichtung -----------------------------------------------------

  /// Ändert die Einrichtung, speichert sie und zeichnet neu.
  void configure(void Function(LocalSetup setup) change) {
    change(setup);
    setup.save(storage);
    _changed();
  }

  void changePlayers(int step) =>
      configure((s) => s.playerCount = (s.playerCount + step).clamp(minPlayers[GameType.impostor]!, maxPlayers));

  void changeImpostorCount(int step) =>
      configure((s) => s.impostorCount = (s.impostorCount + step).clamp(1, s.maxImpostors));

  void changeWerewolfCount(int step) => configure(
    (s) => s.werewolfCount = (rules.werewolves(s.playerCount, s.werewolfCount) + step).clamp(1, maxPlayers - 1),
  );

  void changeTurnSeconds(int step) => configure(
    (s) =>
        s.turnSeconds = (s.turnSeconds + step * Tabu.turnSecondsStep).clamp(Tabu.minTurnSeconds, Tabu.maxTurnSeconds),
  );

  void changeTargetScore(int step) => configure(
    (s) =>
        s.targetScore = (s.targetScore + step * Tabu.targetScoreStep).clamp(Tabu.minTargetScore, Tabu.maxTargetScore),
  );

  void changeTeamCount(int step) => configure((s) {
    s.teamCount = (s.teamCount + step).clamp(Tabu.minTeams, Tabu.maxTeams);
    s.teams = [for (final t in s.teams) t != null && t < s.teamCount ? t : null];
  });

  void changeQuestionCount(int step) => configure(
    (s) => s.questionCount = (s.questionCount + step).clamp(
      NobodyIsPerfectRules.minQuestions,
      NobodyIsPerfectRules.maxQuestions,
    ),
  );

  void chooseTeam(int seat, int team) => configure((s) {
    while (s.teams.length <= seat) {
      s.teams = [...s.teams, null];
    }
    s.teams[seat] = team;
  });

  void setName(int seat, String name) => configure((s) {
    while (s.names.length <= seat) {
      s.names = [...s.names, ''];
    }
    s.names[seat] = name;
  });

  void toggleCategory(String name, bool selected) => configure(
    (s) => s.categories = [
      for (final c in gameData.categoryNames)
        if (c == name ? selected : s.categories.contains(c)) c,
    ],
  );

  void toggleRole(String id, bool selected) =>
      configure((s) => s.roles = rules.normalizeRoles(selected ? [...s.roles, id] : s.roles.where((r) => r != id)));

  // ---- Runden ----------------------------------------------------------

  void startRound() {
    final problem = setup.problem;
    if (problem != null) {
      toast(problem);
      return;
    }
    players = rules.playerNames(setup.playerCount, setup.names);
    switch (setup.game) {
      case GameType.nobodyIsPerfect:
        final questions = rules.pickQuestions(setup.questionCount, _usedQuestions, _random);
        _usedQuestions.addAll(questions.map((q) => q.question));
        fib = rules.NobodyIsPerfectMatch(setup.playerCount, questions);
        answerInput.clear();
        index = 0;
        stage = Stage.fibPass;
      case GameType.tabu:
        final teams = rules.makeTeams(setup.playerCount, setup.teamCount, setup.autoTeams, setup.teams, _random);
        match = rules.TabuMatch(teams, setup.targetScore);
        deadline = null;
        stage = Stage.tabuReady;
      case GameType.impostor:
        final deal = rules.dealImpostor(
          setup.playerCount,
          rules.ImpostorOptions(
            impostorCount: setup.impostorCount,
            randomStartPlayer: setup.randomStartPlayer,
            categories: setup.categories,
          ),
          _usedWords,
          _random,
        );
        _usedWords.add(deal.word);
        impostor = deal;
        werwolf = null;
        _startPassing();
      case GameType.werwolf:
      case GameType.buzzer:
        werwolf = rules.dealWerwolf(setup.playerCount, setup.werewolfCount, setup.roles, _random);
        impostor = null;
        _startPassing();
    }
    _changed();
  }

  void _startPassing() {
    index = 0;
    overviewOpen = false;
    stage = Stage.pass;
  }

  void showCard() {
    stage = Stage.card;
    _changed();
  }

  void passOn() {
    index++;
    stage = index < players.length ? Stage.pass : Stage.table;
    _changed();
  }

  Future<void> _confirmThen(String question, String yes, void Function() then) async {
    if (await confirm(question, yes) && !_disposed) {
      then();
      _changed();
    }
  }

  Future<void> revealImpostor() =>
      _confirmThen('Auflösen? Danach sehen alle, wer Impostor war.', 'Ja, auflösen', () => stage = Stage.reveal);

  Future<void> showOverview() => _confirmThen(
    'Nur die Spielleitung darf jetzt hinschauen. Alle Rollen zeigen?',
    'Ja, zeigen',
    () => overviewOpen = true,
  );

  void hideOverview() {
    overviewOpen = false;
    _changed();
  }

  Future<void> redeal() =>
      _confirmThen('Rollen neu verteilen? Das Handy geht dann wieder reihum.', 'Ja, neu verteilen', startRound);

  /// Zurück zu den Einstellungen. Mitten in einer Runde erst nachfragen.
  Future<void> backToSetup() async {
    if (const [Stage.setup, Stage.reveal, Stage.tabuOver, Stage.fibOver].contains(stage)) {
      _toSetup();
      _changed();
      return;
    }
    await _confirmThen('Runde abbrechen und zurück zu den Einstellungen?', 'Ja, abbrechen', _toSetup);
  }

  void _toSetup() {
    _turnTimer?.cancel();
    stage = Stage.setup;
  }

  Future<void> quit() async {
    if (stage == Stage.setup || await confirm('Lokales Spiel beenden?', 'Ja, beenden')) {
      if (!_disposed) exit();
    }
  }

  // ---- Tabu ------------------------------------------------------------

  /// Lokal zählt die Uhr dieses Handys. Ist die Zeit um, ist das nächste Team dran.
  void startTurn() {
    rules.drawCard(match!, _random);
    deadline = DateTime.now().add(Duration(seconds: setup.turnSeconds));
    stage = Stage.tabuTurn;
    _turnTimer?.cancel();
    _turnTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => tick(DateTime.now()));
    _changed();
  }

  void tick(DateTime now) {
    final end = deadline;
    if (stage != Stage.tabuTurn || end == null || now.isBefore(end)) return;
    _turnTimer?.cancel();
    rules.endTurn(match!);
    deadline = null;
    stage = Stage.tabuReady;
    _changed();
  }

  void score(CardOutcome outcome) {
    rules.scoreCard(match!, outcome, _random);
    if (match!.winner != null) {
      _turnTimer?.cancel();
      deadline = null;
      stage = Stage.tabuOver;
    }
    _changed();
  }

  // ---- Nobody is Perfect -----------------------------------------------

  void showFibTurn() {
    stage = fib!.choices.isEmpty ? Stage.fibWrite : Stage.fibGuess;
    _changed();
  }

  /// Antwort merken und das Handy weitergeben. Nach dem Letzten werden die Antworten gemischt.
  void submitAnswer() {
    final problem = rules.submitLie(fib!, index, answerInput.text);
    if (problem != null) {
      toast(problem);
      return;
    }
    answerInput.clear();
    index++;
    if (index == players.length) {
      rules.mixChoices(fib!, _random);
      index = 0;
    }
    stage = Stage.fibPass;
    _changed();
  }

  void guess(String id) {
    final problem = rules.guessChoice(fib!, index, id);
    if (problem != null) toast(problem);
    _changed();
  }

  /// Tipp steht, Handy weitergeben. Nach dem Letzten wird aufgelöst.
  void finishGuess() {
    if (fib!.guesses[index] == null) {
      toast('Tippe zuerst auf eine Antwort.');
      return;
    }
    index++;
    if (index < players.length) {
      stage = Stage.fibPass;
    } else {
      rules.revealQuestion(fib!);
      stage = rules.isLastQuestion(fib!) ? Stage.fibOver : Stage.fibReveal;
    }
    _changed();
  }

  void nextQuestion() {
    rules.nextQuestion(fib!);
    index = 0;
    stage = Stage.fibPass;
    _changed();
  }
}
