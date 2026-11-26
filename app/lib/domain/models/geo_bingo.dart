// Geo-Bingo: Einstellung, Karte, Funde und Abstimmungen.
import 'json.dart';

class GeoBingoSettings {
  GeoBingoSettings.fromJson(Json j)
    : minutes = j['minutes'] as int,
      minMinutes = j['minMinutes'] as int,
      maxMinutes = j['maxMinutes'] as int;
  final int minutes;
  final int minMinutes;
  final int maxMinutes;
}

/// Genau die Ansicht im Straßenbild, die jemand gemeldet hat: Bild, Blickpunkt (0 bis 1) und Zoom.
class GeoBingoSpot {
  const GeoBingoSpot({required this.imageId, required this.x, required this.y, required this.zoom});
  final String imageId;
  final double x;
  final double y;
  final double zoom;
}

class GeoBingoScore {
  GeoBingoScore.fromJson(Json j) : playerId = j['playerId'] as String, fields = List<int>.from(j['fields'] as List);
  final String playerId;
  final List<int> fields;
}

class GeoBingoClaim {
  GeoBingoClaim.fromJson(Json j)
    : id = j['id'] as String,
      playerId = j['playerId'] as String,
      field = j['field'] as int,
      spot = GeoBingoSpot(
        imageId: j['imageId'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        zoom: (j['zoom'] as num).toDouble(),
      ),
      remainingMs = j['remainingMs'] as int,
      votedIds = parseStrings(j['votedIds']),
      yourVote = j['yourVote'] as bool?;
  final String id;
  final String playerId;
  final int field;
  final GeoBingoSpot spot;
  final int remainingMs;
  final List<String> votedIds;

  /// null, solange man nicht abgestimmt hat.
  final bool? yourVote;
}

class GeoBingoDecision {
  GeoBingoDecision.fromJson(Json j)
    : playerId = j['playerId'] as String,
      field = j['field'] as int,
      accepted = j['accepted'] as bool;
  final String playerId;
  final int field;
  final bool accepted;
}

/// winnerIds ist erst am Ende gefüllt, winningLine nur bei einer vollen Reihe.
class GeoBingoView {
  GeoBingoView.fromJson(Json j)
    : place = j['place'] as String,
      lat = (j['lat'] as num).toDouble(),
      lng = (j['lng'] as num).toDouble(),
      board = parseStrings(j['board']),
      remainingMs = j['remainingMs'] as int,
      scores = parseList(j['scores'], GeoBingoScore.fromJson),
      claims = parseList(j['claims'], GeoBingoClaim.fromJson),
      decisions = parseList(j['decisions'], GeoBingoDecision.fromJson),
      winnerIds = parseStrings(j['winnerIds']),
      winningLine = j['winningLine'] == null ? null : List<int>.from(j['winningLine'] as List);
  final String place;
  final double lat;
  final double lng;
  final List<String> board;
  final int remainingMs;
  final List<GeoBingoScore> scores;
  final List<GeoBingoClaim> claims;
  final List<GeoBingoDecision> decisions;
  final List<String> winnerIds;
  final List<int>? winningLine;

  List<int> fieldsOf(String playerId) => scores.where((s) => s.playerId == playerId).firstOrNull?.fields ?? const [];
}
