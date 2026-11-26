// Holt Spieldaten und Bilder aus dem Rest des Projekts in app/assets/game/. Die Originale bleiben die
// einzige Quelle, die Kopien stehen in .gitignore. Vor "flutter run", "flutter test" und
// "flutter build" aufrufen: dart run tool/sync_assets.dart
import 'dart:io';

const sources = [
  '../backend/src/main/resources/games/impostor-words.json',
  '../backend/src/main/resources/games/werwolf-roles.json',
  '../backend/src/main/resources/games/tabu-cards.json',
  '../backend/src/main/resources/games/nobody-is-perfect-questions.json',
  '../assets/images/Werwolf/Werwolf_werwolf1.png',
];

void main() {
  final app = File.fromUri(Platform.script).parent.parent.uri;
  final target = Directory.fromUri(app.resolve('assets/game/'))..createSync(recursive: true);
  for (final source in sources) {
    final file = File.fromUri(app.resolve(source));
    final name = file.uri.pathSegments.last;
    file.copySync(target.uri.resolve(name).toFilePath());
    stdout.writeln('assets/game/$name');
  }
}
