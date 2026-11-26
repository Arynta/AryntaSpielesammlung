// Online-Ansichten für Tabu: Teamwahl in der Lobby und das laufende Spiel.
import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

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
        SectionTitle(texts.teams),
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
                    SectionTitle(tabuTeamNames[team], count: '${settings.teams[team].length}'),
                    Gap(
                      spacing: 0,
                      children: [
                        for (final id in settings.teams[team])
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 40),
                            child: Row(
                              spacing: 6,
                              children: [
                                Expanded(child: Text('${room.nameOf(id)}${id == room.you.id ? ' (${texts.noteYou})' : ''}')),
                                if (room.you.host)
                                  IconSquare(
                                    icon: Icons.swap_horiz,
                                    semanticLabel: texts.moveToNextTeam(room.nameOf(id)),
                                    onPressed: () => controller.moveToNextTeam(id),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (!settings.teams[team].contains(room.you.id))
                      AppButton(texts.joinThisTeam, small: true, onPressed: () => controller.chooseTeam(team)),
                  ],
                ),
              ),
          ],
        ),
        if (unassigned.isNotEmpty) Hint(texts.withoutTeam(unassigned.join(', '))),
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
        child: AppButton.primary(texts.correct, icon: Icons.check, onPressed: onCorrect),
      ),
      Expanded(child: AppButton(texts.skip, onPressed: onSkip)),
    ],
  );
}

List<Widget> tabuView(AppController controller, RoomView room, TabuView game) {
  final label = texts.tabuTurnLabel(room.round);
  final teamNames = [for (final t in game.teams) t.name];
  final scoreboard = Scoreboard(
    teams: [for (final t in game.teams) (name: t.name, score: t.score)],
    currentTeam: game.currentTeam,
    targetScore: game.targetScore,
  );
  final leave = endOrLeave(controller, room);
  final lastTurn = TurnResults(title: texts.lastTurn, results: game.lastTurn, teamNames: teamNames);

  final winner = game.winnerTeam;
  if (winner != null) {
    return [
      GameLabel(label),
      PhaseHead(
        title: texts.wins(teamNames[winner]),
        lead: game.yourTeam == winner ? texts.tabuYouWon : texts.tabuYouLost,
      ),
      scoreboard,
      if (game.lastTurn.isNotEmpty) lastTurn,
      ActionColumn(
        children: afterRound(
          controller,
          room,
          againLabel: texts.playAgain,
          waitingText: texts.allReadyHostCanRestart,
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
        title: texts.isUp(teamNames[game.currentTeam]),
        leadParts: youExplain
            ? [texts.youExplain]
            : youWatch
            ? [texts.youWatch(explainer)]
            : [Strong(explainer), texts.explainsComma, Strong(watcher), texts.watchesSuffix],
      ),
      if (youExplain)
        ActionColumn(children: [AppButton.primary(texts.startClock, onPressed: controller.startTurn)])
      else if (room.you.host && !explainerOnline)
        ActionColumn(children: [AppButton(texts.startFor(explainer), onPressed: controller.startTurn)]),
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
      AppButton(texts.forbidden, kind: ButtonStyleKind.danger, onPressed: controller.buzz),
      Hint(texts.buzzWhen(explainer)),
    ] else if (game.yourTeam == game.currentTeam)
      TurnText([texts.guessAlong, Strong(explainer), texts.explainsSuffix])
    else
      TurnText([texts.teamIsGuessing(teamNames[game.currentTeam]), Strong(watcher), texts.watchesSuffix]),
    if (game.turnResults.isNotEmpty) TurnResults(title: texts.thisTurn, results: game.turnResults, teamNames: teamNames),
    scoreboard,
    ActionColumn(children: [leave]),
  ];
}
