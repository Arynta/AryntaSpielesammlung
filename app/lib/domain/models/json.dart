// JSON der Leitung und kleine Helfer zum Lesen.

typedef Json = Map<String, dynamic>;

List<T> parseList<T>(Object? raw, T Function(Json) parse) => [for (final item in raw as List) parse(item as Json)];

List<String> parseStrings(Object? raw) => List<String>.from(raw as List);

T? parseOptional<T>(Object? raw, T Function(Json) parse) => raw == null ? null : parse(raw as Json);
