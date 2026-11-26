// Lokaler Modus: Nobody is Perfect.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../../../l10n/l10n.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

String _fibLabel(NobodyIsPerfectMatch match) => texts.nipQuestionLabel(match.index + 1, match.questions.length);

Widget _fibQuestion(NobodyIsPerfectMatch match) => QuestionCard(
  question: match.questions[match.index].question,
  number: match.index + 1,
  count: match.questions.length,
);

List<Widget> localFibPass(LocalController local, NobodyIsPerfectMatch match) {
  final name = local.players[local.index];
  final guessing = match.choices.isNotEmpty;
  return [
    PhaseHead(
      label: _fibLabel(match),
      title: texts.passPhoneTo(name),
      lead: '${guessing ? texts.nowGuessing : texts.nowFibbing} ${texts.onlyNameMayLook(name)}',
    ),
    ActionColumn(
      children: [
        AppButton.primary(
          guessing ? texts.iAmNameShowAnswers(name) : texts.iAmNameShowQuestion(name),
          onPressed: local.showFibTurn,
        ),
        AppButton.quiet(texts.cancelGame, onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localFibWrite(LocalController local, NobodyIsPerfectMatch match) => [
  PhaseHead(
    label: _fibLabel(match),
    title: texts.startFibbingName(local.players[local.index]),
    lead: texts.makeUpRealSounding,
  ),
  _fibQuestion(match),
  SettingsGroup(
    key: const ValueKey('local-answer'),
    children: [
      AppField(
        label: texts.yourFakeAnswer,
        controller: local.answerInput,
        hint: texts.yourFakeAnswerHint,
        maxLength: NobodyIsPerfectRules.maxAnswerLength,
        onSubmitted: local.submitAnswer,
      ),
    ],
  ),
  ActionColumn(children: [AppButton.primary(texts.submitAndPass, onPressed: local.submitAnswer)]),
];

List<Widget> localFibGuess(LocalController local, NobodyIsPerfectMatch match) {
  final own = match.choices.where((c) => c.author == local.index).firstOrNull?.id;
  final chosen = match.guesses[local.index];
  return [
    PhaseHead(
      label: _fibLabel(match),
      title: texts.whichIsRealName(local.players[local.index]),
      lead: texts.tapTheRealAnswer,
    ),
    _fibQuestion(match),
    ChoiceList(
      choices: [for (final c in match.choices) (id: c.id, text: c.text)],
      ownId: own,
      chosenId: chosen,
      onChoose: local.guess,
    ),
    ActionColumn(
      children: [
        AppButton.primary(texts.guessAndPass, onPressed: chosen == null ? null : local.finishGuess),
      ],
    ),
  ];
}

List<Widget> localFibReveal(LocalController local, NobodyIsPerfectMatch match) {
  final over = local.stage == Stage.fibOver;
  final reveal = RevealList([
    for (final c in match.choices)
      RevealRow(
        id: c.id,
        text: c.text,
        correct: c.author == null,
        author: c.author == null ? null : local.players[c.author!],
        guessers: [
          for (var seat = 0; seat < local.players.length; seat++)
            if (match.guesses[seat] == c.id) local.players[seat],
        ],
      ),
  ]);
  final points = PointTable([
    for (var seat = 0; seat < local.players.length; seat++)
      (name: local.players[seat], score: match.scores[seat], gained: match.gained[seat]),
  ], title: over ? texts.finalScore : texts.points);
  final answer = ResultWord(intro: texts.theRealAnswer, word: match.questions[match.index].answer, size: 26);

  if (!over) {
    return [
      PhaseHead(label: _fibLabel(match), title: texts.reveal),
      _fibQuestion(match),
      answer,
      reveal,
      points,
      ActionColumn(
        children: [
          AppButton.primary(texts.nextQuestion, onPressed: local.nextQuestion),
          AppButton.quiet(texts.cancelGame, onPressed: local.backToSetup),
        ],
      ),
    ];
  }

  final best = match.scores.reduce(math.max);
  final winners = [
    for (var seat = 0; seat < local.players.length; seat++)
      if (match.scores[seat] == best) local.players[seat],
  ];
  return [
    PhaseHead(
      label: texts.nipGameOver,
      title: winners.length == 1 ? texts.wins(winners.first) : texts.tie(winners.join(texts.and)),
      lead: texts.withPoints(best),
    ),
    points,
    _fibQuestion(match),
    answer,
    reveal,
    ActionColumn(
      children: [
        AppButton.primary(texts.playAgain, onPressed: local.startRound),
        AppButton.quiet(texts.changeSettings, onPressed: local.backToSetup),
      ],
    ),
  ];
}
