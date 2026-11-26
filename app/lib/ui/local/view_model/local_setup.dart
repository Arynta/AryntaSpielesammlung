// Einrichtung des lokalen Modus: Spiel, Spieler, Namen und Einstellungen. Wird im Gerät gespeichert.
import '../../../data/services/storage/storage_base.dart';
import '../../../data/repositories/game_data.dart';
import '../../../l10n/l10n.dart';
import '../../../domain/rules/local_games.dart' as rules;
import '../../../domain/models/models.dart';
import 'local_controller.dart';

class LocalSetup {
  LocalSetup() : categories = gameData.categoryIds, roles = [seer];

  /// Gespeicherte Werte können von einer älteren Version stammen, deshalb absichern.
  factory LocalSetup.load(Storage storage) {
    final setup = LocalSetup();
    final saved = storage.readJson(localSetupKey);
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
    setup.playerCount = number('playerCount', defaultLocalPlayers, minPlayers[GameType.impostor]!, maxPlayers);
    setup.names = [for (final n in list('names')) n?.toString() ?? ''];
    setup.impostorCount = number('impostorCount', 1, 1, maxImpostorsOverall);
    setup.seesCategory = saved['seesCategory'] != false;
    setup.randomStartPlayer = saved['randomStartPlayer'] != false;
    final categories = [
      for (final c in gameData.categoryIds)
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
  int playerCount = defaultLocalPlayers;

  /// Eingegebene Namen, leere werden zu „Spieler 1“ usw.
  List<String> names = [];
  int impostorCount = 1;
  bool seesCategory = true;
  bool randomStartPlayer = true;
  /// IDs der Kategorien, gleich in allen Sprachen.
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

  void save(Storage storage) => storage.writeJson(localSetupKey, {
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
    if (duplicate != null) return texts.duplicateName(duplicate);
    return switch (game) {
      GameType.tabu => rules.tabuProblem(playerCount, teamCount, autoTeams, teams),
      GameType.nobodyIsPerfect => null,
      GameType.impostor => rules.impostorProblem(playerCount, impostorCount),
      _ => rules.werwolfProblem(playerCount, werewolfCount, roles),
    };
  }

  int get maxImpostors => (playerCount ~/ 2 - 1).clamp(1, maxImpostorsOverall);
}
