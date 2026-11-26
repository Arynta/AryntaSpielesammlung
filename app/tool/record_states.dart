// Spielt mit mehreren Verbindungen alle Spiele gegen ein laufendes Backend durch. Prüft dabei, dass der
// Server jede Nachricht annimmt und jede Antwort in die Datenmodelle passt, und schreibt typische
// Ansichten nach test/fixtures/states.json (Grundlage für test/ui/views_test.dart).
//
// Backend starten, dann in app/: dart run tool/record_states.dart [ws://localhost:8080/ws]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arynta/domain/models/models.dart';

class Client {
  Client._(this.name, this._socket);

  final String name;
  final WebSocket _socket;
  late String secret;
  late String code;
  Json? raw;
  RoomView get room => RoomView.fromJson(raw!);
  final errors = <String>[];
  final types = <String>[];
  Completer<void>? _pong;

  static Future<Client> connect(String url, String name) async {
    // Ohne Origin-Kopfzeile, genau wie später die Android- und iOS-App
    final client = Client._(name, await WebSocket.connect(url));
    client._socket.listen((data) {
      final json = jsonDecode(data as String) as Json;
      final msg = ServerMessage.fromJson(json); // wirft, wenn Modell und Server nicht zusammenpassen
      client.types.add(json['type'] as String);
      switch (msg) {
        case Joined(:final code, :final secret):
          client.code = code;
          client.secret = secret;
        case StateMessage():
          client.raw = json['state'] as Json;
        case ErrorMessage(:final message):
          client.errors.add(message);
        case Pong():
          client._pong?.complete();
        case LeftRoom() || Kicked():
          break;
      }
    });
    return client;
  }

  void send(ClientMessage msg) => _socket.add(jsonEncode(msg.json));

  /// Wartet, bis alles Bisherige beantwortet ist.
  Future<void> settle() async {
    _pong = Completer();
    send(ClientMessage.ping());
    await _pong!.future.timeout(const Duration(seconds: 5));
  }

  Future<void> close() => _socket.close();
}

final fixtures = <String, Json>{};
late List<Client> all;

Future<void> act(Client who, ClientMessage msg) async {
  who.send(msg);
  await who.settle();
  for (final c in all) {
    await c.settle();
  }
  if (who.errors.isNotEmpty) {
    throw StateError('${who.name}: ${msg.json} → ${who.errors}');
  }
}

void keep(String name, Client c) => fixtures[name] = c.raw!;

void check(bool ok, String what) {
  if (!ok) throw StateError('Erwartung nicht erfüllt: $what');
}

Future<void> readyAll() async {
  for (final c in all) {
    await act(c, ClientMessage.setReady(true));
  }
}

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'ws://localhost:8080/ws' : args.first;
  const names = ['Anna', 'Ben', 'Cem', 'Dana', 'Elif'];
  all = [for (final n in names) await Client.connect(url, n)];
  final [host, ben, ...rest] = all;

  await act(host, ClientMessage.create(host.name, Language.de));
  for (final c in [ben, ...rest]) {
    await act(c, ClientMessage.join(host.code, c.name, Language.de));
  }
  await act(ben, ClientMessage.rejoin(host.code, ben.secret, Language.de));
  // Jeder sieht die Lobby in seiner Sprache
  await act(ben, ClientMessage.setLanguage(Language.en));
  check(ben.room.games.first.name == 'Werewolf' && host.room.games.first.name == 'Werwolf', 'Sprache pro Spieler');
  await act(ben, ClientMessage.setLanguage(Language.de));
  await act(host, ClientMessage.setPlayerLimit(8));
  check(host.room.playerLimit.value == 8, 'Spielerlimit');

  // ---- Impostor ----
  await act(host, ClientMessage.setImpostorOptions(impostorCount: 1, randomStartPlayer: true));
  await act(host, ClientMessage.setImpostorCategories(['animals', 'places']));
  await act(host, ClientMessage.configureImpostor(impostorSeesCategory: true, customWord: ''));
  keep('lobby_impostor_host', host);
  keep('lobby_impostor_guest', ben);
  await readyAll();
  await act(host, ClientMessage.start());
  final impostor = all.firstWhere((c) => c.room.impostor!.part == ImpostorPart.impostor);
  final crew = all.firstWhere((c) => c.room.impostor!.part == ImpostorPart.crew);
  keep('impostor_word_crew', crew);
  keep('impostor_word_impostor', impostor);
  await act(host, ClientMessage.startVoting());
  await act(crew, ClientMessage.vote(impostor.room.you.id));
  keep('impostor_voting', crew);
  for (final c in all.where((c) => c != crew)) {
    final target = c == impostor ? crew : impostor;
    await act(c, ClientMessage.vote(target.room.you.id));
  }
  check(host.room.phase == Phase.result, 'Impostor-Ergebnis');
  keep('impostor_result_host', host);
  keep('impostor_result_guest', ben);
  await readyAll();
  await act(host, ClientMessage.nextRound());
  await act(host, ClientMessage.backToLobby());

  await act(host, ClientMessage.configureImpostor(impostorSeesCategory: false, customWord: 'Leuchtturm'));
  keep('lobby_impostor_custom_word', host);
  await readyAll();
  await act(host, ClientMessage.start());
  keep('impostor_game_master', host);
  await act(host, ClientMessage.startVoting());
  keep('impostor_voting_game_master', host);
  await act(host, ClientMessage.backToLobby());

  // ---- Werwolf ----
  await act(host, ClientMessage.selectGame(GameType.werwolf));
  await act(host, ClientMessage.configureWerwolf(werewolfCount: 1, roles: ['SEHERIN', 'DIEB'], hostIsGameMaster: true));
  keep('lobby_werwolf_host', host);
  keep('lobby_werwolf_guest', ben);
  await readyAll();
  await act(host, ClientMessage.start());
  keep('werwolf_night_game_master', host);
  keep('werwolf_night_player', ben);
  await act(host, ClientMessage.nextPhase());
  keep('werwolf_day_game_master', host);
  keep('werwolf_day_player', ben);
  await act(host, ClientMessage.backToLobby());
  await act(host, ClientMessage.configureWerwolf(werewolfCount: null, roles: ['GUENSTLING'], hostIsGameMaster: false));
  await readyAll();
  await act(host, ClientMessage.start());
  keep('werwolf_night_wolf', all.firstWhere((c) => c.room.werwolf!.role!.id == 'WERWOLF'));
  await act(host, ClientMessage.backToLobby());

  // ---- Tabu ----
  await act(host, ClientMessage.selectGame(GameType.tabu));
  await act(host, ClientMessage.configureTabu(turnSeconds: 180, autoTeams: false, teamCount: 2, targetScore: 10));
  await act(ben, ClientMessage.chooseTeam(1));
  await act(host, ClientMessage.chooseTeam(0));
  keep('lobby_tabu_teams_host', host);
  keep('lobby_tabu_teams_guest', ben);
  await act(host, ClientMessage.chooseTeam(0, targetId: rest[0].room.you.id));
  await act(host, ClientMessage.chooseTeam(1, targetId: rest[1].room.you.id));
  await act(host, ClientMessage.chooseTeam(0, targetId: rest[2].room.you.id));
  await readyAll();
  await act(host, ClientMessage.start());
  Client byId(String id) => all.firstWhere((c) => c.room.you.id == id);
  var tabu = host.room.tabu!;
  final explainer = byId(tabu.explainerId);
  final watcher = byId(tabu.watcherId);
  final guesser = all.firstWhere((c) => c != explainer && c.room.tabu!.yourTeam == tabu.currentTeam);
  final other = all.firstWhere((c) => c != watcher && c.room.tabu!.yourTeam != tabu.currentTeam);
  keep('tabu_ready_explainer', explainer);
  keep('tabu_ready_watcher', watcher);
  keep('tabu_ready_other', other);
  await act(explainer, ClientMessage.startTurn());
  await act(explainer, ClientMessage.wordCorrect());
  await act(explainer, ClientMessage.wordSkip());
  await act(watcher, ClientMessage.buzz());
  keep('tabu_turn_explainer', explainer);
  keep('tabu_turn_watcher', watcher);
  keep('tabu_turn_guesser', guesser);
  keep('tabu_turn_other', other);
  for (var i = 0; i < 9; i++) {
    await act(explainer, ClientMessage.wordCorrect());
  }
  check(host.room.tabu!.winnerTeam != null, 'Tabu-Sieger');
  keep('tabu_over_host', host);
  keep('tabu_over_guest', ben);
  await act(host, ClientMessage.backToLobby());

  // ---- Nobody is Perfect ----
  await act(host, ClientMessage.selectGame(GameType.nobodyIsPerfect));
  await act(host, ClientMessage.configureNobodyIsPerfect(3));
  keep('lobby_nobody_host', host);
  keep('lobby_nobody_guest', ben);
  await readyAll();
  await act(host, ClientMessage.start());
  for (var question = 1; question <= 3; question++) {
    await act(ben, ClientMessage.submitAnswer('Erfunden von Ben $question'));
    if (question == 1) keep('nobody_writing_submitted', ben);
    if (question == 1) keep('nobody_writing_host', host);
    for (final c in all.where((c) => c != ben)) {
      await act(c, ClientMessage.submitAnswer('Erfunden von ${c.name} $question'));
    }
    check(host.room.phase == Phase.guessing, 'Tippen');
    final benChoice = ben.room.nobodyIsPerfect!.yourChoiceId!;
    await act(host, ClientMessage.guessAnswer(benChoice));
    if (question == 1) keep('nobody_guessing', host);
    if (question == 2) {
      await act(host, ClientMessage.skipWaiting());
    } else {
      for (final c in all.where((c) => c != host)) {
        final choice = c.room.nobodyIsPerfect!.choices.firstWhere((x) => x.id != c.room.nobodyIsPerfect!.yourChoiceId);
        await act(c, ClientMessage.guessAnswer(choice.id));
      }
    }
    if (question < 3) {
      if (question == 1) keep('nobody_reveal_host', host);
      if (question == 1) keep('nobody_reveal_guest', ben);
      await act(host, ClientMessage.nextQuestion());
    }
  }
  // Nach der letzten Frage geht es je nach Server direkt oder über "nächste Frage" zum Ende
  if (host.room.phase == Phase.reveal) await act(host, ClientMessage.nextQuestion());
  keep('nobody_over_host', host);
  keep('nobody_over_guest', ben);
  await act(host, ClientMessage.backToLobby());

  // ---- Buzzer ----
  await act(host, ClientMessage.selectGame(GameType.buzzer));
  await act(host, ClientMessage.configureBuzzer(false));
  keep('lobby_buzzer_host', host);
  keep('lobby_buzzer_guest', ben);
  await readyAll();
  await act(host, ClientMessage.start());
  keep('buzzer_host_empty', host);
  keep('buzzer_player_open', ben);
  await act(ben, ClientMessage.pressBuzzer());
  await act(rest[0], ClientMessage.pressBuzzer());
  keep('buzzer_host_pressed', host);
  keep('buzzer_player_first', ben);
  keep('buzzer_player_second', rest[0]);
  await act(host, ClientMessage.releaseBuzzer());
  await act(host, ClientMessage.backToLobby());

  // ---- Geo-Bingo ----
  await act(host, ClientMessage.selectGame(GameType.geoBingo));
  await act(host, ClientMessage.configureGeoBingo(15));
  keep('lobby_geo_bingo_host', host);
  keep('lobby_geo_bingo_guest', ben);
  await readyAll();
  await act(host, ClientMessage.start());
  keep('geo_bingo_start', ben);
  for (final field in [0, 1, 2]) {
    await act(ben, ClientMessage.claimGeoBingoField(field, const GeoBingoSpot(imageId: '123', x: 0.4, y: 0.5, zoom: 1)));
    if (field == 1) {
      keep('geo_bingo_claimer', ben);
      keep('geo_bingo_vote', host);
    }
    final claimId = host.room.geoBingo!.claims.single.id;
    for (final c in all.where((c) => c != ben)) {
      await act(c, ClientMessage.voteGeoBingo(claimId, true));
    }
  }
  check(host.room.phase == Phase.result, 'Geo-Bingo-Reihe');
  keep('geo_bingo_over_host', host);
  keep('geo_bingo_over_guest', ben);
  await act(host, ClientMessage.backToLobby());

  // ---- Entfernen und Verlassen ----
  final last = all.last;
  await host.settle();
  host.send(ClientMessage.kick(last.room.you.id));
  await host.settle();
  await last.settle();
  check(last.types.contains('kicked'), 'Rauswurf');
  ben.send(ClientMessage.leave());
  await ben.settle();
  check(ben.types.contains('left'), 'Verlassen');
  for (final c in all) {
    check(c.errors.isEmpty, '${c.name} ohne Fehler: ${c.errors}');
    await c.close();
  }

  final out = File.fromUri(Platform.script.resolve('../test/fixtures/states.json'));
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(fixtures)}\n');
  stdout.writeln('${fixtures.length} Ansichten nach ${out.path} geschrieben.');
}
