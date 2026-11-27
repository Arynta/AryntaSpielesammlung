// Geo-Bingo: Einstellung, Karte, Funde und Abstimmungen.
import 'json.dart';

/// [size]: Felder pro Reihe. [motifs]: eigene Begriffe des Hosts, den Rest füllt die Standardliste auf.
class GeoBingoSettings {
  GeoBingoSettings.fromJson(Json j)
    : minutes = j['minutes'] as int,
      minMinutes = j['minMinutes'] as int,
      maxMinutes = j['maxMinutes'] as int,
      size = j['size'] as int,
      minSize = j['minSize'] as int,
      maxSize = j['maxSize'] as int,
      motifs = parseStrings(j['motifs']),
      maxMotifs = j['maxMotifs'] as int,
      maxMotifLength = j['maxMotifLength'] as int;
  final int minutes;
  final int minMinutes;
  final int maxMinutes;
  final int size;
  final int minSize;
  final int maxSize;
  final List<String> motifs;
  final int maxMotifs;
  final int maxMotifLength;
}

/// Woher die Straßenbilder einer Runde kommen. Google nur, solange das Tageslimit des Servers reicht.
enum StreetViewSource {
  google('GOOGLE'),
  mapillary('MAPILLARY');

  const StreetViewSource(this.wire);
  final String wire;
  static StreetViewSource parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

/// Genau die Ansicht im Straßenbild, die jemand gemeldet hat: Bild, Blickpunkt (0 bis 1) und Zoom.
/// Bei Google ist x die Himmelsrichtung und y der Blick nach oben oder unten, beides auf 0 bis 1 umgerechnet.
class GeoBingoSpot {
  const GeoBingoSpot({required this.imageId, required this.x, required this.y, required this.zoom});
  final String imageId;
  final double x;
  final double y;
  final double zoom;

  // Jeder Stand vom Server baut neue Objekte. Ohne Vergleich spränge der Viewer bei jedem Stand neu zum Fund.
  @override
  bool operator ==(Object other) =>
      other is GeoBingoSpot && other.imageId == imageId && other.x == x && other.y == y && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(imageId, x, y, zoom);
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
      source = StreetViewSource.parse(j['source']),
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
  final StreetViewSource source;
  final List<String> board;
  final int remainingMs;
  final List<GeoBingoScore> scores;
  final List<GeoBingoClaim> claims;
  final List<GeoBingoDecision> decisions;
  final List<String> winnerIds;
  final List<int>? winningLine;

  List<int> fieldsOf(String playerId) => scores.where((s) => s.playerId == playerId).firstOrNull?.fields ?? const [];
}
