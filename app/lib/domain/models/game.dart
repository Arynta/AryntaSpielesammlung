// Spiele und Phasen, wie GameType und Phase im Backend.

/// Namen wie auf der Leitung: `GameType.nobodyIsPerfect` ↔ `NOBODY_IS_PERFECT`.
enum GameType {
  werwolf('WERWOLF'),
  impostor('IMPOSTOR'),
  tabu('TABU'),
  nobodyIsPerfect('NOBODY_IS_PERFECT'),
  buzzer('BUZZER');

  const GameType(this.wire);
  final String wire;
  static GameType parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}

enum Phase {
  lobby('LOBBY'),
  night('NIGHT'),
  day('DAY'),
  word('WORD'),
  voting('VOTING'),
  result('RESULT'),
  turnReady('TURN_READY'),
  turn('TURN'),
  writing('WRITING'),
  guessing('GUESSING'),
  reveal('REVEAL'),
  buzzer('BUZZER');

  const Phase(this.wire);
  final String wire;
  static Phase parse(Object? raw) => values.firstWhere((v) => v.wire == raw);
}
