// Tabu lokal, wie TabuGame im Backend.
import '../../data/repositories/game_data.dart';
import '../../l10n/l10n.dart';
import '../models/models.dart';
import 'common.dart';

/// Ein laufendes Tabu-Spiel. Spieler sind Plätze (Index in der Namensliste).
class TabuMatch {
  TabuMatch(this.teams, this.targetScore)
    : scores = List.filled(teams.length, 0),
      explainerTurns = List.filled(teams.length, 0),
      watcherTurns = List.filled(teams.length, 0);

  final List<List<int>> teams;
  final List<int> scores;
  final int targetScore;
  int currentTeam = 0;

  /// Pro Team: wie oft schon erklärt bzw. aufgepasst wurde, daraus folgt, wer dran ist.
  final List<int> explainerTurns;
  final List<int> watcherTurns;
  List<TabuCard> deck = [];
  TabuCard? card;
  List<CardResult> turnResults = [];
  List<CardResult> lastTurn = [];
  int? winner;
}

/// Warum nicht gestartet werden kann, oder null.
/// [chosen] pro Platz das selbst gewählte Team, null = noch keins
String? tabuProblem(int playerCount, int teamCount, bool autoTeams, List<int?> chosen) {
  final needed = teamCount * Tabu.minTeamSize;
  if (playerCount < needed) return texts.tabuMinPlayers(teamCount, needed);
  if (autoTeams) return null;
  final picks = List.generate(playerCount, (i) => i < chosen.length ? chosen[i] : null);
  final unassigned = picks.where((t) => t == null || t >= teamCount).length;
  if (unassigned > 0) {
    return texts.withoutTeamCount(unassigned);
  }
  for (var team = 0; team < teamCount; team++) {
    if (picks.where((t) => t == team).length < Tabu.minTeamSize) {
      return texts.teamMinSize(Tabu.minTeamSize);
    }
  }
  return null;
}

/// Automatisch: gemischt und reihum verteilt, also gleich groß. Sonst wie gewählt.
List<List<int>> makeTeams(int playerCount, int teamCount, bool autoTeams, List<int?> chosen, Random random) {
  final teams = List.generate(teamCount, (_) => <int>[]);
  final seats = List.generate(playerCount, (i) => i);
  if (autoTeams) {
    final mixed = shuffled(seats, random);
    for (var i = 0; i < mixed.length; i++) {
      teams[i % teamCount].add(mixed[i]);
    }
  } else {
    for (final seat in seats) {
      teams[chosen[seat]!].add(seat);
    }
  }
  return teams;
}

/// Der Aufpasser kommt aus dem Team, das als Nächstes dran ist.
int watcherTeam(TabuMatch match) => (match.currentTeam + 1) % match.teams.length;

int explainerSeat(TabuMatch match) {
  final team = match.teams[match.currentTeam];
  return team[match.explainerTurns[match.currentTeam] % team.length];
}

int watcherSeat(TabuMatch match) {
  final index = watcherTeam(match);
  final team = match.teams[index];
  return team[match.watcherTurns[index] % team.length];
}

/// Neu gemischt wird erst, wenn alle Karten einmal dran waren.
void drawCard(TabuMatch match, Random random) {
  if (match.deck.isEmpty) match.deck = shuffled(gameData.tabuCards, random);
  match.card = match.deck.removeLast();
}

/// Richtig: Punkt fürs eigene Team. Überspringen oder Buzzer: neue Karte, kein Punkt.
void scoreCard(TabuMatch match, CardOutcome outcome, Random random) {
  final card = match.card;
  if (card == null || match.winner != null) return;
  if (outcome != CardOutcome.correct) {
    match.turnResults.add(CardResult(card.word, outcome, null));
    drawCard(match, random);
    return;
  }
  final team = match.currentTeam;
  match.scores[team]++;
  match.turnResults.add(CardResult(card.word, outcome, team));
  if (match.scores[team] >= match.targetScore) {
    match.winner = team;
    match.lastTurn = match.turnResults;
    match.turnResults = [];
    match.card = null;
    return;
  }
  drawCard(match, random);
}

/// Zeit um: das nächste Team ist dran, Erklärer und Aufpasser wechseln.
void endTurn(TabuMatch match) {
  match.lastTurn = match.turnResults;
  match.turnResults = [];
  match.explainerTurns[match.currentTeam]++;
  match.watcherTurns[watcherTeam(match)]++;
  match.currentTeam = (match.currentTeam + 1) % match.teams.length;
  match.card = null;
}
