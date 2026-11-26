// Zufall und Spielernamen für alle lokalen Spiele.
import 'dart:math' as math;

/// Zufallszahl von 0 (inklusive) bis 1 (exklusive). Austauschbar für Tests.
typedef Random = double Function();

final Random systemRandom = math.Random().nextDouble;

List<T> shuffled<T>(Iterable<T> items, Random random) {
  final copy = List<T>.of(items);
  for (var i = copy.length - 1; i > 0; i--) {
    final j = (random() * (i + 1)).floor();
    final swap = copy[i];
    copy[i] = copy[j];
    copy[j] = swap;
  }
  return copy;
}

/// Leere Felder werden zu „Spieler 1“, „Spieler 2“ usw.
List<String> playerNames(int count, List<String> typed) => List.generate(count, (i) {
  final name = cleanName(i < typed.length ? typed[i] : '');
  return name.isEmpty ? 'Spieler ${i + 1}' : name;
});

final _invisible = RegExp(r'[\p{Cc}\p{Cf}\p{Co}\p{Cn}]', unicode: true);
final _whitespace = RegExp(r'\s');
final _spaces = RegExp(r'[\s\p{Z}]+', unicode: true);

/// Wie im Backend: unsichtbare Zeichen raus, Leerraum zusammenfassen.
String cleanName(String raw) =>
    raw.replaceAllMapped(_invisible, (m) => _whitespace.hasMatch(m[0]!) ? m[0]! : '').replaceAll(_spaces, ' ').trim();

String? duplicateName(List<String> names) {
  final seen = <String>{};
  for (final name in names) {
    if (!seen.add(name.toLowerCase())) return name;
  }
  return null;
}
