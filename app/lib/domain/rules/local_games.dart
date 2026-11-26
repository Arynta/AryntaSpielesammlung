// Spielregeln für den lokalen Modus (ein Handy, kein Server). Sie entsprechen den Regeln im
// Backend (RoleDistribution, ImpostorOptions, ImpostorWords, TabuGame, NobodyIsPerfectGame) und haben eigene Tests.
import 'dart:math' as math;

import '../../data/repositories/game_data.dart';
import '../models/models.dart';

/// Zufallszahl von 0 (inklusive) bis 1 (exklusive). Austauschbar für Tests.
typedef Random = double Function();

final Random systemRandom = math.Random().nextDouble;

List<T> shuffled<T>(Iterable<T> items, Random random) {
  final copy = List<T>.of(items);
  for (var i = copy.length - 1; i > 0; i--) {
    final j = (random() * (i + 1)).floor();
    final swap = copy[i];
    copy[i] = copy[j];
    copy[j] = swap;
  }
  return copy;
}

/// Leere Felder werden zu „Spieler 1“, „Spieler 2“ usw.
List<String> playerNames(int count, List<String> typed) => List.generate(count, (i) {
  final name = cleanName(i < typed.length ? typed[i] : '');
  return name.isEmpty ? 'Spieler ${i + 1}' : name;
});

final _invisible = RegExp(r'[\p{Cc}\p{Cf}\p{Co}\p{Cn}]', unicode: true);
final _whitespace = RegExp(r'\s');
final _spaces = RegExp(r'[\s\p{Z}]+', unicode: true);

/// Wie im Backend: unsichtbare Zeichen raus, Leerraum zusammenfassen.
String cleanName(String raw) =>
    raw.replaceAllMapped(_invisible, (m) => _whitespace.hasMatch(m[0]!) ? m[0]! : '').replaceAll(_spaces, ' ').trim();

String? duplicateName(List<String> names) {
  final seen = <String>{};
  for (final name in names) {
    if (!seen.add(name.toLowerCase())) return name;
  }
  return null;
}

// ---- Werwolf ---------------------------------------------------------------

/// Ein Werwolf pro angefangene vier Spieler (4–7 → 1, 8–11 → 2, ...).
int autoWerewolves(int playerCount) => math.max(1, playerCount ~/ 4);

/// [chosen] ist null, wenn die Anzahl automatisch sein soll.
int werewolves(int playerCount, int? chosen) => chosen ?? autoWerewolves(playerCount);

String? werwolfProblem(int playerCount, int? chosen, List<String> specialRoles) {
  final needed = minPlayers[GameType.werwolf]!;
  if (playerCount < needed) return 'Es werden mindestens $needed Spieler gebraucht.';
  final cards = werewolves(playerCount, chosen) + specialRoles.length;
  if (cards > playerCount) {
    return 'Zu viele Rollen: $cards Rollen für $playerCount Spieler. Nimm Rollen raus oder weniger Werwölfe.';
  }
  return null;
}

/// Bringt die Auswahl in die Reihenfolge der Rollenliste und lässt Unbekanntes weg.
List<String> normalizeRoles(Iterable<String> ids) => [
  for (final role in gameData.specialRoles)
    if (ids.contains(role.id)) role.id,
];

class WerwolfDeal {
  const WerwolfDeal(this.perPlayer, this.leftover);
  final List<RoleData> perPlayer;

  /// Nur mit Dieb: die zwei übrigen Karten.
  final List<RoleData> leftover;
}

WerwolfDeal dealWerwolf(int playerCount, int? chosen, List<String> specialRoles, Random random) {
  final problem = werwolfProblem(playerCount, chosen, specialRoles);
  if (problem != null) throw StateError(problem);

  final extra = specialRoles.contains(thief) ? thiefExtraCards : 0;
  final cards = <RoleData>[
    for (var i = 0; i < werewolves(playerCount, chosen); i++) gameData.roleById(werewolf),
    for (final id in specialRoles) gameData.roleById(id),
  ];
  while (cards.length < playerCount + extra) {
    cards.add(gameData.roleById(villager));
  }

  final mixed = shuffled(cards, random);
  return WerwolfDeal(mixed.sublist(0, playerCount), mixed.sublist(playerCount));
}

/// Das Rudel kennt sich gegenseitig, der Günstling kennt das Rudel.
List<String> knownWolves(WerwolfDeal deal, List<String> names, int index) {
  final role = deal.perPlayer[index];
  if (!role.wolfPack && !role.seesWolfPack) return [];
  return [
    for (var i = 0; i < names.length; i++)
      if (i != index && deal.perPlayer[i].wolfPack) names[i],
  ];
}

// ---- Impostor --------------------------------------------------------------

/// Ab 2 Impostorn muss die Crew mindestens zwei mehr sein, sonst ist sie chancenlos.
int minImpostorParticipants(int impostorCount) {
  final minimum = minPlayers[GameType.impostor]!;
  return impostorCount == 1 ? minimum : math.max(minimum, 2 * impostorCount + 2);
}

String? impostorProblem(int playerCount, int impostorCount) {
  if (impostorCount < 1 || impostorCount > maxImpostorsOverall) {
    return 'Es kann 1 bis $maxImpostorsOverall Impostor geben.';
  }
  final needed = minImpostorParticipants(impostorCount);
  if (playerCount >= needed) return null;
  return impostorCount == 1
      ? 'Für Impostor braucht es mindestens $needed Mitspieler.'
      : 'Für $impostorCount Impostor braucht es mindestens $needed Mitspieler.';
}

class ImpostorOptions {
  const ImpostorOptions({required this.impostorCount, required this.randomStartPlayer, required this.categories});
  final int impostorCount;
  final bool randomStartPlayer;
  final List<String> categories;
}

class ImpostorDeal {
  const ImpostorDeal({required this.word, required this.category, required this.impostors, required this.startPlayer});
  final String word;
  final String category;

  /// Plätze (Index in der Namensliste) der Impostor.
  final List<int> impostors;

  /// Wer anfängt, oder null. Nie ein Impostor, der hätte ja gar keinen Hinweis.
  final int? startPlayer;
}

typedef PickedWord = ({String word, String category});

/// Ein Wort aus den Kategorien, das noch nicht dran war. Sind alle verbraucht, geht es von vorne los.
PickedWord pickWord(List<String> categories, List<String> usedWords, Random random) {
  final inCategories = <PickedWord>[
    for (final c in gameData.categories)
      if (categories.contains(c.name))
        for (final word in c.words) (word: word, category: c.name),
  ];
  if (inCategories.isEmpty) throw StateError('Bitte wähle mindestens eine Kategorie.');
  final unused = [
    for (final w in inCategories)
      if (!usedWords.contains(w.word)) w,
  ];
  final candidates = unused.isNotEmpty ? unused : inCategories;
  return candidates[(random() * candidates.length).floor()];
}

ImpostorDeal dealImpostor(int playerCount, ImpostorOptions options, List<String> usedWords, Random random) {
  final problem = impostorProblem(playerCount, options.impostorCount);
  if (problem != null) throw StateError(problem);

  final picked = pickWord(options.categories, usedWords, random);
  final seats = shuffled(List.generate(playerCount, (i) => i), random);
  final impostors = seats.sublist(0, options.impostorCount)..sort();
  final crew = seats.sublist(options.impostorCount);
  final startPlayer = options.randomStartPlayer ? crew[(random() * crew.length).floor()] : null;
  return ImpostorDeal(word: picked.word, category: picked.category, impostors: impostors, startPlayer: startPlayer);
}

// ---- Tabu ------------------------------------------------------------

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
  if (playerCount < needed) return 'Für $teamCount Teams braucht es mindestens $needed Spieler.';
  if (autoTeams) return null;
  final picks = List.generate(playerCount, (i) => i < chosen.length ? chosen[i] : null);
  final unassigned = picks.where((t) => t == null || t >= teamCount).length;
  if (unassigned > 0) {
    return unassigned == 1 ? '1 Spieler hat noch kein Team.' : '$unassigned Spieler haben noch kein Team.';
  }
  for (var team = 0; team < teamCount; team++) {
    if (picks.where((t) => t == team).length < Tabu.minTeamSize) {
      return 'Jedes Team braucht mindestens ${Tabu.minTeamSize} Spieler.';
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

// ---- Nobody is Perfect -----------------------------------------------

/// Eine Antwort zur Auswahl. [author] ist der Platz des Erfinders, null bei der echten.
class NobodyIsPerfectChoiceData {
  const NobodyIsPerfectChoiceData(this.id, this.text, this.author);
  final String id;
  final String text;
  final int? author;
}

/// Ein laufendes Nobody-is-Perfect-Spiel. Spieler sind Plätze (Index in der Namensliste).
class NobodyIsPerfectMatch {
  NobodyIsPerfectMatch(int playerCount, this.questions)
    : scores = List.filled(playerCount, 0),
      gained = List.filled(playerCount, 0),
      answers = List.filled(playerCount, null),
      guesses = List.filled(playerCount, null);

  final List<NobodyIsPerfectQuestion> questions;
  int index = 0;
  final List<int> scores;

  /// Punkte für die zuletzt aufgelöste Frage.
  List<int> gained;

  /// Pro Platz die erfundene Antwort zur aktuellen Frage.
  final List<String?> answers;

  /// Leer, solange noch geschrieben wird.
  List<NobodyIsPerfectChoiceData> choices = [];

  /// Pro Platz der Buchstabe, auf den getippt wurde.
  final List<String?> guesses;
}

/// Zieht Fragen, die noch nicht dran waren. Reichen die nicht, kommen auch alte wieder.
List<NobodyIsPerfectQuestion> pickQuestions(int count, List<String> used, Random random) {
  final fresh = shuffled(gameData.questions.where((q) => !used.contains(q.question)), random);
  final old = shuffled(gameData.questions.where((q) => used.contains(q.question)), random);
  return [...fresh, ...old].take(count).toList();
}

/// Gibt zurück, was an der Antwort nicht stimmt, oder null.
String? submitLie(NobodyIsPerfectMatch match, int seat, String raw) {
  final answer = cleanName(raw);
  if (answer.isEmpty) return 'Bitte schreib eine Antwort.';
  if (answer.length > NobodyIsPerfectRules.maxAnswerLength) {
    return 'Die Antwort darf höchstens ${NobodyIsPerfectRules.maxAnswerLength} Zeichen lang sein.';
  }
  match.answers[seat] = answer;
  return null;
}

/// Erfundene Antworten und die echte gemischt, mit Buchstaben A, B, C …
void mixChoices(NobodyIsPerfectMatch match, Random random) {
  final all = <({String text, int? author})>[
    for (var seat = 0; seat < match.answers.length; seat++)
      if (match.answers[seat] case final text?) (text: text, author: seat),
    (text: match.questions[match.index].answer, author: null),
  ];
  final mixed = shuffled(all, random);
  match.choices = [
    for (var i = 0; i < mixed.length; i++)
      NobodyIsPerfectChoiceData(String.fromCharCode(65 + i), mixed[i].text, mixed[i].author),
  ];
}

NobodyIsPerfectChoiceData? _choice(NobodyIsPerfectMatch match, String? id) {
  for (final c in match.choices) {
    if (c.id == id) return c;
  }
  return null;
}

/// Gibt zurück, warum der Tipp nicht geht, oder null.
String? guessChoice(NobodyIsPerfectMatch match, int seat, String id) {
  final choice = _choice(match, id);
  if (choice == null) return 'Diese Antwort gibt es nicht.';
  if (choice.author == seat) return 'Auf deine eigene Antwort kannst du nicht tippen.';
  match.guesses[seat] = id;
  return null;
}

/// Richtig getippt: +1. Jeder, der auf die eigene Erfindung hereinfällt: +1 für den Erfinder.
void revealQuestion(NobodyIsPerfectMatch match) {
  match.gained = List.filled(match.scores.length, 0);
  for (var seat = 0; seat < match.guesses.length; seat++) {
    final choice = _choice(match, match.guesses[seat]);
    if (choice == null) continue;
    match.gained[choice.author ?? seat]++;
  }
  for (var seat = 0; seat < match.scores.length; seat++) {
    match.scores[seat] += match.gained[seat];
  }
}

bool isLastQuestion(NobodyIsPerfectMatch match) => match.index == match.questions.length - 1;

void nextQuestion(NobodyIsPerfectMatch match) {
  match.index++;
  match.answers.fillRange(0, match.answers.length, null);
  match.guesses.fillRange(0, match.guesses.length, null);
  match.gained = List.filled(match.scores.length, 0);
  match.choices = [];
}
