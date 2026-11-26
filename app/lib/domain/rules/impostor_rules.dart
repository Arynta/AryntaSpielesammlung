// Impostor lokal, wie ImpostorOptions und ImpostorWords im Backend.
import 'dart:math' as math;

import '../../data/repositories/game_data.dart';
import '../models/models.dart';
import 'common.dart';

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
