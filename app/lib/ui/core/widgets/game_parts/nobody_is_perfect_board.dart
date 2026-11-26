// Nobody is Perfect: Frage, Antworten zum Tippen, Auflösung und Punkte.
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../themes/theme.dart';
import '../widgets.dart';

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
        Text(texts.questionOf(number, count), style: TextStyle(color: context.palette.muted, fontSize: 14.4)),
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
              if (c.id == ownId) Text(texts.yours, style: TextStyle(color: note, fontSize: 14.4)),
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
        Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionTitle(texts.reveal)),
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
                        '${r.correct ? texts.theRealAnswer : texts.madeUpBy(r.author ?? '?')} · '
                        '${r.guessers.isEmpty ? texts.nobodyPicked : texts.pickedBy(r.guessers.join(', '))}',
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
  const PointTable(this.rows, {super.key, this.title});

  final List<({String name, int score, int gained})> rows;
  final String? title;

  @override
  Widget build(BuildContext context) => Gap(
    spacing: 0,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionTitle(title ?? texts.points)),
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
