// Der Raum aus Sicht eines Spielers, wie RoomView im Backend.
import 'json.dart';
import 'game.dart';
import 'impostor.dart';
import 'tabu.dart';
import 'werwolf.dart';
import 'nobody_is_perfect.dart';
import 'buzzer.dart';
import 'geo_bingo.dart';

class PlayerView {
  PlayerView.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      alive = j['alive'] as bool,
      connected = j['connected'] as bool,
      ready = j['ready'] as bool;
  final String id;
  final String name;
  final bool alive;
  final bool connected;
  final bool ready;
}

class You {
  You.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      host = j['host'] as bool,
      ready = j['ready'] as bool;
  final String id;
  final String name;
  final bool host;
  final bool ready;
}

class GameOption {
  GameOption.fromJson(Json j)
    : type = GameType.parse(j['type']),
      name = j['name'] as String,
      description = j['description'] as String,
      minPlayers = j['minPlayers'] as int;
  final GameType type;
  final String name;
  final String description;
  final int minPlayers;
}

class PlayerLimit {
  PlayerLimit.fromJson(Json j) : value = j['value'] as int, min = j['min'] as int, max = j['max'] as int;
  final int value;

  /// Kleinster Wert, den der Host gerade einstellen darf.
  final int min;
  final int max;
}

class RoomView {
  RoomView.fromJson(Json j)
    : code = j['code'] as String,
      game = GameType.parse(j['game']),
      games = parseList(j['games'], GameOption.fromJson),
      impostorSettings = ImpostorSettings.fromJson(j['impostorSettings'] as Json),
      werwolfSettings = WerwolfSettings.fromJson(j['werwolfSettings'] as Json),
      tabuSettings = TabuSettings.fromJson(j['tabuSettings'] as Json),
      nobodyIsPerfectSettings = NobodyIsPerfectSettings.fromJson(j['nobodyIsPerfectSettings'] as Json),
      buzzerSettings = BuzzerSettings.fromJson(j['buzzerSettings'] as Json),
      geoBingoSettings = GeoBingoSettings.fromJson(j['geoBingoSettings'] as Json),
      playerLimit = PlayerLimit.fromJson(j['playerLimit'] as Json),
      phase = Phase.parse(j['phase']),
      round = j['round'] as int,
      hostId = j['hostId'] as String,
      players = parseList(j['players'], PlayerView.fromJson),
      canStart = j['canStart'] as bool,
      startHint = j['startHint'] as String?,
      you = You.fromJson(j['you'] as Json),
      werwolf = parseOptional(j['werwolf'], WerwolfView.fromJson),
      impostor = parseOptional(j['impostor'], ImpostorView.fromJson),
      tabu = parseOptional(j['tabu'], TabuView.fromJson),
      nobodyIsPerfect = parseOptional(j['nobodyIsPerfect'], NobodyIsPerfectView.fromJson),
      buzzer = parseOptional(j['buzzer'], BuzzerView.fromJson),
      geoBingo = parseOptional(j['geoBingo'], GeoBingoView.fromJson);
  final String code;
  final GameType game;
  final List<GameOption> games;
  final ImpostorSettings impostorSettings;
  final WerwolfSettings werwolfSettings;
  final TabuSettings tabuSettings;
  final NobodyIsPerfectSettings nobodyIsPerfectSettings;
  final BuzzerSettings buzzerSettings;
  final GeoBingoSettings geoBingoSettings;
  final PlayerLimit playerLimit;
  final Phase phase;
  final int round;
  final String hostId;
  final List<PlayerView> players;
  final bool canStart;
  final String? startHint;
  final You you;
  final WerwolfView? werwolf;
  final ImpostorView? impostor;
  final TabuView? tabu;
  final NobodyIsPerfectView? nobodyIsPerfect;
  final BuzzerView? buzzer;
  final GeoBingoView? geoBingo;

  /// Name zu einer Spieler-ID, "?" wenn es den Spieler nicht mehr gibt.
  String nameOf(String id) {
    for (final p in players) {
      if (p.id == id) return p.name;
    }
    return '?';
  }
}
