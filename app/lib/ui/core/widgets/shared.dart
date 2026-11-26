// Bausteine, die online (Lobby) und lokal (ein Handy) gleich aussehen.
// Was beim Ändern passiert, entscheidet der Aufrufer: an den Server schicken oder lokal merken.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../../../domain/models/models.dart';
import '../themes/theme.dart';
import 'widgets.dart';

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

// ---- Impostor --------------------------------------------------------------

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

// ---- Werwolf ---------------------------------------------------------------

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

// ---- Tabu ------------------------------------------------------------------

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

/// Die Karte mit Begriff und verbotenen Wörtern.
class ForbiddenCard extends StatelessWidget {
  const ForbiddenCard(this.card, {super.key});

  final TabuCard card;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF2A1D07);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EA),
        border: Border.all(color: context.palette.accent, width: 3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            card.word,
            textAlign: TextAlign.center,
            style: display(40, height: 1.05, color: ink),
          ),
          Text(
            'NICHT SAGEN:',
            semanticsLabel: 'Nicht sagen:',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFA12A1C),
              fontWeight: FontWeight.w700,
              fontSize: 13.6,
              letterSpacing: 1.1,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final word in card.forbidden)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE3D6B8))),
                  ),
                  child: Text(
                    word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uhr, die jede Viertelsekunde weiterzählt.
class Countdown extends StatefulWidget {
  const Countdown(this.deadline, {super.key});

  final DateTime deadline;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late final Timer _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer; // startet die Uhr
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final seconds = math.max(0, (widget.deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil());
    final low = seconds <= 10;
    return Semantics(
      label: 'Restzeit in Sekunden',
      child: Container(
        constraints: const BoxConstraints(minWidth: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: low ? teamColors[0] : p.line, width: 2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$seconds',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: low ? const Color(0xFFFF8A7A) : p.text,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Kasten mit farbigem Streifen links in der Teamfarbe.
class TeamStripe extends StatelessWidget {
  const TeamStripe({super.key, required this.team, required this.child, this.radius = 10, this.padding});

  final int team;
  final Widget child;
  final double radius;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(left: BorderSide(color: teamColors[team % teamColors.length], width: 6)),
      ),
      child: child,
    ),
  );
}

class Scoreboard extends StatelessWidget {
  const Scoreboard({super.key, required this.teams, required this.currentTeam, required this.targetScore});

  final List<({String name, int score})> teams;
  final int currentTeam;
  final int targetScore;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Punktestand',
    child: Gap(
      spacing: 6,
      children: [
        AutoGrid(
          minWidth: 120,
          fit: true,
          children: [
            for (var i = 0; i < teams.length; i++)
              DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  border: i == currentTeam ? Border.all(color: context.palette.accent, width: 2) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TeamStripe(
                  team: i,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(child: Text(teams[i].name)),
                      Text('${teams[i].score}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Hint('Gewonnen hat, wer zuerst $targetScore Punkte hat.'),
      ],
    ),
  );
}

class TurnResults extends StatelessWidget {
  const TurnResults({super.key, required this.title, required this.results, required this.teamNames});

  final String title;
  final List<CardResult> results;
  final List<String> teamNames;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Gap(
      spacing: 0,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionTitle(title)),
        for (final r in results)
          NameLine(
            name: r.word,
            note: Text.rich(
              TextSpan(
                children: [
                  if (r.outcome != CardOutcome.skipped)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        r.outcome == CardOutcome.correct ? Icons.check : Icons.close,
                        size: 16,
                        color: context.palette.muted,
                      ),
                    ),
                  TextSpan(
                    text: switch (r.outcome) {
                      CardOutcome.correct => ' richtig',
                      CardOutcome.skipped => 'übersprungen',
                      CardOutcome.buzzed => ' verboten',
                    },
                  ),
                  if (r.scoringTeam case final team?) TextSpan(text: ' · +1 ${teamNames[team]}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Nobody is Perfect -----------------------------------------------------

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

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question, required this.number, required this.count});

  final String question;
  final int number;
  final int count;

  @override
  Widget build(BuildContext context) => Panel(
    borderColor: context.palette.accent,
    padding: const EdgeInsets.all(20),
    child: Gap(
      spacing: 6,
      children: [
        Text('Frage $number von $count', style: TextStyle(color: context.palette.muted, fontSize: 14.4)),
        Text(question, style: const TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

/// Großer Kasten mit dem gesuchten Wort oder der echten Antwort.
class ResultWord extends StatelessWidget {
  const ResultWord({super.key, required this.intro, required this.word, this.category, this.size = 40});

  final String intro;
  final String word;
  final String? category;
  final double size;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(intro),
        Text.rich(
          TextSpan(
            text: word,
            style: display(size, height: 1.15, color: context.palette.accent),
            children: [
              if (category != null)
                TextSpan(
                  text: '  ($category)',
                  style: TextStyle(
                    fontFamily: bodyFont,
                    fontFamilyFallback: bodyFallback,
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: context.palette.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Auswählbare Zeile beim Abstimmen und Tippen.
class VoteOption extends StatelessWidget {
  const VoteOption({super.key, required this.selected, required this.onPressed, required this.builder});

  final bool selected;
  final VoidCallback? onPressed;
  final Widget Function(Color foreground, Color note) builder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final foreground = selected ? p.onAccent : p.text;
    return Opacity(
      opacity: onPressed == null ? 0.55 : 1,
      child: Pressable(
        selected: selected,
        onPressed: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: selected ? p.accent : p.surface,
            border: Border.all(color: selected ? p.accent : p.line, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: builder(foreground, selected ? p.onAccent : p.muted),
          ),
        ),
      ),
    );
  }
}

class ChoiceLetter extends StatelessWidget {
  const ChoiceLetter(this.letter, {super.key, required this.color});

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 2),
    ),
    child: Text(
      letter,
      style: TextStyle(color: color, fontWeight: FontWeight.w700),
    ),
  );
}

/// Antworten zum Tippen. Die eigene Erfindung ist gesperrt.
class ChoiceList extends StatelessWidget {
  const ChoiceList({
    super.key,
    required this.choices,
    required this.ownId,
    required this.chosenId,
    required this.onChoose,
  });

  final List<({String id, String text})> choices;
  final String? ownId;
  final String? chosenId;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => Gap(
    spacing: 8,
    children: [
      for (final c in choices)
        VoteOption(
          key: ValueKey(c.id),
          selected: c.id == chosenId,
          onPressed: c.id == ownId ? null : () => onChoose(c.id),
          builder: (foreground, note) => Row(
            spacing: 16,
            children: [
              ChoiceLetter(c.id, color: foreground),
              Expanded(child: Text(c.text)),
              if (c.id == ownId) Text('deine', style: TextStyle(color: note, fontSize: 14.4)),
            ],
          ),
        ),
    ],
  );
}

class RevealRow {
  const RevealRow({
    required this.id,
    required this.text,
    required this.correct,
    required this.author,
    required this.guessers,
  });
  final String id;
  final String text;
  final bool correct;

  /// null bei der echten Antwort.
  final String? author;
  final List<String> guessers;
}

/// Auflösung: echte Antwort zuerst, dann die Erfindungen nach Anzahl der Reingefallenen.
List<RevealRow> sortReveal(List<RevealRow> rows) => _stableSort(rows, (a, b) {
  if (a.correct != b.correct) return a.correct ? -1 : 1;
  return b.guessers.length - a.guessers.length;
});

/// Wie sort(), behält aber bei Gleichstand die ursprüngliche Reihenfolge.
List<T> _stableSort<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = items.indexed.toList()
    ..sort((a, b) {
      final result = compare(a.$2, b.$2);
      return result != 0 ? result : a.$1 - b.$1;
    });
  return [for (final entry in indexed) entry.$2];
}

class RevealList extends StatelessWidget {
  const RevealList(this.rows, {super.key});

  final List<RevealRow> rows;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Gap(
      spacing: 0,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: SectionTitle('Auflösung')),
        for (final r in sortReveal(rows))
          ListLine(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                ChoiceLetter(r.id, color: r.correct ? p.accent : p.text),
                Expanded(
                  child: Gap(
                    spacing: 3,
                    children: [
                      Text(
                        r.text,
                        style: r.correct ? TextStyle(color: p.accent, fontWeight: FontWeight.w700) : null,
                      ),
                      Text(
                        '${r.correct ? 'Die echte Antwort' : 'Erfunden von ${r.author ?? '?'}'} · '
                        '${r.guessers.isEmpty ? 'Niemand hat darauf getippt' : 'Getippt: ${r.guessers.join(', ')}'}',
                        style: TextStyle(color: p.muted, fontSize: 14.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Punktestand, Bester oben. `gained`: Punkte für die letzte Frage.
class PointTable extends StatelessWidget {
  const PointTable(this.rows, {super.key, this.title = 'Punkte'});

  final List<({String name, int score, int gained})> rows;
  final String title;

  @override
  Widget build(BuildContext context) => Gap(
    spacing: 0,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionTitle(title)),
      for (final r in _stableSort(rows, (a, b) => b.score - a.score))
        NameLine(
          name: r.name,
          note: Text.rich(
            TextSpan(
              text: r.gained > 0 ? '+${r.gained} · ' : '',
              children: [
                TextSpan(
                  text: '${r.score}',
                  style: TextStyle(color: context.palette.text, fontSize: 17.6, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

// ---- Karten ----------------------------------------------------------------

/// Kartenfarbe nach Team bzw. Impostor-Rolle.
enum CardTone {
  wolves(Color(0xFF7D2424), Color(0xFFA63A3A)),
  village(Color(0xFF355A37), Color(0xFF4F7D51)),
  neutral(Color(0xFF4A3D8C), Color(0xFF6D5FB8));

  const CardTone(this.fill, this.border);
  final Color fill;
  final Color border;

  static CardTone forTeam(String team) => switch (team) {
    'WOELFE' => wolves,
    'DORF' => village,
    _ => neutral,
  };
}

/// Die Kartenfläche. Ohne [tone] ist sie verdeckt.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.tone, required this.child});

  final CardTone? tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = tone;
    final face = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: open?.fill ?? p.surface,
        border: open == null ? null : Border.all(color: open.border, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DefaultTextStyle.merge(
        textAlign: TextAlign.center,
        style: TextStyle(color: open == null ? p.text : Colors.white),
        child: child,
      ),
    );
    if (open != null) return face;
    return CustomPaint(
      foregroundPainter: DashedBorder(color: p.line, radius: 18, width: 2),
      child: face,
    );
  }
}

Widget _cardText(String text, {bool bold = false}) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 290),
  child: Text(text, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
);

class RoleCardContent extends StatelessWidget {
  const RoleCardContent({super.key, required this.role, required this.knownWolves, required this.leftoverRoles});

  final RoleCard role;
  final List<String> knownWolves;
  final List<String> leftoverRoles;

  @override
  Widget build(BuildContext context) {
    final data = gameData.roleById(role.id);
    final String? wolves;
    if (data.seesWolfPack) {
      wolves = knownWolves.isEmpty
          ? 'Es gibt keine Werwölfe, die du kennst.'
          : 'Die Werwölfe: ${knownWolves.join(', ')}';
    } else if (data.wolfPack) {
      wolves = knownWolves.isEmpty ? 'Du jagst allein.' : 'Mit dir jagen: ${knownWolves.join(', ')}';
    } else {
      wolves = null;
    }
    final image = roleImages[role.id];
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (image != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              // Die Karte ist quadratisch-unabhängig, die Höhe ergibt sich aus der Breite
              child: Image.asset(image, semanticLabel: role.name, fit: BoxFit.fitWidth),
            ),
          )
        else ...[
          Text(
            role.teamName.toUpperCase(),
            semanticsLabel: role.teamName,
            style: const TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          Text(role.name, style: display(48)),
        ],
        _cardText(role.description),
        if (wolves != null) _cardText(wolves, bold: true),
        if (leftoverRoles.isNotEmpty) _cardText('Übrige Karten: ${leftoverRoles.join(' und ')}', bold: true),
      ],
    );
  }
}

class ImpostorCardContent extends StatelessWidget {
  const ImpostorCardContent({
    super.key,
    required this.isImpostor,
    required this.word,
    required this.category,
    required this.fellowImpostors,
  });

  final bool isImpostor;
  final String? word;
  final String? category;
  final List<String> fellowImpostors;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Text(isImpostor ? 'Impostor' : word ?? '', style: display(48)),
      if (category != null)
        isImpostor ? RichLine(['Kategorie: ', Strong(category!)]) : _cardText('Kategorie: $category')
      else if (isImpostor)
        _cardText('Du kennst das Wort nicht. Hör gut zu und bluffe.'),
      if (isImpostor && fellowImpostors.isNotEmpty) _cardText('Mit dir: ${fellowImpostors.join(', ')}', bold: true),
    ],
  );
}

/// Karte, die ihren Inhalt nur zeigt, solange man sie gedrückt hält.
class SecretCard extends StatefulWidget {
  const SecretCard({super.key, required this.tone, required this.what, required this.content});

  final CardTone tone;

  /// Satzende für den Hinweis, z. B. „um dein Wort zu sehen“.
  final String what;
  final Widget content;

  @override
  State<SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<SecretCard> {
  bool _revealing = false;
  bool _focused = false;

  /// Verdeckt die Karte auch, wenn das Fenster den Fokus verliert.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onInactive: () => _set(false));

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bilder vorab laden, damit sie beim Aufdecken sofort da sind
    for (final image in roleImages.values) {
      precacheImage(AssetImage(image), context);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _set(bool revealing) {
    if (mounted && _revealing != revealing) setState(() => _revealing = revealing);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _set(true);
    if (event is KeyUpEvent) _set(false);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _onKey,
    onFocusChange: (focused) {
      if (!focused) _set(false);
      setState(() => _focused = focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional);
    },
    child: Semantics(
      button: true,
      label: _revealing ? null : 'Gedrückt halten, ${widget.what}',
      excludeSemantics: !_revealing,
      child: Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        // Hält die Geste fest, damit die Seite unter dem Finger nicht wegscrollt
        child: GestureDetector(
          onVerticalDragStart: (_) {},
          onLongPress: () {},
          onLongPressEnd: (_) => _set(false),
          excludeFromSemantics: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: FocusRing(
              show: _focused,
              radius: 18,
              child: CardFace(
                tone: _revealing ? widget.tone : null,
                child: _revealing
                    ? widget.content
                    : Text(
                        'Gedrückt halten,\n${widget.what}',
                        style: TextStyle(color: context.palette.muted, fontSize: 17.6),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Liste „Name – Rolle“ für die Spielleitung.
class RoleOverview extends StatelessWidget {
  const RoleOverview({super.key, required this.rows, required this.leftoverRoles});

  final List<({String name, RoleCard role})> rows;
  final List<String> leftoverRoles;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Gap(
      spacing: 0,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 8), child: SectionTitle('Alle Rollen')),
        for (final row in rows)
          NameLine(
            name: row.name,
            noteColor: switch (CardTone.forTeam(row.role.team)) {
              CardTone.wolves => p.wolfNote,
              CardTone.village => p.villageNote,
              CardTone.neutral => p.neutralNote,
            },
            note: Text('${row.role.name} · ${row.role.teamName}'),
          ),
        if (leftoverRoles.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Hint('Übrige Karten: ${leftoverRoles.join(' und ')}')),
      ],
    );
  }
}
