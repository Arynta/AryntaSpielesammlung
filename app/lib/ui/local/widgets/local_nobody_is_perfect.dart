// Lokaler Modus: Nobody is Perfect.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

String _fibLabel(NobodyIsPerfectMatch match) =>
    'Nobody is Perfect · Frage ${match.index + 1} von ${match.questions.length}';

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
      title: 'Gib das Handy an $name',
      lead:
          '${guessing ? 'Jetzt wird getippt.' : 'Jetzt wird geflunkert.'} '
          'Nur $name darf auf den Bildschirm schauen.',
    ),
    ActionColumn(
      children: [
        AppButton.primary(
          'Ich bin $name, ${guessing ? 'Antworten zeigen' : 'Frage zeigen'}',
          onPressed: local.showFibTurn,
        ),
        AppButton.quiet('Spiel abbrechen', onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localFibWrite(LocalController local, NobodyIsPerfectMatch match) => [
  PhaseHead(
    label: _fibLabel(match),
    title: 'Flunker los, ${local.players[local.index]}!',
    lead: 'Denk dir eine Antwort aus, die echt klingt.',
  ),
  _fibQuestion(match),
  SettingsGroup(
    key: const ValueKey('local-answer'),
    children: [
      AppField(
        label: 'Deine erfundene Antwort',
        controller: local.answerInput,
        hint: 'Klingt echt, ist aber ausgedacht',
        maxLength: NobodyIsPerfectRules.maxAnswerLength,
        onSubmitted: local.submitAnswer,
      ),
    ],
  ),
  ActionColumn(children: [AppButton.primary('Abgeben und weitergeben', onPressed: local.submitAnswer)]),
];

List<Widget> localFibGuess(LocalController local, NobodyIsPerfectMatch match) {
  final own = match.choices.where((c) => c.author == local.index).firstOrNull?.id;
  final chosen = match.guesses[local.index];
  return [
    PhaseHead(
      label: _fibLabel(match),
      title: 'Welche ist echt, ${local.players[local.index]}?',
      lead: 'Tippe auf die Antwort, die du für die echte hältst.',
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
        AppButton.primary('Tipp abgeben und weitergeben', onPressed: chosen == null ? null : local.finishGuess),
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
  ], title: over ? 'Endstand' : 'Punkte');
  final answer = ResultWord(intro: 'Die echte Antwort', word: match.questions[match.index].answer, size: 26);

  if (!over) {
    return [
      PhaseHead(label: _fibLabel(match), title: 'Auflösung'),
      _fibQuestion(match),
      answer,
      reveal,
      points,
      ActionColumn(
        children: [
          AppButton.primary('Nächste Frage', onPressed: local.nextQuestion),
          AppButton.quiet('Spiel abbrechen', onPressed: local.backToSetup),
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
      label: 'Nobody is Perfect · Spielende',
      title: winners.length == 1 ? '${winners.first} gewinnt!' : 'Gleichstand: ${winners.join(' und ')}',
      lead: 'Mit $best Punkten.',
    ),
    points,
    _fibQuestion(match),
    answer,
    reveal,
    ActionColumn(
      children: [
        AppButton.primary('Nochmal spielen', onPressed: local.startRound),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}
