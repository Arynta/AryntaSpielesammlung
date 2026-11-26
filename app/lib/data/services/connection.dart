import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/models/models.dart';

enum ConnectionStatus { waking, connecting, online, offline }

/// Was die Oberfläche von der Verbindung braucht. Tests setzen hier einen Nachbau ein.
abstract class GameLink {
  Future<void> start();

  /// false, wenn gerade keine Verbindung steht.
  bool send(ClientMessage msg);

  /// Aufrufen, wenn die App wieder sichtbar ist (Handy entsperrt, Tab nach vorne geholt).
  void resume();

  void dispose();
}

typedef ChannelFactory = WebSocketChannel Function(Uri url);

const _pingEvery = Duration(seconds: 25);
const _firstRetryDelay = Duration(seconds: 1);
const _maxRetryDelay = Duration(seconds: 10);

/// Hält die WebSocket-Verbindung zum Backend offen und baut sie nach
/// Abbrüchen (Handy gesperrt, WLAN gewechselt) selbst wieder auf.
class GameConnection implements GameLink {
  GameConnection(
    this.url, {
    required this.onMessage,
    required this.onStatus,
    required this.onOpen,
    ChannelFactory? channelFactory,
    Future<void> Function(Uri healthUrl)? wake,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect,
       _wake = wake ?? _wakeServer;

  final Uri url;
  final void Function(ServerMessage msg) onMessage;
  final void Function(ConnectionStatus status) onStatus;

  /// Wird nach jedem (Wieder-)Verbinden aufgerufen, z. B. um sich im Raum zurückzumelden.
  final void Function() onOpen;

  final ChannelFactory _channelFactory;
  final Future<void> Function(Uri) _wake;

  /// Gesetzt, solange eine Verbindung aufgebaut wird oder offen ist.
  WebSocketChannel? _channel;
  bool _open = false;
  Duration _retryDelay = _firstRetryDelay;
  Timer? _pingTimer;
  Timer? _retryTimer;
  bool _everConnected = false;
  bool _started = false;
  bool _disposed = false;

  @override
  Future<void> start() async {
    // Render Free legt den Server nach 15 Minuten schlafen. Ein normaler HTTP-Aufruf weckt ihn auf.
    onStatus(ConnectionStatus.waking);
    try {
      await _wake(healthUrl(url));
    } catch (_) {
      // egal, der WebSocket-Versuch danach zeigt, ob der Server da ist
    }
    _started = true;
    _connect();
  }

  @override
  bool send(ClientMessage msg) {
    if (!_open) return false;
    _channel!.sink.add(jsonEncode(msg.json));
    return true;
  }

  @override
  void resume() {
    if (!_started || _open) return;
    _retryDelay = _firstRetryDelay;
    _connect();
  }

  @override
  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _retryTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _open = false;
  }

  void _connect() {
    if (_disposed || _channel != null) return; // verbindet schon oder ist offen
    _retryTimer?.cancel();
    onStatus(_everConnected ? ConnectionStatus.connecting : ConnectionStatus.waking);
    final WebSocketChannel channel;
    try {
      channel = _channelFactory(url);
    } catch (e) {
      debugPrint('Verbindung nicht möglich: $e');
      _scheduleRetry();
      return;
    }
    _channel = channel;

    channel.stream.listen(_receive, onError: (Object _) => _closed(channel), onDone: () => _closed(channel));
    channel.ready.then((_) => _opened(channel), onError: (Object _) => _closed(channel));
  }

  void _opened(WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;
    _open = true;
    _everConnected = true;
    _retryDelay = _firstRetryDelay;
    onStatus(ConnectionStatus.online);
    _pingTimer = Timer.periodic(_pingEvery, (_) => send(ClientMessage.ping()));
    onOpen();
  }

  void _receive(Object? data) {
    final ServerMessage msg;
    try {
      msg = ServerMessage.fromJson(jsonDecode(data as String) as Json);
    } catch (e) {
      debugPrint('Kaputte Nachricht vom Server: $e');
      return;
    }
    onMessage(msg);
  }

  void _closed(WebSocketChannel channel) {
    if (_disposed || !identical(_channel, channel)) return;
    _pingTimer?.cancel();
    _channel = null;
    _open = false;
    onStatus(ConnectionStatus.offline);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(_retryDelay, _connect);
    final doubled = _retryDelay * 2;
    _retryDelay = doubled < _maxRetryDelay ? doubled : _maxRetryDelay;
  }
}

/// `wss://host/ws` → `https://host/health`
Uri healthUrl(Uri wsUrl) => Uri(
  scheme: wsUrl.scheme == 'wss' ? 'https' : 'http',
  userInfo: wsUrl.userInfo,
  host: wsUrl.host,
  port: wsUrl.hasPort ? wsUrl.port : null,
  path: '/health',
);

Future<void> _wakeServer(Uri url) async {
  // Der Zeitstempel verhindert, dass der Browser eine alte Antwort aus dem Zwischenspeicher nimmt
  final fresh = url.replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
  await http.get(fresh).timeout(const Duration(seconds: 90));
}
