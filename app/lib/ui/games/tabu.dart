// Online-Ansichten für Tabu: Teamwahl in der Lobby und das laufende Spiel.
import 'package:material_ui/material_ui.dart';

import '../../logic/app_controller.dart';
import '../../logic/game_data.dart';
import '../../logic/models.dart';
import '../players.dart';
import '../shared.dart';
import '../widgets.dart';

/// Teamwahl in der Lobby, wenn die Teams nicht automatisch gemischt werden.
class TeamChoice extends StatelessWidget {
  const TeamChoice({super.key, required this.controller, required this.room});

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final settings = room.tabuSettings;
    final assigned = {for (final team in settings.teams) ...team};
    final unassigned = [
      for (final p in room.players)
        if (!assigned.contains(p.id)) p.name,
    ];
    return Gap(
      spacing: 8,
      children: [
        const SectionTitle('Teams'),
        AutoGrid(
          minWidth: 144,
          spacing: 12,
          fit: true,
          children: [
            for (var team = 0; team < settings.teams.length; team++)
              TeamStripe(
                key: ValueKey(team),
                team: team,
                radius: 12,
                padding: const EdgeInsets.all(12),
                child: Gap(
                  spacing: 8,
                  children: [
                    SectionTitle(Tabu.teamNames[team], count: '${settings.teams[team].length}'),
                    Gap(
                      spacing: 0,
                      children: [
                        for (final id in settings.teams[team])
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Row(
                              spacing: 6,
                              children: [
                                Expanded(child: Text('${room.nameOf(id)}${id == room.you.id ? ' (du)' : ''}')),
                                if (room.you.host)
                                  IconSquare(
                                    icon: Icons.swap_horiz,
                                    semanticLabel: '${room.nameOf(id)} ins nächste Team',
                                    onPressed: () => controller.moveToNextTeam(id),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (!settings.teams[team].contains(room.you.id))
                      AppButton('Hier rein', small: true, onPressed: () => controller.chooseTeam(team)),
                  ],
                ),
              ),
          ],
        ),
        if (unassigned.isNotEmpty) Hint('Noch ohne Team: ${unassigned.join(', ')}'),
      ],
    );
  }
}

/// Spielleiste mit Beschriftung und Restzeit.
class TurnHead extends StatelessWidget {
  const TurnHead({super.key, required this.label, required this.deadline});

  final String label;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 16,
    children: [
      Expanded(child: GameLabel(label)),
      if (deadline != null) Countdown(deadline!),
    ],
  );
}

class TurnText extends StatelessWidget {
  const TurnText(this.parts, {super.key});

  final List<Object> parts;

  @override
  Widget build(BuildContext context) => Panel(
    border: false,
    padding: const EdgeInsets.all(20),
    child: RichLine(parts, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19)),
  );
}

/// „Richtig“ und „Überspringen“ nebeneinander.
class TurnButtons extends StatelessWidget {
  const TurnButtons({super.key, required this.onCorrect, required this.onSkip});

  final VoidCallback onCorrect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Expanded(
        child: AppButton.primary('Richtig', icon: Icons.check, onPressed: onCorrect),
      ),
      Expanded(child: AppButton('Überspringen', onPressed: onSkip)),
    ],
  );
}

List<Widget> tabuView(AppController controller, RoomView room, TabuView game) {
  final label = 'Tabu · Zug ${room.round}';
  final teamNames = [for (final t in game.teams) t.name];
  final scoreboard = Scoreboard(
    teams: [for (final t in game.teams) (name: t.name, score: t.score)],
    currentTeam: game.currentTeam,
    targetScore: game.targetScore,
  );
  final leave = endOrLeave(controller, room);
  final lastTurn = TurnResults(title: 'Letzter Zug', results: game.lastTurn, teamNames: teamNames);

  final winner = game.winnerTeam;
  if (winner != null) {
    return [
      GameLabel(label),
      PhaseHead(
        title: '${teamNames[winner]} gewinnt!',
        lead: game.yourTeam == winner ? 'Glückwunsch, ihr habt es geschafft.' : 'Knapp daneben ist auch vorbei.',
      ),
      scoreboard,
      if (game.lastTurn.isNotEmpty) lastTurn,
      ActionColumn(
        children: afterRound(
          controller,
          room,
          againLabel: 'Nochmal spielen',
          waitingText: 'Alle sind bereit. Die Spielleitung kann neu starten.',
        ),
      ),
    ];
  }

  final explainer = room.nameOf(game.explainerId);
  final watcher = room.nameOf(game.watcherId);
  final youExplain = game.explainerId == room.you.id;
  final youWatch = game.watcherId == room.you.id;

  if (room.phase == Phase.turnReady) {
    final explainerOnline = room.players.any((p) => p.id == game.explainerId && p.connected);
    return [
      GameLabel(label),
      PhaseHead(
        title: '${teamNames[game.currentTeam]} ist dran',
        leadParts: youExplain
            ? ['Du erklärst! Starte die Uhr, wenn dein Team bereit ist.']
            : youWatch
            ? ['Du passt auf $explainer auf und hast den Buzzer.']
            : [Strong(explainer), ' erklärt, ', Strong(watcher), ' passt auf.'],
      ),
      if (youExplain)
        ActionColumn(children: [AppButton.primary('Uhr starten', onPressed: controller.startTurn)])
      else if (room.you.host && !explainerOnline)
        ActionColumn(children: [AppButton('Für $explainer starten', onPressed: controller.startTurn)]),
      scoreboard,
      if (game.lastTurn.isNotEmpty) lastTurn,
      ActionColumn(children: [leave]),
    ];
  }

  // Zug läuft
  final card = game.card;
  return [
    TurnHead(label: label, deadline: controller.turnDeadline),
    if (youExplain && card != null) ...[
      ForbiddenCard(card),
      TurnButtons(onCorrect: controller.wordCorrect, onSkip: controller.wordSkip),
    ] else if (youWatch && card != null) ...[
      ForbiddenCard(card),
      AppButton('Verboten!', kind: ButtonStyleKind.danger, onPressed: controller.buzz),
      Hint('Drück, wenn $explainer ein verbotenes Wort, einen Teil davon oder eine Geste benutzt.'),
    ] else if (game.yourTeam == game.currentTeam)
      TurnText(['Rate mit! ', Strong(explainer), ' erklärt.'])
    else
      TurnText(['${teamNames[game.currentTeam]} rät gerade. ', Strong(watcher), ' passt auf.']),
    if (game.turnResults.isNotEmpty) TurnResults(title: 'Dieser Zug', results: game.turnResults, teamNames: teamNames),
    scoreboard,
    ActionColumn(children: [leave]),
  ];
}
