// Einstellungen der Spiele in der Lobby und im lokalen Modus, dazu die Zusammenfassung für Mitspieler.
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/game_data.dart';
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
    required this.selectedCategories,
    required this.categoryHint,
  });
  final int impostorCount;
  final int maxImpostorCount;
  final bool seesCategory;
  final bool randomStartPlayer;
  final List<String> allCategories;
  final List<String> selectedCategories;
  final String categoryHint;

  List<List<Object>> get summary => [
    ['Anzahl Impostor: ', Strong('$impostorCount')],
    ['Impostor sieht die Kategorie: ', Strong(seesCategory ? 'an' : 'aus')],
    ['Startspieler auslosen: ', Strong(randomStartPlayer ? 'an' : 'aus')],
    [
      'Kategorien: ',
      Strong(selectedCategories.length == allCategories.length ? 'alle' : selectedCategories.join(', ')),
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
  final void Function(String name, bool selected) onCategory;

  @override
  Widget build(BuildContext context) {
    final selected = form.selectedCategories.toSet();
    return Gap(
      children: [
        SettingsGroup(
          children: [
            AppStepper(
              label: 'Anzahl Impostor',
              value: form.impostorCount,
              min: 1,
              max: form.maxImpostorCount,
              onStep: onCount,
            ),
            AppCheck(value: form.seesCategory, onChanged: onSeesCategory, label: 'Impostor sieht die Kategorie'),
            AppCheck(value: form.randomStartPlayer, onChanged: onRandomStart, label: 'Startspieler auslosen'),
          ],
        ),
        SettingsGroup(
          children: [
            const Text('Kategorien', style: TextStyle(fontWeight: FontWeight.w700)),
            AutoGrid(
              minWidth: 152,
              children: [
                for (final name in form.allCategories)
                  AppCheck(
                    key: ValueKey(name),
                    value: selected.contains(name),
                    bold: false,
                    label: name,
                    // Die letzte angekreuzte Kategorie lässt sich nicht abwählen, ohne Kategorie gäbe es kein Wort
                    onChanged: selected.contains(name) && selected.length == 1
                        ? null
                        : (value) => onCategory(name, value),
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
      ['Werwölfe: ', Strong('$effectiveWerewolfCount${werewolfCount == null ? ' (automatisch)' : ''}')],
      ['Sonderrollen: ', Strong(roles.isEmpty ? 'keine' : roles)],
      if (hostIsGameMaster == true) ['Die Spielleitung spielt nicht mit.'],
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
              AppCheck(value: gameMaster, onChanged: onGameMaster, label: 'Ich leite das Spiel und spiele nicht mit'),
              const Hint('Die Spielleitung sieht dann alle Rollen.'),
            ],
          ),
        SettingsGroup(
          children: [
            AppStepper(
              label: 'Werwölfe',
              value: form.effectiveWerewolfCount,
              min: 1,
              max: maxPlayers - 1,
              onStep: onCount,
            ),
            form.werewolfCount == null
                ? const Hint('Automatisch: 1 Werwolf pro 4 Spieler.')
                : Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton('Wieder automatisch', small: true, onPressed: onAuto),
                  ),
          ],
        ),
        SettingsGroup(
          children: [
            const Text('Sonderrollen', style: TextStyle(fontWeight: FontWeight.w700)),
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
            const Hint('Jede Rolle gibt es einmal. Alle übrigen Spieler sind Dorfbewohner.'),
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
  ['Sekunden pro Zug: ', Strong('$turnSeconds')],
  ['Punkte bis zum Sieg: ', Strong('$targetScore')],
  ['Teams: ', Strong('$teamCount'), ', ${autoTeams ? 'automatisch gemischt' : 'selbst gewählt'}'],
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
            label: 'Sekunden pro Zug',
            value: turnSeconds,
            min: Tabu.minTurnSeconds,
            max: Tabu.maxTurnSeconds,
            onStep: onTurnSeconds,
          ),
          AppStepper(
            label: 'Punkte bis zum Sieg',
            value: targetScore,
            min: Tabu.minTargetScore,
            max: Tabu.maxTargetScore,
            onStep: onTargetScore,
          ),
        ],
      ),
      SettingsGroup(
        children: [
          AppStepper(label: 'Teams', value: teamCount, min: Tabu.minTeams, max: Tabu.maxTeams, onStep: onTeamCount),
          AppCheck(value: autoTeams, onChanged: onAutoTeams, label: 'Teams automatisch mischen'),
          Hint(
            autoTeams
                ? 'Beim Start werden die Teams zufällig und gleich groß gemischt.'
                : 'Jeder wählt sein Team selbst.',
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
        label: 'Fragen',
        value: questionCount,
        min: NobodyIsPerfectRules.minQuestions,
        max: NobodyIsPerfectRules.maxQuestions,
        onStep: onCount,
      ),
      const Hint('Richtig getippt: 1 Punkt. Für jeden, der auf deine erfundene Antwort hereinfällt: 1 Punkt.'),
    ],
  );
}
