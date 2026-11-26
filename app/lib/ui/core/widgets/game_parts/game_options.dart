// Einstellungen der Spiele in der Lobby und im lokalen Modus, dazu die Zusammenfassung für Mitspieler.
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/game_data.dart';
import '../../../../l10n/l10n.dart';
import '../../themes/theme.dart';
import '../widgets.dart';

/// Zusammenfassung der Einstellungen für alle, die sie nicht ändern dürfen.
class SettingsSummary extends StatelessWidget {
  const SettingsSummary(this.lines, {super.key});

  final List<List<Object>> lines;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: context.palette.muted, fontSize: 15);
    return SettingsGroup(
      children: [
        Gap(
          spacing: 2,
          children: [
            for (final line in lines)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 20, child: Text('•', style: style)),
                  Expanded(child: RichLine(line, style: style)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class ImpostorForm {
  const ImpostorForm({
    required this.impostorCount,
    required this.maxImpostorCount,
    required this.seesCategory,
    required this.randomStartPlayer,
    required this.allCategories,
    required this.categoryNames,
    required this.selectedCategories,
    required this.categoryHint,
  });
  final int impostorCount;
  final int maxImpostorCount;
  final bool seesCategory;
  final bool randomStartPlayer;
  /// IDs, dazu [categoryNames] in derselben Reihenfolge.
  final List<String> allCategories;
  final List<String> categoryNames;
  final List<String> selectedCategories;
  final String categoryHint;

  String nameOf(String id) => categoryNames[allCategories.indexOf(id)];

  List<List<Object>> get summary => [
    ['${texts.impostorCount}: ', Strong('$impostorCount')],
    ['${texts.impostorSeesCategory}: ', Strong(seesCategory ? texts.on : texts.off)],
    ['${texts.randomStartPlayer}: ', Strong(randomStartPlayer ? texts.on : texts.off)],
    [
      '${texts.categories}: ',
      Strong(
        selectedCategories.length == allCategories.length
            ? texts.categoriesAll
            : selectedCategories.map(nameOf).join(', '),
      ),
    ],
  ];
}

class ImpostorOptionsView extends StatelessWidget {
  const ImpostorOptionsView({
    super.key,
    required this.form,
    required this.onCount,
    required this.onSeesCategory,
    required this.onRandomStart,
    required this.onCategory,
  });

  final ImpostorForm form;
  final ValueChanged<int> onCount;
  final ValueChanged<bool> onSeesCategory;
  final ValueChanged<bool> onRandomStart;
  final void Function(String id, bool selected) onCategory;

  @override
  Widget build(BuildContext context) {
    final selected = form.selectedCategories.toSet();
    return Gap(
      children: [
        SettingsGroup(
          children: [
            AppStepper(
              label: texts.impostorCount,
              value: form.impostorCount,
              min: 1,
              max: form.maxImpostorCount,
              onStep: onCount,
            ),
            AppCheck(value: form.seesCategory, onChanged: onSeesCategory, label: texts.impostorSeesCategory),
            AppCheck(value: form.randomStartPlayer, onChanged: onRandomStart, label: texts.randomStartPlayer),
          ],
        ),
        SettingsGroup(
          children: [
            Text(texts.categories, style: const TextStyle(fontWeight: FontWeight.w700)),
            AutoGrid(
              minWidth: 152,
              children: [
                for (final id in form.allCategories)
                  AppCheck(
                    key: ValueKey(id),
                    value: selected.contains(id),
                    bold: false,
                    label: form.nameOf(id),
                    // Die letzte angekreuzte Kategorie lässt sich nicht abwählen, ohne Kategorie gäbe es kein Wort
                    onChanged: selected.contains(id) && selected.length == 1
                        ? null
                        : (value) => onCategory(id, value),
                  ),
              ],
            ),
            Hint(form.categoryHint),
          ],
        ),
      ],
    );
  }
}

class WerwolfForm {
  const WerwolfForm({
    required this.werewolfCount,
    required this.effectiveWerewolfCount,
    required this.selectedRoles,
    this.hostIsGameMaster,
  });

  /// null = automatisch.
  final int? werewolfCount;
  final int effectiveWerewolfCount;
  final List<String> selectedRoles;

  /// Nur online: Host spielt nicht mit und sieht alle Rollen. null = Schalter nicht zeigen.
  final bool? hostIsGameMaster;

  List<List<Object>> get summary {
    final roles = selectedRoles.map((id) => gameData.roleById(id).name).join(', ');
    return [
      [
        '${texts.werewolves}: ',
        Strong(werewolfCount == null ? texts.werewolvesAuto(effectiveWerewolfCount) : '$effectiveWerewolfCount'),
      ],
      ['${texts.specialRoles}: ', Strong(roles.isEmpty ? texts.none : roles)],
      if (hostIsGameMaster == true) [texts.gameMasterSitsOut],
    ];
  }
}

class WerwolfOptionsView extends StatelessWidget {
  const WerwolfOptionsView({
    super.key,
    required this.form,
    required this.onCount,
    required this.onAuto,
    required this.onRole,
    this.onGameMaster,
  });

  final WerwolfForm form;
  final ValueChanged<int> onCount;
  final VoidCallback onAuto;
  final void Function(String id, bool selected) onRole;
  final ValueChanged<bool>? onGameMaster;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final gameMaster = form.hostIsGameMaster;
    final selected = form.selectedRoles.toSet();
    return Gap(
      children: [
        if (gameMaster != null)
          SettingsGroup(
            children: [
              AppCheck(value: gameMaster, onChanged: onGameMaster, label: texts.iAmGameMaster),
              Hint(texts.gameMasterSeesRoles),
            ],
          ),
        SettingsGroup(
          children: [
            AppStepper(
              label: texts.werewolves,
              value: form.effectiveWerewolfCount,
              min: 1,
              max: maxPlayers - 1,
              onStep: onCount,
            ),
            form.werewolfCount == null
                ? Hint(texts.werewolvesAutoHint)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(texts.werewolvesBackToAuto, small: true, onPressed: onAuto),
                  ),
          ],
        ),
        SettingsGroup(
          children: [
            Text(texts.specialRoles, style: const TextStyle(fontWeight: FontWeight.w700)),
            for (final team in gameData.teamNames.entries)
              Container(
                key: ValueKey(team.key),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Gap(
                  spacing: 10,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        team.value,
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.muted),
                      ),
                    ),
                    for (final role in gameData.specialRoles.where((r) => r.team == team.key))
                      AppCheck(
                        key: ValueKey(role.id),
                        value: selected.contains(role.id),
                        onChanged: (value) => onRole(role.id, value),
                        label: role.name,
                        description: role.description,
                      ),
                  ],
                ),
              ),
            Hint(texts.specialRolesHint),
          ],
        ),
      ],
    );
  }
}

List<List<Object>> tabuSummary({
  required int turnSeconds,
  required int targetScore,
  required int teamCount,
  required bool autoTeams,
}) => [
  ['${texts.turnSeconds}: ', Strong('$turnSeconds')],
  ['${texts.targetScore}: ', Strong('$targetScore')],
  ['${texts.teams}: ', Strong('$teamCount'), ', ${autoTeams ? texts.teamsMixed : texts.teamsChosen}'],
];

class TabuOptionsView extends StatelessWidget {
  const TabuOptionsView({
    super.key,
    required this.turnSeconds,
    required this.targetScore,
    required this.teamCount,
    required this.autoTeams,
    required this.onTurnSeconds,
    required this.onTargetScore,
    required this.onTeamCount,
    required this.onAutoTeams,
  });

  final int turnSeconds;
  final int targetScore;
  final int teamCount;
  final bool autoTeams;
  final ValueChanged<int> onTurnSeconds;
  final ValueChanged<int> onTargetScore;
  final ValueChanged<int> onTeamCount;
  final ValueChanged<bool> onAutoTeams;

  @override
  Widget build(BuildContext context) => Gap(
    children: [
      SettingsGroup(
        children: [
          AppStepper(
            label: texts.turnSeconds,
            value: turnSeconds,
            min: Tabu.minTurnSeconds,
            max: Tabu.maxTurnSeconds,
            onStep: onTurnSeconds,
          ),
          AppStepper(
            label: texts.targetScore,
            value: targetScore,
            min: Tabu.minTargetScore,
            max: Tabu.maxTargetScore,
            onStep: onTargetScore,
          ),
        ],
      ),
      SettingsGroup(
        children: [
          AppStepper(label: texts.teams, value: teamCount, min: Tabu.minTeams, max: Tabu.maxTeams, onStep: onTeamCount),
          AppCheck(value: autoTeams, onChanged: onAutoTeams, label: texts.teamsAutoMix),
          Hint(
            autoTeams ? texts.teamsAutoMixHint : texts.teamsChosenHint,
          ),
        ],
      ),
    ],
  );
}

class NobodyIsPerfectOptionsView extends StatelessWidget {
  const NobodyIsPerfectOptionsView({super.key, required this.questionCount, required this.onCount});

  final int questionCount;
  final ValueChanged<int> onCount;

  @override
  Widget build(BuildContext context) => SettingsGroup(
    children: [
      AppStepper(
        label: texts.questions,
        value: questionCount,
        min: NobodyIsPerfectRules.minQuestions,
        max: NobodyIsPerfectRules.maxQuestions,
        onStep: onCount,
      ),
      Hint(texts.nobodyIsPerfectScoringHint),
    ],
  );
}
