// Impostor: Einstellungen, Abstimmung und Ergebnis.
import 'json.dart';

enum ImpostorPart {
  crew('CREW'),
  impostor('IMPOSTOR'),
  gameMaster('GAME_MASTER');

  const ImpostorPart(this.wire);
  final String wire;
  static ImpostorPart parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

class ImpostorSettings {
  ImpostorSettings.fromJson(Json j)
    : impostorSeesCategory = j['impostorSeesCategory'] as bool,
      customWordSet = j['customWordSet'] as bool,
      customWord = j['customWord'] as String?,
      allCategories = parseStrings(j['allCategories']),
      selectedCategories = parseStrings(j['selectedCategories']),
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
    : impostorIds = parseStrings(j['impostorIds']),
      impostorNames = parseStrings(j['impostorNames']),
      word = j['word'] as String,
      category = j['category'] as String?,
      impostorCaught = j['impostorCaught'] as bool,
      votes = parseList(j['votes'], VoteCount.fromJson);
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
      fellowImpostors = parseStrings(j['fellowImpostors']),
      startPlayerId = j['startPlayerId'] as String?,
      gameMasterId = j['gameMasterId'] as String?,
      participantIds = parseStrings(j['participantIds']),
      votedIds = parseStrings(j['votedIds']),
      yourVote = j['yourVote'] as String?,
      result = parseOptional(j['result'], ImpostorResult.fromJson);
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
