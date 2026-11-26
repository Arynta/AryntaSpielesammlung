// Lobby: Raumcode, Spielauswahl, Einstellungen, Teams und Mitspieler.
import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../data/repositories/game_data.dart';
import '../../../domain/models/models.dart';
import '../../games/widgets/buzzer.dart';
import '../../games/widgets/geo_bingo.dart';
import '../../games/widgets/tabu.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/showcase.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

List<Widget> lobbyView(BuildContext context, AppController controller, RoomView room) {
  final waitHint = room.canStart && !room.you.host
      ? 'Alle sind bereit. Die Spielleitung kann starten.'
      : room.startHint;
  final games = [
    for (final g in room.games) (type: g.type, name: g.name, description: g.description, minPlayers: g.minPlayers),
  ];
  final index = games.indexWhere((g) => g.type == room.game);
  final game = games[index];
  return [
    GameHero(
      title: game.name,
      text: game.description,
      meta: 'ab ${game.minPlayers} Spielern',
      game: game.type,
      count: games.length,
      index: index,
      child: _RoomCode(controller, room),
    ),
    GameRow(
      key: const ValueKey('picker'),
      games: games,
      selected: room.game,
      locked: {
        for (final g in room.games)
          if (g.locked) g.type,
      },
      onSelect: room.you.host ? controller.selectGame : null,
    ),
    Narrow(
      children: [
        _Settings(key: const ValueKey('settings'), controller: controller, room: room),
        if (room.game == GameType.tabu && !room.tabuSettings.autoTeams) TeamChoice(controller: controller, room: room),
        PlayerList(room: room, showReady: true, showLimit: true, onKick: room.you.host ? controller.kick : null),
        ActionColumn(
          children: [
            ReadyButton(controller, room),
            if (room.you.host)
              AppButton.primary('Spiel starten', onPressed: room.canStart ? controller.startGame : null),
            if (waitHint != null) Hint(waitHint),
            AppButton.quiet('Raum verlassen', onPressed: controller.leave),
          ],
        ),
      ],
    ),
  ];
}

class _RoomCode extends StatelessWidget {
  const _RoomCode(this.controller, this.room);

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Raumcode', style: TextStyle(color: p.muted)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 16,
            children: [
              Expanded(
                // Auf schmalen Handys wird der Code kleiner statt umzubrechen
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    room.code,
                    style: display(72, height: 0.95, color: p.accent, letterSpacing: 8.6),
                  ),
                ),
              ),
              AppButton('Link teilen', small: true, onPressed: controller.shareRoom),
            ],
          ),
        ],
      ),
    );
  }
}

/// Aufklappbarer Bereich: Spielerlimit für alle Spiele, dazu die Einstellungen des gewählten Spiels.
class _Settings extends StatelessWidget {
  const _Settings({super.key, required this.controller, required this.room});

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = controller.settingsOpen;
    return Expandable(
      open: open,
      onChanged: controller.setSettingsOpen,
      header: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: open ? p.accent : p.line, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('Spieleinstellungen', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            Chevron(open: open),
          ],
        ),
      ),
      child: CustomPaint(
        painter: DashedBorder(color: p.line, radius: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Gap(children: [_playerLimit(), _gameSettings()]),
        ),
      ),
    );
  }

  Widget _playerLimit() {
    final limit = room.playerLimit;
    if (!room.you.host) {
      return Row(
        children: [
          const Expanded(
            child: Text('Spielerlimit', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('${limit.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    return AppStepper(
      label: 'Spielerlimit',
      lessLabel: 'Limit verringern',
      moreLabel: 'Limit erhöhen',
      value: limit.value,
      min: limit.min,
      max: limit.max,
      onStep: controller.changePlayerLimit,
    );
  }

  Widget _gameSettings() {
    final host = room.you.host;
    switch (room.game) {
      case GameType.impostor:
        return host ? _impostorSettings() : _impostorSummary();
      case GameType.tabu:
        final s = room.tabuSettings;
        if (!host) {
          return SettingsSummary(
            tabuSummary(
              turnSeconds: s.turnSeconds,
              targetScore: s.targetScore,
              teamCount: s.teamCount,
              autoTeams: s.autoTeams,
            ),
          );
        }
        return TabuOptionsView(
          turnSeconds: s.turnSeconds,
          targetScore: s.targetScore,
          teamCount: s.teamCount,
          autoTeams: s.autoTeams,
          onTurnSeconds: controller.changeTurnSeconds,
          onTargetScore: controller.changeTargetScore,
          onTeamCount: controller.changeTeamCount,
          onAutoTeams: (value) => controller.configureTabu(autoTeams: value),
        );
      case GameType.nobodyIsPerfect:
        final count = room.nobodyIsPerfectSettings.questionCount;
        if (!host) {
          return SettingsSummary([
            ['Fragen: ', Strong('$count')],
          ]);
        }
        return NobodyIsPerfectOptionsView(questionCount: count, onCount: controller.changeQuestionCount);
      case GameType.buzzer:
        return BuzzerSettingsView(controller: controller, room: room);
      case GameType.geoBingo:
        return GeoBingoSettingsView(controller: controller, room: room);
      case GameType.werwolf:
        final s = room.werwolfSettings;
        final form = WerwolfForm(
          werewolfCount: s.werewolfCount,
          effectiveWerewolfCount: s.effectiveWerewolfCount,
          selectedRoles: s.selectedRoles,
          hostIsGameMaster: s.hostIsGameMaster,
        );
        if (!host) return SettingsSummary(form.summary);
        return WerwolfOptionsView(
          form: form,
          onCount: controller.changeWerewolfCount,
          onAuto: controller.autoWerewolves,
          onRole: controller.toggleRole,
          onGameMaster: controller.setHostIsGameMaster,
        );
    }
  }

  ImpostorForm _impostorForm() {
    final s = room.impostorSettings;
    return ImpostorForm(
      impostorCount: s.impostorCount,
      maxImpostorCount: s.maxImpostorCount,
      seesCategory: s.impostorSeesCategory,
      randomStartPlayer: s.randomStartPlayer,
      allCategories: s.allCategories,
      selectedCategories: s.selectedCategories,
      categoryHint: s.customWordSet
          ? 'Gilt erst wieder, wenn kein eigenes Wort gesetzt ist.'
          : 'Das Wort kommt zufällig aus den angekreuzten Kategorien.',
    );
  }

  Widget _impostorSettings() {
    final customWord = room.impostorSettings.customWord;
    return Gap(
      children: [
        ImpostorOptionsView(
          form: _impostorForm(),
          onCount: controller.changeImpostorCount,
          onSeesCategory: (value) => controller.configureImpostor(seesCategory: value),
          onRandomStart: (value) => controller.setImpostorOptions(randomStartPlayer: value),
          onCategory: controller.toggleCategory,
        ),
        SettingsGroup(
          key: const ValueKey('custom-word'),
          children: [
            AppField(
              label: 'Eigenes Wort (optional)',
              controller: controller.customWordInput,
              hint: 'leer lassen = Wortliste',
              maxLength: maxCustomWordLength,
              onSubmitted: controller.saveWord,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton('Wort übernehmen', small: true, onPressed: controller.saveWord),
            ),
            if (customWord != null && customWord.isNotEmpty) ...[
              Hint.rich(['Eigenes Wort: ', Strong(customWord), '. Du spielst die nächste Runde nicht mit.']),
              AppButton.quiet('Wort entfernen, Wortliste nehmen', onPressed: controller.clearWord),
            ],
          ],
        ),
      ],
    );
  }

  Widget _impostorSummary() => SettingsSummary([
    ..._impostorForm().summary,
    if (room.impostorSettings.customWordSet) ['Die Spielleitung hat ein eigenes Wort gewählt und spielt nicht mit.'],
  ]);
}
