import 'dart:io';

import 'package:arynta/logic/game_data.dart';

/// Lädt die Spieldaten direkt aus dem Backend-Ordner, also ohne vorherigen Abgleich.
Future<void> loadGameData() async {
  gameData = await GameData.load((file) async => File('../backend/src/main/resources/games/$file').readAsStringSync());
}
