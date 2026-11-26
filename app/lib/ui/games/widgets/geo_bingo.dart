// Online-Ansichten für Geo-Bingo: Spielzeit in der Lobby, Straßenbild mit Bingo-Karte, Abstimmung und Ergebnis.
import 'package:material_ui/material_ui.dart';

import '../../../data/services/street_view/street_view.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/view_model/app_controller.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

class GeoBingoSettingsView extends StatelessWidget {
  const GeoBingoSettingsView({super.key, required this.controller, required this.room});

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final s = room.geoBingoSettings;
    if (!room.you.host) {
      return SettingsSummary([
        ['${texts.playTime}: ', Strong(texts.minutes(s.minutes))],
        [texts.geoBingoSource],
      ]);
    }
    return SettingsGroup(
      children: [
        AppStepper(
          label: texts.playTimeMinutes,
          value: s.minutes,
          min: s.minMinutes,
          max: s.maxMinutes,
          onStep: controller.changeGeoBingoMinutes,
        ),
        Hint(texts.geoBingoRules),
        Hint(texts.geoBingoSource),
      ],
    );
  }
}

List<Widget> geoBingoView(AppController controller, RoomView room, GeoBingoView game) =>
    room.phase == Phase.geoBingo ? _running(controller, room, game) : _result(controller, room, game);

List<Widget> _running(AppController controller, RoomView room, GeoBingoView game) {
  final me = room.you.id;
  final toVote = game.claims.where((c) => c.playerId != me && c.yourVote == null).firstOrNull;
  final deadline = controller.geoBingoDeadline;
  return [
    Row(
      children: [
        Expanded(child: GameLabel(texts.geoBingoPlace(game.place))),
        if (deadline != null) Countdown(deadline, clock: true),
      ],
    ),
    if (toVote != null) _Vote(key: ValueKey(toVote.id), controller: controller, room: room, game: game, claim: toVote),
    _Frame(
      key: ValueKey('street-${room.round}'),
      child: StreetView(start: (lat: game.lat, lng: game.lng), controller: controller.streetView),
    ),
    Hint(texts.geoBingoLookAround),
    _Board(game: game, playerId: me, onClaim: controller.claimGeoBingoField),
    ..._news(room, game),
    ActionColumn(children: [endOrLeave(controller, room)]),
  ];
}

List<Widget> _result(AppController controller, RoomView room, GeoBingoView game) {
  final winners = game.winnerIds;
  final title = switch (winners.length) {
    0 => texts.geoBingoNothingFound,
    1 => texts.wins(room.nameOf(winners.first)),
    _ => texts.tie(winners.map(room.nameOf).join(texts.and)),
  };
  final lead = game.winningLine != null
      ? texts.geoBingoFullRow
      : '${texts.timeIsUp}${winners.isEmpty ? '' : ' ${texts.withFields(game.fieldsOf(winners.first).length)}'}';
  final shown = winners.isEmpty ? room.you.id : winners.first;
  return [
    PhaseHead(label: texts.geoBingoPlace(game.place), title: title, lead: lead),
    _Board(game: game, playerId: shown, highlight: game.winningLine ?? const []),
    _Scores(room: room, game: game),
    ActionColumn(
      children: afterRound(
        controller,
        room,
        againLabel: texts.newCity,
        waitingText: texts.allReadyHostNewCity,
      ),
    ),
  ];
}

/// Was zuletzt entschieden wurde und wie viele Felder die anderen haben.
List<Widget> _news(RoomView room, GeoBingoView game) => [
  for (final d in game.decisions.take(3))
    Hint.rich([
      Strong(room.nameOf(d.playerId)),
      ': ${game.board[d.field]} ',
      Strong(d.accepted ? texts.confirmed : texts.rejected),
    ]),
  _Scores(room: room, game: game),
];

class _Scores extends StatelessWidget {
  const _Scores({required this.room, required this.game});

  final RoomView room;
  final GeoBingoView game;

  @override
  Widget build(BuildContext context) => Text(
    [for (final s in game.scores) '${room.nameOf(s.playerId)}: ${s.fields.length}'].join(' · '),
    style: TextStyle(color: context.palette.muted),
  );
}

/// Rahmen für ein Straßenbild im Format 4:3.
class _Frame extends StatelessWidget {
  const _Frame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: 4 / 3,
      child: ColoredBox(color: context.palette.surface, child: child),
    ),
  );
}

class _Vote extends StatelessWidget {
  const _Vote({super.key, required this.controller, required this.room, required this.game, required this.claim});

  final AppController controller;
  final RoomView room;
  final GeoBingoView game;
  final GeoBingoClaim claim;

  @override
  Widget build(BuildContext context) {
    final deadline = controller.voteDeadlines[claim.id];
    return Panel(
      borderColor: context.palette.accent,
      child: Gap(
        children: [
          Row(
            children: [
              Expanded(
                child: RichLine([
                  Strong(room.nameOf(claim.playerId)),
                  texts.claimHas,
                  Strong(game.board[claim.field]),
                  texts.claimFound,
                ]),
              ),
              if (deadline != null) Countdown(deadline),
            ],
          ),
          _Frame(child: StreetView(spot: claim.spot)),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: AppButton.primary(texts.yesCorrect, onPressed: () => controller.voteGeoBingo(claim.id, true)),
              ),
              Expanded(
                child: AppButton(texts.no, onPressed: () => controller.voteGeoBingo(claim.id, false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Die 3×3-Karte von [playerId]. Mit [onClaim] kann man offene Felder melden.
class _Board extends StatelessWidget {
  const _Board({required this.game, required this.playerId, this.onClaim, this.highlight = const []});

  final GeoBingoView game;
  final String playerId;
  final ValueChanged<int>? onClaim;
  final List<int> highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final found = game.fieldsOf(playerId);
    final pending = game.claims.where((c) => c.playerId == playerId).firstOrNull?.field;
    Widget tile(int field) {
      final done = found.contains(field);
      final waiting = field == pending;
      final claim = onClaim;
      final motif = game.board[field];
      return Expanded(
        child: Opacity(
          opacity: claim != null && pending != null && !waiting ? 0.45 : 1,
          child: Pressable(
            semanticLabel: '$motif${done ? ', ${texts.found}' : waiting ? ', ${texts.beingChecked}' : ''}',
            selected: done,
            onPressed: claim == null || done || pending != null ? null : () => claim(field),
            child: Container(
              height: 64,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: done ? p.accent : p.surface,
                border: Border.all(color: waiting || highlight.contains(field) ? p.accent : p.line, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              // Lange Wörter wie „Fensterläden“ werden kleiner statt mitten im Wort umzubrechen
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  waiting ? '$motif\n…' : motif.replaceAll(' ', '\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: done ? p.onAccent : p.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Gap(
      spacing: 8,
      children: [
        for (var row = 0; row < 3; row++)
          Row(spacing: 8, children: [for (var col = 0; col < 3; col++) tile(row * 3 + col)]),
      ],
    );
  }
}
