// Online-Ansichten für Nobody is Perfect: Antwort schreiben, tippen, Auflösung und Spielende.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../logic/app_controller.dart';
import '../../logic/game_data.dart';
import '../../logic/models.dart';
import '../players.dart';
import '../shared.dart';
import '../widgets.dart';

List<Widget> nobodyIsPerfectView(AppController controller, RoomView room, NobodyIsPerfectView game) {
  final label = 'Nobody is Perfect · Frage ${game.questionNumber} von ${game.questionCount}';
  final question = QuestionCard(question: game.question, number: game.questionNumber, count: game.questionCount);
  final points = [for (final s in game.scores) (name: room.nameOf(s.playerId), score: s.score, gained: s.gained)];

  if (room.phase == Phase.writing || room.phase == Phase.guessing) {
    final writing = room.phase == Phase.writing;
    final done = (writing ? game.answeredIds : game.guessedIds).toSet();
    final waitingFor = [
      for (final p in room.players)
        if (game.participantIds.contains(p.id) && p.connected && !done.contains(p.id)) p.name,
    ];
    final progress =
        '${done.length} von ${done.length + waitingFor.length} '
        '${writing ? 'haben geschrieben' : 'haben getippt'}.';
    return [
      PhaseHead(
        label: label,
        title: writing ? 'Flunker los!' : 'Welche ist echt?',
        lead: writing
            ? 'Denk dir eine Antwort aus, die echt klingt. Je glaubwürdiger, desto mehr fallen darauf herein.'
            : 'Tippe auf die Antwort, die du für die echte hältst. Du kannst deinen Tipp noch ändern.',
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
      Hint(waitingFor.isEmpty ? progress : '$progress Warte auf ${waitingFor.join(', ')}.'),
      ActionColumn(
        children: [
          if (room.you.host && done.isNotEmpty && waitingFor.isNotEmpty)
            AppButton('Nicht länger warten', onPressed: controller.skipWaiting),
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
  final answer = ResultWord(intro: 'Die echte Antwort', word: game.answer ?? '', size: 26);

  if (room.phase == Phase.reveal) {
    return [
      PhaseHead(label: label, title: 'Auflösung'),
      question,
      answer,
      reveal,
      PointTable(points),
      ActionColumn(
        children: [
          if (room.you.host)
            AppButton.primary('Nächste Frage', onPressed: controller.nextQuestion)
          else
            const Hint('Die Spielleitung geht zur nächsten Frage.'),
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
      ? '${room.nameOf(winners.first)} gewinnt!'
      : 'Gleichstand: ${winners.map(room.nameOf).join(' und ')}';
  return [
    PhaseHead(
      label: 'Nobody is Perfect · Spielende',
      title: title,
      lead: winners.contains(room.you.id) ? 'Niemand flunkert so gut wie du.' : 'Mit $best Punkten.',
    ),
    PointTable(points, title: 'Endstand'),
    question,
    answer,
    reveal,
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
          label: 'Deine erfundene Antwort',
          controller: controller.answerInput,
          hint: 'Klingt echt, ist aber ausgedacht',
          maxLength: NobodyIsPerfectRules.maxAnswerLength,
          onSubmitted: controller.submitAnswer,
        ),
        AppButton.primary(submitted == null ? 'Antwort abgeben' : 'Antwort ändern', onPressed: controller.submitAnswer),
        if (submitted != null) Hint('Abgegeben: „$submitted“. Du kannst sie noch ändern, bis alle fertig sind.'),
      ],
    );
  }
}
