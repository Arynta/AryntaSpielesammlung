// Nachrichten vom Server und an den Server.
import 'json.dart';
import 'game.dart';
import 'language.dart';
import 'geo_bingo.dart';
import 'room.dart';

/// Was der Server schickt.
sealed class ServerMessage {
  const ServerMessage();

  /// Wirft bei unbekanntem Typ oder fehlenden Feldern.
  factory ServerMessage.fromJson(Json j) => switch (j['type']) {
    'joined' => Joined(j['code'] as String, j['secret'] as String),
    'state' => StateMessage(RoomView.fromJson(j['state'] as Json)),
    'left' => const LeftRoom(),
    'kicked' => const Kicked(),
    'error' => ErrorMessage(j['message'] as String, key: j['key'] as String?),
    'pong' => const Pong(),
    final type => throw FormatException('Unbekannte Nachricht: $type'),
  };
}

class Joined extends ServerMessage {
  const Joined(this.code, this.secret);
  final String code;
  final String secret;
}

class StateMessage extends ServerMessage {
  const StateMessage(this.state);
  final RoomView state;
}

class LeftRoom extends ServerMessage {
  const LeftRoom();
}

class Kicked extends ServerMessage {
  const Kicked();
}

class ErrorMessage extends ServerMessage {
  const ErrorMessage(this.message, {this.key});
  final String message;

  /// Schlüssel der Meldung im Server (i18n/messages.properties), z. B. error.rooms.unknown.
  final String? key;
}

class Pong extends ServerMessage {
  const Pong();
}

/// Was das Handy schickt.
class ClientMessage {
  ClientMessage._(String type, [Json fields = const {}]) : json = {'type': type, ...fields};
  final Json json;
  String get type => json['type'] as String;

  ClientMessage.create(String name, Language language) : this._('create', {'name': name, 'language': language.wire});
  ClientMessage.join(String code, String name, Language language)
    : this._('join', {'code': code, 'name': name, 'language': language.wire});
  ClientMessage.rejoin(String code, String secret, Language language)
    : this._('rejoin', {'code': code, 'secret': secret, 'language': language.wire});
  ClientMessage.setLanguage(Language language) : this._('setLanguage', {'language': language.wire});
  ClientMessage.leave() : this._('leave');
  ClientMessage.selectGame(GameType game) : this._('selectGame', {'game': game.wire});
  ClientMessage.setReady(bool ready) : this._('setReady', {'ready': ready});
  ClientMessage.configureImpostor({required bool impostorSeesCategory, required String customWord})
    : this._('configureImpostor', {'impostorSeesCategory': impostorSeesCategory, 'customWord': customWord});
  ClientMessage.start() : this._('start');
  ClientMessage.nextPhase() : this._('nextPhase');
  ClientMessage.startVoting() : this._('startVoting');
  ClientMessage.vote(String targetId) : this._('vote', {'targetId': targetId});
  ClientMessage.kick(String targetId) : this._('kick', {'targetId': targetId});
  ClientMessage.setPlayerLimit(int playerLimit) : this._('setPlayerLimit', {'playerLimit': playerLimit});
  ClientMessage.setImpostorCategories(List<String> categories)
    : this._('setImpostorCategories', {'categories': categories});
  ClientMessage.setImpostorOptions({required int impostorCount, required bool randomStartPlayer})
    : this._('setImpostorOptions', {'impostorCount': impostorCount, 'randomStartPlayer': randomStartPlayer});
  ClientMessage.configureWerwolf({
    required int? werewolfCount,
    required List<String> roles,
    required bool hostIsGameMaster,
  }) : this._('configureWerwolf', {
         'werewolfCount': werewolfCount,
         'roles': roles,
         'hostIsGameMaster': hostIsGameMaster,
       });
  ClientMessage.configureTabu({
    required int turnSeconds,
    required bool autoTeams,
    required int teamCount,
    required int targetScore,
  }) : this._('configureTabu', {
         'turnSeconds': turnSeconds,
         'autoTeams': autoTeams,
         'teamCount': teamCount,
         'targetScore': targetScore,
       });
  ClientMessage.chooseTeam(int team, {String? targetId}) : this._('chooseTeam', {'team': team, 'targetId': ?targetId});
  ClientMessage.startTurn() : this._('startTurn');
  ClientMessage.wordCorrect() : this._('wordCorrect');
  ClientMessage.wordSkip() : this._('wordSkip');
  ClientMessage.buzz() : this._('buzz');
  ClientMessage.configureNobodyIsPerfect(int questionCount)
    : this._('configureNobodyIsPerfect', {'questionCount': questionCount});
  ClientMessage.submitAnswer(String answer) : this._('submitAnswer', {'answer': answer});
  ClientMessage.guessAnswer(String choice) : this._('guessAnswer', {'choice': choice});
  ClientMessage.skipWaiting() : this._('skipWaiting');
  ClientMessage.nextQuestion() : this._('nextQuestion');
  ClientMessage.configureBuzzer(bool lockout) : this._('configureBuzzer', {'lockout': lockout});
  ClientMessage.pressBuzzer() : this._('pressBuzzer');
  ClientMessage.releaseBuzzer() : this._('releaseBuzzer');
  ClientMessage.configureGeoBingo(int minutes) : this._('configureGeoBingo', {'minutes': minutes});
  ClientMessage.claimGeoBingoField(int field, GeoBingoSpot spot)
    : this._('claimGeoBingoField', {'field': field, 'imageId': spot.imageId, 'x': spot.x, 'y': spot.y, 'zoom': spot.zoom});
  ClientMessage.voteGeoBingo(String claimId, bool accept)
    : this._('voteGeoBingo', {'claimId': claimId, 'accept': accept});
  ClientMessage.nextRound() : this._('nextRound');
  ClientMessage.backToLobby() : this._('backToLobby');
  ClientMessage.ping() : this._('ping');
}
