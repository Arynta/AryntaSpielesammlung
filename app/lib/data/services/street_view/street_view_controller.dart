import '../../../domain/models/models.dart';

/// Liest aus dem eigenen Viewer, wohin man gerade schaut, um einen Fund zu melden.
class StreetViewController {
  Future<GeoBingoSpot?> Function()? _reader;

  /// Der Viewer meldet sich hier an ([reader]) und beim Schließen wieder ab (null).
  void attach(Future<GeoBingoSpot?> Function()? reader) => _reader = reader;

  /// null, solange kein Bild geladen ist.
  Future<GeoBingoSpot?> currentSpot() => _reader?.call() ?? Future.value();
}
