// Großer Titel des gewählten Spiels mit Text und Punkten für die Auswahl.
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/game_data.dart';
import '../../../../domain/models/models.dart';
import '../../themes/theme.dart';
import 'showcase_layout.dart';

/// Der große Bereich oben: Titel, Text und rechts das Bild des Spiels.
class GameHero extends StatelessWidget {
  const GameHero({
    super.key,
    required this.title,
    this.text,
    this.meta,
    this.game,
    this.count = 0,
    this.index = 0,
    this.child,
  });

  final String title;
  final String? text;
  final String? meta;

  /// Bestimmt das Bild rechts.
  final GameType? game;

  /// Punkte unten rechts: wie viele Spiele es gibt und welches gewählt ist.
  final int count;
  final int index;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final titleSize = (width * 0.075).clamp(44.0, 96.0);
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: width >= 700 ? 300 : 0),
          child: Stack(
            children: [
              // Auf schmalen Bildschirmen liegt der Text über dem Bild, deshalb blasser
              if (game != null && !gameHeroes.containsKey(game))
                Positioned.fill(
                  child: Opacity(opacity: width >= 700 ? 1 : 0.3, child: _HeroArt(game!)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: AnimatedSwitcher(
                    duration: context.motion(300),
                    layoutBuilder: (current, previous) =>
                        Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
                    child: Column(
                      key: ValueKey(title),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title.toUpperCase(),
                            style: display(titleSize, height: 1.05, color: p.accent, letterSpacing: titleSize * 0.12),
                          ),
                        ),
                        if (text != null) Text(text!, style: const TextStyle(fontSize: 17, color: Colors.white)),
                        if (meta != null) Text(meta!, style: TextStyle(fontSize: 15, color: p.muted)),
                        ?child,
                      ],
                    ),
                  ),
                ),
              ),
              if (count > 1)
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: _Dots(count: count, index: index),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt(this.game);

  final GameType game;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: context.motion(400),
        child: Align(
          key: ValueKey(game),
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, 0),
                  radius: 0.6,
                  colors: [gameTints[game]!.withValues(alpha: 0.5), gameTints[game]!.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      spacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: context.motion(250),
            width: i == index ? 28 : 14,
            height: 4,
            decoration: BoxDecoration(
              color: i == index ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}
