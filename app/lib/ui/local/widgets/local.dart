// Ansichten für den lokalen Modus: ein Handy, das reihum weitergegeben wird.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../../domain/models/models.dart';
import '../../games/widgets/impostor.dart' show StartPlayer;
import '../../games/widgets/tabu.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/showcase.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

List<Widget> localView(BuildContext context, LocalController local) => switch (local.stage) {
  Stage.setup => _setup(context, local),
  Stage.pass => _pass(local),
  Stage.card => _card(local),
  Stage.table => local.impostor != null ? _impostorTable(local) : _werwolfTable(local),
  Stage.reveal => _impostorReveal(local),
  Stage.tabuReady => _tabuReady(local, local.match!),
  Stage.tabuTurn => _tabuTurn(local, local.match!),
  Stage.tabuOver => _tabuOver(local, local.match!),
  Stage.fibPass => _fibPass(local, local.fib!),
  Stage.fibWrite => _fibWrite(local, local.fib!),
  Stage.fibGuess => _fibGuess(local, local.fib!),
  Stage.fibReveal || Stage.fibOver => _fibReveal(local, local.fib!),
};

final _games = <ShowcaseGame>[
  (
    type: GameType.impostor,
    name: 'Impostor',
    description: 'Alle kennen ein geheimes Wort, nur die Impostor nicht.',
    minPlayers: minPlayers[GameType.impostor]!,
  ),
  (
    type: GameType.werwolf,
    name: 'Werwolf',
    description: 'Das Handy verteilt nur die Rollen. Den Rest leitet ihr am Tisch.',
    minPlayers: minPlayers[GameType.werwolf]!,
  ),
  (
    type: GameType.tabu,
    name: 'Tabu',
    description: 'Erklärt eurem Team Begriffe, ohne die verbotenen Wörter zu sagen.',
    minPlayers: minPlayers[GameType.tabu]!,
  ),
  (
    type: GameType.nobodyIsPerfect,
    name: 'Nobody is Perfect',
    description: 'Erfindet glaubwürdige Antworten auf kuriose Fragen und findet die echte.',
    minPlayers: minPlayers[GameType.nobodyIsPerfect]!,
  ),
];

List<Widget> _setup(BuildContext context, LocalController local) {
  final setup = local.setup;
  final problem = setup.problem;
  final index = _games.indexWhere((g) => g.type == setup.game);
  final game = _games[index];
  return [
    GameHero(
      title: game.name,
      text: game.description,
      meta: 'ab ${game.minPlayers} Spielern · Ein Handy geht reihum, kein Internet nötig',
      game: game.type,
      count: _games.length,
      index: index,
    ),
    GameRow(games: _games, selected: setup.game, onSelect: (type) => local.configure((s) => s.game = type)),
    Narrow(
      children: [
        CustomPaint(
          key: const ValueKey('local-settings'),
          painter: DashedBorder(color: context.palette.line, radius: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Gap(
              children: [
                AppStepper(
                  label: 'Spieler',
                  value: setup.playerCount,
                  min: minPlayers[GameType.impostor]!,
                  max: maxPlayers,
                  onStep: local.changePlayers,
                ),
                if (setup.game == GameType.werwolf)
                  const Hint('Die Spielleitung zählt nicht mit, sie bekommt keine Karte.'),
                SettingsGroup(
                  key: const ValueKey('names'),
                  children: [
                    const Text('Namen (optional)', style: TextStyle(fontWeight: FontWeight.w700)),
                    AutoGrid(
                      minWidth: 152,
                      children: [
                        for (var seat = 0; seat < setup.playerCount; seat++)
                          _NameField(key: ValueKey(seat), local: local, seat: seat),
                      ],
                    ),
                  ],
                ),
                _gameSettings(local),
              ],
            ),
          ),
        ),
        ActionColumn(
          children: [
            AppButton.primary(
              setup.game == GameType.nobodyIsPerfect ? 'Los geht\'s' : 'Karten verteilen',
              onPressed: problem == null ? local.startRound : null,
            ),
            if (problem != null) Hint(problem),
          ],
        ),
      ],
    ),
  ];
}

Widget _gameSettings(LocalController local) {
  final setup = local.setup;
  switch (setup.game) {
    case GameType.nobodyIsPerfect:
      return NobodyIsPerfectOptionsView(questionCount: setup.questionCount, onCount: local.changeQuestionCount);
    case GameType.tabu:
      return Gap(
        children: [
          TabuOptionsView(
            turnSeconds: setup.turnSeconds,
            targetScore: setup.targetScore,
            teamCount: setup.teamCount,
            autoTeams: setup.autoTeams,
            onTurnSeconds: local.changeTurnSeconds,
            onTargetScore: local.changeTargetScore,
            onTeamCount: local.changeTeamCount,
            onAutoTeams: (value) => local.configure((s) => s.autoTeams = value),
          ),
          if (!setup.autoTeams) _TeamPicker(local),
        ],
      );
    case GameType.impostor:
      return ImpostorOptionsView(
        form: ImpostorForm(
          impostorCount: setup.impostorCount,
          maxImpostorCount: setup.maxImpostors,
          seesCategory: setup.seesCategory,
          randomStartPlayer: setup.randomStartPlayer,
          allCategories: gameData.categoryNames,
          selectedCategories: setup.categories,
          categoryHint: 'Das Wort kommt zufällig aus den angekreuzten Kategorien.',
        ),
        onCount: local.changeImpostorCount,
        onSeesCategory: (value) => local.configure((s) => s.seesCategory = value),
        onRandomStart: (value) => local.configure((s) => s.randomStartPlayer = value),
        onCategory: local.toggleCategory,
      );
    case GameType.werwolf:
    case GameType.buzzer:
      return WerwolfOptionsView(
        form: WerwolfForm(
          werewolfCount: setup.werewolfCount,
          effectiveWerewolfCount: werewolves(setup.playerCount, setup.werewolfCount),
          selectedRoles: setup.roles,
        ),
        onCount: local.changeWerewolfCount,
        onAuto: () => local.configure((s) => s.werewolfCount = null),
        onRole: local.toggleRole,
      );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({super.key, required this.local, required this.seat});

  final LocalController local;
  final int seat;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(
    text: widget.seat < widget.local.setup.names.length ? widget.local.setup.names[widget.seat] : '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(
    controller: _controller,
    hint: 'Spieler ${widget.seat + 1}',
    semanticLabel: 'Name von Spieler ${widget.seat + 1}',
    maxLength: 20,
    dense: true,
    capitalization: TextCapitalization.words,
    onChanged: (name) => widget.local.setName(widget.seat, name),
  );
}

class _TeamPicker extends StatelessWidget {
  const _TeamPicker(this.local);

  final LocalController local;

  @override
  Widget build(BuildContext context) {
    final setup = local.setup;
    final names = playerNames(setup.playerCount, setup.names);
    final p = context.palette;
    return SettingsGroup(
      children: [
        const Text('Teams', style: TextStyle(fontWeight: FontWeight.w700)),
        for (var seat = 0; seat < names.length; seat++)
          Wrap(
            key: ValueKey(seat),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(names[seat]),
              Semantics(
                container: true,
                label: 'Team von ${names[seat]}',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var team = 0; team < setup.teamCount; team++)
                      _TeamChip(
                        team: team,
                        selected: seat < setup.teams.length && setup.teams[seat] == team,
                        palette: p,
                        onPressed: () => local.chooseTeam(seat, team),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.team, required this.selected, required this.palette, required this.onPressed});

  final int team;
  final bool selected;
  final Palette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    radius: 20,
    selected: selected,
    onPressed: onPressed,
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        color: selected ? palette.accent : Colors.transparent,
        border: Border.all(color: palette.line, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(color: teamColors[team], child: const SizedBox(width: 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                Tabu.teamNames[team].replaceFirst('Team ', ''),
                style: TextStyle(
                  color: selected ? palette.onAccent : palette.text,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : null,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ---- Karten ----------------------------------------------------------------

List<Widget> _pass(LocalController local) {
  final name = local.players[local.index];
  return [
    PhaseHead(
      label: 'Karte ${local.index + 1} von ${local.players.length}',
      title: 'Gib das Handy an $name',
      lead: 'Nur $name darf auf den Bildschirm schauen.',
    ),
    ActionColumn(
      children: [
        AppButton.primary('Ich bin $name, Karte zeigen', onPressed: local.showCard),
        AppButton.quiet('Runde abbrechen', onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> _card(LocalController local) {
  final last = local.index == local.players.length - 1;
  final CardTone tone;
  final Widget content;
  final impostor = local.impostor;
  if (impostor != null) {
    final isImpostor = impostor.impostors.contains(local.index);
    tone = isImpostor ? CardTone.wolves : CardTone.neutral;
    content = ImpostorCardContent(
      isImpostor: isImpostor,
      word: impostor.word,
      category: !isImpostor || local.setup.seesCategory ? impostor.category : null,
      fellowImpostors: [
        if (isImpostor)
          for (final seat in impostor.impostors)
            if (seat != local.index) local.players[seat],
      ],
    );
  } else {
    final deal = local.werwolf!;
    final role = deal.perPlayer[local.index];
    tone = CardTone.forTeam(role.team);
    content = RoleCardContent(
      role: gameData.cardFor(role),
      knownWolves: knownWolves(deal, local.players, local.index),
      leftoverRoles: [
        if (role.id == thief)
          for (final r in deal.leftover) r.name,
      ],
    );
  }
  return [
    GameLabel('Karte von ${local.players[local.index]}'),
    CardFace(tone: tone, child: content),
    ActionColumn(
      children: [
        AppButton.primary(
          last ? 'Verstecken, alle haben ihre Karte' : 'Verstecken und weitergeben',
          onPressed: local.passOn,
        ),
      ],
    ),
  ];
}

List<Widget> _impostorTable(LocalController local) {
  final start = local.impostor!.startPlayer;
  return [
    const PhaseHead(
      label: 'Impostor',
      title: 'Alle kennen ihr Wort',
      lead: 'Reihum sagt jeder ein Wort als Hinweis. Dann zeigt ihr gleichzeitig auf euren Verdacht.',
    ),
    if (start != null) StartPlayer(name: local.players[start]),
    ActionColumn(
      children: [
        AppButton.primary('Auflösen', onPressed: local.revealImpostor),
        AppButton.quiet('Runde abbrechen', onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> _impostorReveal(LocalController local) {
  final deal = local.impostor!;
  final names = [for (final seat in deal.impostors) local.players[seat]];
  return [
    PhaseHead(
      label: 'Impostor',
      title: 'Auflösung',
      leadParts: [
        for (var i = 0; i < names.length; i++) ...[if (i > 0) ' und ', Strong(names[i])],
        names.length == 1 ? ' war der Impostor.' : ' waren die Impostor.',
      ],
    ),
    ResultWord(intro: 'Das Wort war', word: deal.word, category: deal.category),
    ActionColumn(
      children: [
        AppButton.primary('Nächste Runde', onPressed: local.startRound),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> _werwolfTable(LocalController local) {
  final deal = local.werwolf!;
  return [
    const PhaseHead(
      label: 'Werwolf',
      title: 'Alle kennen ihre Rolle',
      lead: 'Die Spielleitung führt jetzt durch Nacht und Tag.',
    ),
    ActionColumn(
      children: [
        if (local.overviewOpen) ...[
          RoleOverview(
            rows: [
              for (var i = 0; i < local.players.length; i++)
                (name: local.players[i], role: gameData.cardFor(deal.perPlayer[i])),
            ],
            leftoverRoles: [for (final r in deal.leftover) r.name],
          ),
          AppButton('Übersicht verstecken', onPressed: local.hideOverview),
        ] else
          AppButton('Spielleitung: alle Rollen zeigen', onPressed: local.showOverview),
        AppButton.quiet('Neu verteilen', onPressed: local.redeal),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}

// ---- Tabu ------------------------------------------------------------------

Widget _scores(TabuMatch match, int current) => Scoreboard(
  teams: [for (var i = 0; i < match.scores.length; i++) (name: Tabu.teamNames[i], score: match.scores[i])],
  currentTeam: current,
  targetScore: match.targetScore,
);

List<Widget> _tabuReady(LocalController local, TabuMatch match) {
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

List<Widget> _tabuTurn(LocalController local, TabuMatch match) => [
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

List<Widget> _tabuOver(LocalController local, TabuMatch match) {
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

// ---- Nobody is Perfect -----------------------------------------------------

String _fibLabel(NobodyIsPerfectMatch match) =>
    'Nobody is Perfect · Frage ${match.index + 1} von ${match.questions.length}';

Widget _fibQuestion(NobodyIsPerfectMatch match) => QuestionCard(
  question: match.questions[match.index].question,
  number: match.index + 1,
  count: match.questions.length,
);

List<Widget> _fibPass(LocalController local, NobodyIsPerfectMatch match) {
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

List<Widget> _fibWrite(LocalController local, NobodyIsPerfectMatch match) => [
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

List<Widget> _fibGuess(LocalController local, NobodyIsPerfectMatch match) {
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

List<Widget> _fibReveal(LocalController local, NobodyIsPerfectMatch match) {
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
