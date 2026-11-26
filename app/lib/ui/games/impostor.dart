// Online-Ansichten für Impostor: Hinweise, Abstimmung und Ergebnis.
import 'package:material_ui/material_ui.dart';

import '../../logic/app_controller.dart';
import '../../logic/models.dart';
import '../players.dart';
import '../shared.dart';
import '../theme.dart';
import '../widgets.dart';

List<Widget> impostorView(AppController controller, RoomView room, ImpostorView impostor) {
  final label = 'Impostor · Runde ${room.round}';
  final result = impostor.result;
  if (room.phase == Phase.result && result != null) {
    return [GameLabel(label), ..._result(controller, room, result)];
  }

  final voting = room.phase == Phase.voting;
  return [
    PhaseHead(
      label: label,
      title: voting ? 'Abstimmung' : 'Hinweise',
      lead: voting
          ? 'Wer ist der Impostor? Tippe auf einen Namen. Du kannst deine Stimme noch ändern.'
          : 'Reihum sagt jeder ein Wort als Hinweis. Nicht zu deutlich, sonst errät der Impostor das Wort.',
    ),
    if (voting) _Voting(controller: controller, room: room, impostor: impostor),
    _wordCard(impostor),
    if (!voting) ...[
      if (room.players.where((p) => p.id == impostor.startPlayerId).firstOrNull case final start?)
        StartPlayer(name: start.name, you: start.id == room.you.id),
      PlayerList(room: room, only: impostor.participantIds),
    ],
    ActionColumn(
      children: [
        if (room.you.host) ...[
          if (!voting) AppButton.primary('Zur Abstimmung', onPressed: controller.startVoting),
          AppButton.quiet('Spiel beenden', onPressed: controller.backToLobby),
        ] else
          AppButton.quiet('Raum verlassen', onPressed: controller.leave),
      ],
    ),
  ];
}

Widget _wordCard(ImpostorView impostor) {
  if (impostor.part == ImpostorPart.gameMaster) {
    return Panel(
      key: const ValueKey('secret'),
      child: Gap(
        spacing: 0,
        children: [
          const Text('Du leitest diese Runde und spielst nicht mit.'),
          RichLine(['Das Wort: ', Strong(impostor.word ?? '')]),
        ],
      ),
    );
  }
  final isImpostor = impostor.part == ImpostorPart.impostor;
  return SecretCard(
    key: const ValueKey('secret'),
    tone: isImpostor ? CardTone.wolves : CardTone.neutral,
    what: 'um dein Wort zu sehen',
    content: ImpostorCardContent(
      isImpostor: isImpostor,
      word: impostor.word,
      category: impostor.category,
      fellowImpostors: impostor.fellowImpostors,
    ),
  );
}

class StartPlayer extends StatelessWidget {
  const StartPlayer({super.key, required this.name, this.you = false});

  final String name;
  final bool you;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      border: Border.all(color: context.palette.accent, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: RichLine(
      you ? ['Du fängst an.'] : [Strong(name), ' fängt an.'],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18.4),
    ),
  );
}

class _Voting extends StatelessWidget {
  const _Voting({required this.controller, required this.room, required this.impostor});

  final AppController controller;
  final RoomView room;
  final ImpostorView impostor;

  @override
  Widget build(BuildContext context) {
    final voted = impostor.votedIds.toSet();
    final participants = [
      for (final p in room.players)
        if (impostor.participantIds.contains(p.id)) p,
    ];
    final online = participants.where((p) => p.connected).length;
    return Gap(
      spacing: 8,
      children: [
        Hint('${voted.length} von $online haben abgestimmt.'),
        if (impostor.part == ImpostorPart.gameMaster)
          PlayerList(room: room, only: impostor.participantIds, votedIds: voted)
        else
          for (final p in participants.where((p) => p.id != room.you.id))
            VoteOption(
              key: ValueKey(p.id),
              selected: impostor.yourVote == p.id,
              onPressed: () => controller.vote(p.id),
              builder: (_, note) => Row(
                spacing: 16,
                children: [
                  Expanded(child: Text(p.name)),
                  if (voted.contains(p.id)) Text('hat abgestimmt', style: TextStyle(color: note, fontSize: 14.4)),
                ],
              ),
            ),
      ],
    );
  }
}

List<Widget> _result(AppController controller, RoomView room, ImpostorResult result) {
  final several = result.impostorIds.length > 1;
  final youWereImpostor = result.impostorIds.contains(room.you.id);
  final title = result.impostorCaught
      ? 'Erwischt!'
      : several
      ? 'Die Impostor gewinnen!'
      : 'Der Impostor gewinnt!';
  final names = result.impostorNames.join(' und ');
  var lead = several ? '$names waren die Impostor.' : '$names war der Impostor.';
  if (youWereImpostor && !several) {
    lead = result.impostorCaught ? 'Sie haben dich durchschaut.' : 'Du hast alle getäuscht.';
  }

  return [
    PhaseHead(title: title, lead: lead),
    ResultWord(intro: 'Das Wort war', word: result.word, category: result.category),
    PlayerList(
      room: room,
      showReady: true,
      votes: {for (final v in result.votes) v.playerId: v.votes},
      impostorIds: result.impostorIds.toSet(),
    ),
    ActionColumn(
      children: afterRound(
        controller,
        room,
        againLabel: 'Nächste Runde',
        waitingText: 'Alle sind bereit. Die Spielleitung startet die nächste Runde.',
      ),
    ),
  ];
}
