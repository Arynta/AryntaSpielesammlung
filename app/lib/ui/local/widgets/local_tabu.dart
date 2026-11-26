// Lokaler Modus: Tabu.
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../../domain/models/models.dart';
import '../../games/widgets/tabu.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

Widget _scores(TabuMatch match, int current) => Scoreboard(
  teams: [for (var i = 0; i < match.scores.length; i++) (name: Tabu.teamNames[i], score: match.scores[i])],
  currentTeam: current,
  targetScore: match.targetScore,
);

List<Widget> localTabuReady(LocalController local, TabuMatch match) {
  final explainer = local.players[explainerSeat(match)];
  final watcher = local.players[watcherSeat(match)];
  return [
    PhaseHead(
      label: 'Tabu',
      title: '${Tabu.teamNames[match.currentTeam]} ist dran',
      leadParts: [
        Strong(explainer),
        ' erklärt und hält das Handy. ',
        Strong(watcher),
        ' aus ${Tabu.teamNames[watcherTeam(match)]} schaut mit drauf und passt auf.',
      ],
    ),
    ActionColumn(
      children: [AppButton.primary('Uhr starten (${local.setup.turnSeconds} s)', onPressed: local.startTurn)],
    ),
    _scores(match, match.currentTeam),
    if (match.lastTurn.isNotEmpty)
      TurnResults(title: 'Letzter Zug', results: match.lastTurn, teamNames: Tabu.teamNames),
    ActionColumn(children: [AppButton.quiet('Spiel abbrechen', onPressed: local.backToSetup)]),
  ];
}

List<Widget> localTabuTurn(LocalController local, TabuMatch match) => [
  TurnHead(
    label: '${Tabu.teamNames[match.currentTeam]} · ${local.players[explainerSeat(match)]} erklärt',
    deadline: local.deadline,
  ),
  ForbiddenCard(match.card!),
  TurnButtons(onCorrect: () => local.score(CardOutcome.correct), onSkip: () => local.score(CardOutcome.skipped)),
  AppButton(
    'Verboten! (${local.players[watcherSeat(match)]})',
    kind: ButtonStyleKind.danger,
    onPressed: () => local.score(CardOutcome.buzzed),
  ),
  if (match.turnResults.isNotEmpty)
    TurnResults(title: 'Dieser Zug', results: match.turnResults, teamNames: Tabu.teamNames),
  _scores(match, match.currentTeam),
];

List<Widget> localTabuOver(LocalController local, TabuMatch match) {
  final winner = match.winner!;
  final winners = [
    for (var seat = 0; seat < local.players.length; seat++)
      if (match.teams[winner].contains(seat)) local.players[seat],
  ];
  return [
    PhaseHead(
      label: 'Tabu',
      title: '${Tabu.teamNames[winner]} gewinnt!',
      lead: 'Glückwunsch an ${winners.join(', ')}.',
    ),
    _scores(match, winner),
    if (match.lastTurn.isNotEmpty)
      TurnResults(title: 'Letzter Zug', results: match.lastTurn, teamNames: Tabu.teamNames),
    ActionColumn(
      children: [
        AppButton.primary('Nochmal spielen', onPressed: local.startRound),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}
