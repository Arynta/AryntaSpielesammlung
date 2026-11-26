// Nobody is Perfect lokal, wie NobodyIsPerfectGame im Backend.
import '../../data/repositories/game_data.dart';
import 'common.dart';

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
