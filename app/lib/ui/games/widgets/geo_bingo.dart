// Online-Ansichten für Geo-Bingo: Spielzeit in der Lobby, Ergebnis und die Bingo-Karte, die auch die
// laufende Runde (geo_bingo_play.dart) zeigt.
import 'dart:math';

import 'package:material_ui/material_ui.dart';

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
        ['${texts.geoBingoCard}: ', Strong('${s.size} × ${s.size}')],
        if (s.motifs.isNotEmpty) ['${texts.geoBingoOwnMotifs}: ', Strong(s.motifs.join(', '))],
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
        AppStepper(
          label: texts.geoBingoCardSize,
          value: s.size,
          min: s.minSize,
          max: s.maxSize,
          onStep: controller.changeGeoBingoSize,
        ),
        Hint(texts.geoBingoRules),
        _OwnMotifs(controller: controller, settings: s),
        Hint(texts.geoBingoSource),
      ],
    );
  }
}

/// Eigene Begriffe: eintippen, hinzufügen, mit X wieder entfernen.
class _OwnMotifs extends StatefulWidget {
  const _OwnMotifs({required this.controller, required this.settings});

  final AppController controller;
  final GeoBingoSettings settings;

  @override
  State<_OwnMotifs> createState() => _OwnMotifsState();
}

class _OwnMotifsState extends State<_OwnMotifs> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Der Fokus bleibt im Feld, damit man mehrere Begriffe hintereinander eintippen kann.
  void _add() {
    widget.controller.addGeoBingoMotif();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final settings = widget.settings;
    final full = settings.motifs.length >= settings.maxMotifs;
    return Gap(
      children: [
        AppField(
          label: texts.geoBingoOwnMotifs,
          controller: controller.geoBingoMotifInput,
          focusNode: _focus,
          hint: texts.geoBingoOwnMotifHint,
          maxLength: settings.maxMotifLength,
          onSubmitted: full ? null : _add,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(texts.geoBingoAddMotif, small: true, onPressed: full ? null : _add),
        ),
        for (final motif in settings.motifs)
          Row(
            spacing: 10,
            children: [
              Expanded(child: Text(motif)),
              IconSquare(
                icon: Icons.close,
                semanticLabel: texts.geoBingoRemoveMotif(motif),
                onPressed: () => controller.removeGeoBingoMotif(motif),
              ),
            ],
          ),
        Hint(texts.geoBingoOwnMotifsInfo),
      ],
    );
  }
}

/// Ergebnis nach der Runde. Die laufende Runde ist GeoBingoPlay und füllt den ganzen Bildschirm.
List<Widget> geoBingoView(AppController controller, RoomView room, GeoBingoView game) {
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
    GeoBingoBoard(game: game, playerId: shown, highlight: game.winningLine ?? const []),
    GeoBingoScores(room: room, game: game),
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
List<Widget> geoBingoNews(RoomView room, GeoBingoView game) => [
  for (final d in game.decisions.take(3))
    Hint.rich([
      Strong(room.nameOf(d.playerId)),
      ': ${game.board[d.field]} ',
      Strong(d.accepted ? texts.confirmed : texts.rejected),
    ]),
  GeoBingoScores(room: room, game: game),
];

class GeoBingoScores extends StatelessWidget {
  const GeoBingoScores({super.key, required this.room, required this.game});

  final RoomView room;
  final GeoBingoView game;

  @override
  Widget build(BuildContext context) => Text(
    [for (final s in game.scores) '${room.nameOf(s.playerId)}: ${s.fields.length}'].join(' · '),
    style: TextStyle(color: context.palette.muted),
  );
}

/// Die Karte von [playerId] (3×3 bis 6×6). Mit [onClaim] kann man offene Felder melden.
class GeoBingoBoard extends StatelessWidget {
  const GeoBingoBoard({
    super.key,
    required this.game,
    required this.playerId,
    this.onClaim,
    this.highlight = const [],
  });

  final GeoBingoView game;
  final String playerId;
  final ValueChanged<int>? onClaim;
  final List<int> highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final found = game.fieldsOf(playerId);
    final pending = game.claims.where((c) => c.playerId == playerId).firstOrNull?.field;
    final size = sqrt(game.board.length).round();
    // Größere Karten bekommen flachere Felder, damit sie in die Leiste passen
    final tileHeight = 64.0 - (size - 3) * 8;
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
              height: tileHeight,
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
        for (var row = 0; row < size; row++)
          Row(spacing: 8, children: [for (var col = 0; col < size; col++) tile(row * size + col)]),
      ],
    );
  }
}
