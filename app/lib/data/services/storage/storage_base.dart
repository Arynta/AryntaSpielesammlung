import 'dart:convert';

abstract class Storage {
  String? read(String key);

  /// [value] null löscht den Eintrag.
  void write(String key, String? value);

  /// Liest JSON. Fehlt der Eintrag oder ist er kaputt, kommt null zurück.
  Object? readJson(String key) {
    final raw = read(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  void writeJson(String key, Object? value) => write(key, value == null ? null : jsonEncode(value));
}

/// Nur im Arbeitsspeicher: für Tests.
class MemoryStorage extends Storage {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String? value) {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
