// Tabu: Einstellungen, Teams, Karten und laufende Runde.
import 'json.dart';

enum CardOutcome {
  correct('CORRECT'),
  skipped('SKIPPED'),
  buzzed('BUZZED');

  const CardOutcome(this.wire);
  final String wire;
  static CardOutcome parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

class TabuSettings {
  TabuSettings.fromJson(Json j)
    : turnSeconds = j['turnSeconds'] as int,
      autoTeams = j['autoTeams'] as bool,
      teamCount = j['teamCount'] as int,
      targetScore = j['targetScore'] as int,
      teams = [for (final team in j['teams'] as List) parseStrings(team)];
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
      playerIds = parseStrings(j['playerIds']),
      score = j['score'] as int;
  final String name;
  final List<String> playerIds;
  final int score;
}

class TabuCard {
  const TabuCard(this.word, this.forbidden);
  TabuCard.fromJson(Json j) : word = j['word'] as String, forbidden = parseStrings(j['forbidden']);
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
    : teams = parseList(j['teams'], TabuTeam.fromJson),
      currentTeam = j['currentTeam'] as int,
      watcherTeam = j['watcherTeam'] as int,
      explainerId = j['explainerId'] as String,
      watcherId = j['watcherId'] as String,
      yourTeam = j['yourTeam'] as int?,
      remainingMs = j['remainingMs'] as int,
      turnSeconds = j['turnSeconds'] as int,
      targetScore = j['targetScore'] as int,
      card = parseOptional(j['card'], TabuCard.fromJson),
      turnResults = parseList(j['turnResults'], CardResult.fromJson),
      lastTurn = parseList(j['lastTurn'], CardResult.fromJson),
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
