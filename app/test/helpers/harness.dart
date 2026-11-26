// Gemeinsames für die Oberflächentests: Nachbau der Verbindung, echte Schriften, Handygröße.
import 'dart:convert';
import 'dart:io';

import 'package:arynta/ui/core/view_model/app_controller.dart';
import 'package:arynta/data/services/connection.dart';
import 'package:arynta/domain/models/models.dart';
import 'package:arynta/data/services/storage/storage_base.dart';
import 'package:arynta/ui/core/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

/// Merkt sich, was an den Server gegangen wäre.
class FakeLink implements GameLink {
  FakeLink(this.onStatus, this.onOpen);

  final void Function(ConnectionStatus) onStatus;
  final void Function() onOpen;
  final sent = <Json>[];
  bool online = true;

  List<String> get types => [for (final m in sent) m['type'] as String];

  @override
  Future<void> start() async {
    onStatus(ConnectionStatus.online);
    onOpen();
  }

  @override
  bool send(ClientMessage msg) {
    if (online) sent.add(msg.json);
    return online;
  }

  @override
  void resume() {}

  @override
  void dispose() {}
}

/// Ansichten, die tool/record_states.dart vom echten Server mitgeschrieben hat.
Map<String, Json> loadFixtures() =>
    (jsonDecode(File('test/fixtures/states.json').readAsStringSync()) as Map).cast<String, Json>();

Future<void> loadFonts() async {
  const families = {
    'Atkinson Hyperlegible': ['atkinson-hyperlegible-latin-400', 'atkinson-hyperlegible-latin-700'],
    'Atkinson Hyperlegible Ext': ['atkinson-hyperlegible-latin-ext-400', 'atkinson-hyperlegible-latin-ext-700'],
    'Grenze': ['grenze-latin-800'],
    'Grenze Ext': ['grenze-latin-ext-800'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file.ttf').readAsBytesSync())));
    }
    await loader.load();
  }
}

Future<void> prepare() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadGameData();
  await loadFonts();
}

class TestApp {
  TestApp(this.controller, this.link, this.storage);

  final AppController controller;
  final FakeLink link;
  final MemoryStorage storage;

  void receive(Json message) => controller.handleMessage(ServerMessage.fromJson(message));

  void show(Json state) => receive({'type': 'state', 'state': state});
}

Future<TestApp> pumpApp(
  WidgetTester tester, {
  Size size = const Size(360, 740),
  MemoryStorage? storage,
  Widget Function(Widget app)? wrap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = storage ?? MemoryStorage();
  late FakeLink link;
  final controller = AppController(
    storage: store,
    createLink: (onMessage, onStatus, onOpen) => link = FakeLink(onStatus, onOpen),
  );
  final app = AryntaApp(controller);
  await tester.pumpWidget(wrap?.call(app) ?? app);
  await controller.start();
  await tester.pump();
  // Erst die Oberfläche abbauen, dann den Zustand, damit keine Uhr weiterläuft
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  return TestApp(controller, link, store);
}
