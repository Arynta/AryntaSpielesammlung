// Nobody is Perfect: Einstellungen, Antworten, Auflösung und Punkte.
import 'json.dart';

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
      guesserIds = parseStrings(j['guesserIds']);
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
      participantIds = parseStrings(j['participantIds']),
      answeredIds = parseStrings(j['answeredIds']),
      yourAnswer = j['yourAnswer'] as String?,
      choices = parseList(j['choices'], NobodyIsPerfectChoice.fromJson),
      yourChoiceId = j['yourChoiceId'] as String?,
      guessedIds = parseStrings(j['guessedIds']),
      yourGuess = j['yourGuess'] as String?,
      reveal = parseList(j['reveal'], NobodyIsPerfectReveal.fromJson),
      scores = parseList(j['scores'], NobodyIsPerfectScore.fromJson);
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
