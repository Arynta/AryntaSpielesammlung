// Mitspielerliste und Bereit-Knopf: in der Lobby und in den Online-Spielen gleich.
import 'package:material_ui/material_ui.dart';

import '../view_model/app_controller.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../themes/theme.dart';
import 'widgets.dart';

class PlayerList extends StatelessWidget {
  const PlayerList({
    super.key,
    required this.room,
    this.showReady = false,
    this.showLimit = false,
    this.onKick,
    this.only,
    this.votedIds,
    this.votes,
    this.impostorIds,
  });

  final RoomView room;
  final bool showReady;

  /// Zeigt „3 / 20“ statt nur „3“.
  final bool showLimit;

  /// Gesetzt beim Host: neben jedem anderen Spieler ein Knopf zum Entfernen.
  final ValueChanged<String>? onKick;
  final List<String>? only;
  final Set<String>? votedIds;

  /// Stimmen nach der Abstimmung. Ist das gesetzt, wird nach Stimmen sortiert.
  final Map<String, int>? votes;
  final Set<String>? impostorIds;

  @override
  Widget build(BuildContext context) {
    var players = [
      for (final p in room.players)
        if (only?.contains(p.id) ?? true) p,
    ];
    final votes = this.votes;
    if (votes != null) {
      // Bei Gleichstand bleibt die Beitrittsreihenfolge
      final order = {for (var i = 0; i < players.length; i++) players[i].id: i};
      players.sort((a, b) {
        final difference = (votes[b.id] ?? -1) - (votes[a.id] ?? -1);
        return difference != 0 ? difference : order[a.id]! - order[b.id]!;
      });
    }
    final count = showLimit ? '${players.length} / ${room.playerLimit.value}' : '${players.length}';

    return Gap(
      spacing: 0,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SectionTitle(texts.players, count: count),
        ),
        for (final p in players) _line(context, p),
      ],
    );
  }

  Widget _line(BuildContext context, PlayerView p) {
    final palette = context.palette;
    final voteCount = votes?[p.id];
    final ready = showReady && p.ready;
    final notes = [
      if (voteCount != null) texts.votes(voteCount),
      if (p.id == room.you.id) texts.noteYou,
      if (p.id == room.hostId) texts.gameMaster,
      if (ready) texts.noteReady,
      if (votedIds?.contains(p.id) ?? false) texts.noteVoted,
      if (!p.connected) texts.noteOffline,
    ];
    final impostor = impostorIds?.contains(p.id) ?? false;
    final color = impostor ? palette.accent : palette.text;
    return NameLine(
      key: ValueKey(p.id),
      name: p.name,
      nameStyle: TextStyle(
        color: p.connected ? color : color.withValues(alpha: 0.55),
        fontWeight: impostor ? FontWeight.w700 : null,
        decoration: p.alive ? null : TextDecoration.lineThrough,
        decorationColor: color,
      ),
      note: notes.isEmpty ? null : Text(notes.join(' · ')),
      noteColor: ready ? palette.accent : null,
      trailing: onKick != null && p.id != room.you.id
          ? IconSquare(icon: Icons.close, semanticLabel: texts.kickPlayer(p.name), onPressed: () => onKick!(p.id))
          : null,
    );
  }
}

class ReadyButton extends StatelessWidget {
  const ReadyButton(this.controller, this.room, {super.key});

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) => AppButton(
    room.you.ready ? texts.ready : texts.imReady,
    icon: room.you.ready ? Icons.check : null,
    highlighted: room.you.ready,
    selected: room.you.ready,
    onPressed: controller.toggleReady,
  );
}

/// Der übliche Knopf unter einem laufenden Spiel: die Spielleitung beendet, alle anderen gehen.
Widget endOrLeave(AppController controller, RoomView room) => room.you.host
    ? AppButton.quiet(texts.endGame, onPressed: controller.backToLobby)
    : AppButton.quiet(texts.leaveRoom, onPressed: controller.leave);

/// Knöpfe am Ende einer Runde: bereit melden, neu starten oder zurück zur Lobby.
List<Widget> afterRound(
  AppController controller,
  RoomView room, {
  required String againLabel,
  required String waitingText,
}) {
  final hint = room.canStart && !room.you.host ? waitingText : room.startHint;
  return [
    ReadyButton(controller, room),
    if (room.you.host) ...[
      AppButton.primary(againLabel, onPressed: room.canStart ? controller.nextRound : null),
      AppButton.quiet(texts.backToLobby, onPressed: controller.backToLobby),
    ] else
      AppButton.quiet(texts.leaveRoom, onPressed: controller.leave),
    if (hint != null) Hint(hint),
  ];
}
