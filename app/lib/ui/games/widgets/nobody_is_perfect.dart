// Online-Ansichten für Nobody is Perfect: Antwort schreiben, tippen, Auflösung und Spielende.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../data/repositories/game_data.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

List<Widget> nobodyIsPerfectView(AppController controller, RoomView room, NobodyIsPerfectView game) {
  final label = texts.nipQuestionLabel(game.questionNumber, game.questionCount);
  final question = QuestionCard(question: game.question, number: game.questionNumber, count: game.questionCount);
  final points = [for (final s in game.scores) (name: room.nameOf(s.playerId), score: s.score, gained: s.gained)];

  if (room.phase == Phase.writing || room.phase == Phase.guessing) {
    final writing = room.phase == Phase.writing;
    final done = (writing ? game.answeredIds : game.guessedIds).toSet();
    final waitingFor = [
      for (final p in room.players)
        if (game.participantIds.contains(p.id) && p.connected && !done.contains(p.id)) p.name,
    ];
    final total = done.length + waitingFor.length;
    final progress = writing ? texts.haveWritten(done.length, total) : texts.haveGuessed(done.length, total);
    return [
      PhaseHead(
        label: label,
        title: writing ? texts.nipWritingTitle : texts.nipGuessingTitle,
        lead: writing
            ? texts.nipWritingLead
            : texts.nipGuessingLead,
      ),
      question,
      if (writing)
        _Writing(key: const ValueKey('answer'), controller: controller, game: game)
      else
        ChoiceList(
          choices: [for (final c in game.choices) (id: c.id, text: c.text)],
          ownId: game.yourChoiceId,
          chosenId: game.yourGuess,
          onChoose: controller.guessAnswer,
        ),
      Hint(waitingFor.isEmpty ? progress : '$progress ${texts.waitingFor(waitingFor.join(', '))}'),
      ActionColumn(
        children: [
          if (room.you.host && done.isNotEmpty && waitingFor.isNotEmpty)
            AppButton(texts.stopWaiting, onPressed: controller.skipWaiting),
          endOrLeave(controller, room),
        ],
      ),
    ];
  }

  final reveal = RevealList([
    for (final r in game.reveal)
      RevealRow(
        id: r.id,
        text: r.text,
        correct: r.correct,
        author: r.authorId == null ? null : room.nameOf(r.authorId!),
        guessers: [for (final id in r.guesserIds) room.nameOf(id)],
      ),
  ]);
  final answer = ResultWord(intro: texts.theRealAnswer, word: game.answer ?? '', size: 26);

  if (room.phase == Phase.reveal) {
    return [
      PhaseHead(label: label, title: texts.reveal),
      question,
      answer,
      reveal,
      PointTable(points),
      ActionColumn(
        children: [
          if (room.you.host)
            AppButton.primary(texts.nextQuestion, onPressed: controller.nextQuestion)
          else
            Hint(texts.hostGoesToNextQuestion),
          endOrLeave(controller, room),
        ],
      ),
    ];
  }

  // Spielende
  final best = game.scores.fold(0, (top, s) => math.max(top, s.score));
  final winners = [
    for (final s in game.scores)
      if (s.score == best) s.playerId,
  ];
  final title = winners.length == 1
      ? texts.wins(room.nameOf(winners.first))
      : texts.tie(winners.map(room.nameOf).join(texts.and));
  return [
    PhaseHead(
      label: texts.nipGameOver,
      title: title,
      lead: winners.contains(room.you.id) ? texts.nobodyFibsLikeYou : texts.withPoints(best),
    ),
    PointTable(points, title: texts.finalScore),
    question,
    answer,
    reveal,
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

class _Writing extends StatelessWidget {
  const _Writing({super.key, required this.controller, required this.game});

  final AppController controller;
  final NobodyIsPerfectView game;

  @override
  Widget build(BuildContext context) {
    final submitted = game.yourAnswer;
    return SettingsGroup(
      children: [
        AppField(
          label: texts.yourFakeAnswer,
          controller: controller.answerInput,
          hint: texts.yourFakeAnswerHint,
          maxLength: NobodyIsPerfectRules.maxAnswerLength,
          onSubmitted: controller.submitAnswer,
        ),
        AppButton.primary(submitted == null ? texts.submitAnswer : texts.changeAnswer, onPressed: controller.submitAnswer),
        if (submitted != null) Hint(texts.answerSubmitted(submitted)),
      ],
    );
  }
}
