// Verbindung gegen einen kleinen WebSocket-Server auf diesem Rechner.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arynta/logic/connection.dart';
import 'package:arynta/logic/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Adresse zum Aufwecken', () {
    expect(healthUrl(Uri.parse('wss://beispiel.onrender.com/ws')).toString(), 'https://beispiel.onrender.com/health');
    expect(healthUrl(Uri.parse('ws://localhost:8080/ws?x=1')).toString(), 'http://localhost:8080/health');
  });

  test('verbindet, empfängt, überlebt Unsinn und baut nach einem Abbruch neu auf', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = StreamController<WebSocket>();
    final received = <Object?>[];
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((data) => received.add(jsonDecode(data as String)));
      sockets.add(socket);
    });
    final incoming = StreamIterator(sockets.stream);

    final statuses = <ConnectionStatus>[];
    final messages = <ServerMessage>[];
    var opened = 0;
    late final GameConnection connection;
    connection = GameConnection(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
      onMessage: messages.add,
      onStatus: statuses.add,
      onOpen: () {
        opened++;
        connection.send(ClientMessage.ping());
      },
      wake: (_) async => throw const SocketException('schläft noch'),
    );
    addTearDown(() async {
      connection.dispose();
      await incoming.cancel();
      await server.close(force: true);
      unawaited(sockets.close());
    });

    expect(connection.send(ClientMessage.ping()), isFalse);
    await connection.start();
    expect(await incoming.moveNext(), isTrue);
    final first = incoming.current;
    first
      ..add('kein JSON')
      ..add('{"type":"gibtsnicht"}')
      ..add('{"type":"error","message":"Hallo"}');
    await until(() => messages.isNotEmpty && received.isNotEmpty);
    expect((messages.single as ErrorMessage).message, 'Hallo');
    expect(received.single, {'type': 'ping'});
    expect(statuses.last, ConnectionStatus.online);

    unawaited(first.close());
    await until(() => statuses.contains(ConnectionStatus.offline));
    expect(await incoming.moveNext(), isTrue);
    await until(() => opened == 2);
    expect(
      statuses,
      containsAllInOrder([
        ConnectionStatus.waking,
        ConnectionStatus.online,
        ConnectionStatus.offline,
        ConnectionStatus.connecting,
        ConnectionStatus.online,
      ]),
    );
  });

  test('versucht es weiter, wenn niemand antwortet', () async {
    // Ein Port, auf dem gerade nichts lauscht
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final statuses = <ConnectionStatus>[];
    final connection = GameConnection(
      Uri.parse('ws://127.0.0.1:$port/ws'),
      onMessage: (_) {},
      onStatus: statuses.add,
      onOpen: () => fail('darf nicht öffnen'),
      wake: (_) async {},
    );
    addTearDown(connection.dispose);
    await connection.start();
    await until(() => statuses.where((s) => s == ConnectionStatus.offline).length >= 2);
  });
}

/// Wartet höchstens zehn Sekunden, bis [done] zutrifft.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 500; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Zeit abgelaufen');
}
