// Sprache der Oberfläche, wie Language im Backend.

/// Auf der Leitung und im Speicher klein geschrieben ("de", "en").
enum Language {
  de,
  en;

  String get wire => name;

  /// Unbekannt oder fehlend heißt Deutsch.
  static Language parse(Object? raw) => values.firstWhere((v) => v.wire == raw, orElse: () => de);

  Language get other => this == de ? en : de;
}
