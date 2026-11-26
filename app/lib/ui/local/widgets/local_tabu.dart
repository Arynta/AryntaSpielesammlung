// Lokaler Modus: Tabu.
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../../domain/models/models.dart';
import '../../games/widgets/tabu.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

Widget _scores(TabuMatch match, int current) => Scoreboard(
  teams: [for (var i = 0; i < match.scores.length; i++) (name: tabuTeamNames[i], score: match.scores[i])],
  currentTeam: current,
  targetScore: match.targetScore,
);

List<Widget> localTabuReady(LocalController local, TabuMatch match) {
  final explainer = local.players[explainerSeat(match)];
  final watcher = local.players[watcherSeat(match)];
  return [
    PhaseHead(
      label: texts.tabu,
      title: texts.isUp(tabuTeamNames[match.currentTeam]),
      leadParts: [
        Strong(explainer),
        texts.localExplainsAndHolds,
        Strong(watcher),
        texts.localWatcherFrom(tabuTeamNames[watcherTeam(match)]),
      ],
    ),
    ActionColumn(
      children: [AppButton.primary(texts.startClockSeconds(local.setup.turnSeconds), onPressed: local.startTurn)],
    ),
    _scores(match, match.currentTeam),
    if (match.lastTurn.isNotEmpty)
      TurnResults(title: texts.lastTurn, results: match.lastTurn, teamNames: tabuTeamNames),
    ActionColumn(children: [AppButton.quiet(texts.cancelGame, onPressed: local.backToSetup)]),
  ];
}

List<Widget> localTabuTurn(LocalController local, TabuMatch match) => [
  TurnHead(
    label: texts.teamExplainer(tabuTeamNames[match.currentTeam], local.players[explainerSeat(match)]),
    deadline: local.deadline,
  ),
  ForbiddenCard(match.card!),
  TurnButtons(onCorrect: () => local.score(CardOutcome.correct), onSkip: () => local.score(CardOutcome.skipped)),
  AppButton(
    texts.forbiddenBy(local.players[watcherSeat(match)]),
    kind: ButtonStyleKind.danger,
    onPressed: () => local.score(CardOutcome.buzzed),
  ),
  if (match.turnResults.isNotEmpty)
    TurnResults(title: texts.thisTurn, results: match.turnResults, teamNames: tabuTeamNames),
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
      label: texts.tabu,
      title: texts.wins(tabuTeamNames[winner]),
      lead: texts.congratulations(winners.join(', ')),
    ),
    _scores(match, winner),
    if (match.lastTurn.isNotEmpty)
      TurnResults(title: texts.lastTurn, results: match.lastTurn, teamNames: tabuTeamNames),
    ActionColumn(
      children: [
        AppButton.primary(texts.playAgain, onPressed: local.startRound),
        AppButton.quiet(texts.changeSettings, onPressed: local.backToSetup),
      ],
    ),
  ];
}
