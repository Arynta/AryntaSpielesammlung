// Was beide Straßenbild-Viewer im Browser können (Google Street View und Mapillary).
import 'package:web/web.dart' as web;

import '../../../domain/models/models.dart';

abstract interface class Viewer {
  /// Öffnet den Viewer in [container] beim ersten Bild nahe [start].
  /// Wirft [StreetViewProblem], wenn es dort nichts zu sehen gibt.
  Future<void> open(web.HTMLElement container, ({double lat, double lng}) start);

  /// Springt zu einer gemeldeten Ansicht und merkt sich, wo man vorher war.
  Future<void> show(GeoBingoSpot spot);

  /// Zurück an die Stelle vor dem ersten [show].
  Future<void> back();

  /// Wohin man gerade schaut, null solange kein Bild geladen ist.
  Future<GeoBingoSpot?> read();

  /// Nach jeder Größenänderung des Rahmens.
  void resize();

  void close();
}

/// Ein Fehler, den man den Spielern so zeigen kann, wie er ist.
class StreetViewProblem implements Exception {
  const StreetViewProblem(this.message);
  final String message;

  @override
  String toString() => message;
}
