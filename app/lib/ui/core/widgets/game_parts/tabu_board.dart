// Tabu: Karte, Uhr, Teams und Punktestand.
import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/models.dart';
import '../../themes/theme.dart';
import '../widgets.dart';

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
