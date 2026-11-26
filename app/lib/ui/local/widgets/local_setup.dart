// Lokaler Modus: Einrichtung mit Spiel, Spielern, Namen und Teams.
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../../../l10n/l10n.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../../domain/models/models.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/showcase.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

List<ShowcaseGame> get _games => [
  (
    type: GameType.impostor,
    name: 'Impostor',
    description: texts.localImpostorDescription,
    minPlayers: minPlayers[GameType.impostor]!,
  ),
  (
    type: GameType.werwolf,
    name: texts.werwolf,
    description: texts.localWerwolfDescription,
    minPlayers: minPlayers[GameType.werwolf]!,
  ),
  (
    type: GameType.tabu,
    name: texts.tabu,
    description: texts.localTabuDescription,
    minPlayers: minPlayers[GameType.tabu]!,
  ),
  (
    type: GameType.nobodyIsPerfect,
    name: 'Nobody is Perfect',
    description: texts.localNipDescription,
    minPlayers: minPlayers[GameType.nobodyIsPerfect]!,
  ),
];

List<Widget> localSetupView(BuildContext context, LocalController local) {
  final setup = local.setup;
  final problem = setup.problem;
  final index = _games.indexWhere((g) => g.type == setup.game);
  final game = _games[index];
  return [
    GameHero(
      title: game.name,
      text: game.description,
      meta: '${texts.minPlayers(game.minPlayers)} · ${texts.localMeta}',
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
                  label: texts.playerCount,
                  value: setup.playerCount,
                  min: minPlayers[GameType.impostor]!,
                  max: maxPlayers,
                  onStep: local.changePlayers,
                ),
                if (setup.game == GameType.werwolf)
                  Hint(texts.localGameMasterNoCard),
                SettingsGroup(
                  key: const ValueKey('names'),
                  children: [
                    Text(texts.namesOptional, style: const TextStyle(fontWeight: FontWeight.w700)),
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
              setup.game == GameType.nobodyIsPerfect ? texts.letsGo : texts.dealCards,
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
          allCategories: gameData.categoryIds,
          categoryNames: [for (final c in gameData.categories) c.name],
          selectedCategories: setup.categories,
          categoryHint: texts.categoriesHint,
        ),
        onCount: local.changeImpostorCount,
        onSeesCategory: (value) => local.configure((s) => s.seesCategory = value),
        onRandomStart: (value) => local.configure((s) => s.randomStartPlayer = value),
        onCategory: local.toggleCategory,
      );
    case GameType.werwolf:
    case GameType.buzzer:
    case GameType.geoBingo:
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
    hint: texts.playerNumber(widget.seat + 1),
    semanticLabel: texts.nameOfPlayer(widget.seat + 1),
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
        Text(texts.teams, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                label: texts.teamOf(names[seat]),
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
                tabuTeamNames[team].replaceFirst('Team ', ''),
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
