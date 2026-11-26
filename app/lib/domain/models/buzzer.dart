// Buzzer: Einstellung und Reihenfolge.
import 'json.dart';

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
      presses = parseList(j['presses'], BuzzerPress.fromJson),
      yourRank = j['yourRank'] as int?,
      canPress = j['canPress'] as bool;
  final bool lockout;
  final List<BuzzerPress> presses;
  final int? yourRank;
  final bool canPress;
}
