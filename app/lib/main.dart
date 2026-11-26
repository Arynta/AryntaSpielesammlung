import 'package:material_ui/material_ui.dart';

import 'ui/core/view_model/app_controller.dart';
import 'data/services/connection.dart';
import 'data/repositories/game_data.dart';
import 'data/services/storage/storage.dart';
import 'ui/core/app.dart';

/// Adresse des Backends: --dart-define=BACKEND_URL=wss://…/ws. Lokal brauchst du nichts einzutragen.
const _configuredUrl = String.fromEnvironment('BACKEND_URL');
const _localUrl = 'ws://localhost:8080/ws';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  gameDataByLanguage = await GameData.loadAll();
  final url = Uri.parse(_configuredUrl.isEmpty ? _localUrl : _configuredUrl);
  final controller = AppController(
    storage: await openStorage(),
    initialCode: Uri.base.queryParameters['raum'] ?? '',
    createLink: (onMessage, onStatus, onOpen) =>
        GameConnection(url, onMessage: onMessage, onStatus: onStatus, onOpen: onOpen),
  );
  runApp(AryntaApp(controller));
  await controller.start();
}
