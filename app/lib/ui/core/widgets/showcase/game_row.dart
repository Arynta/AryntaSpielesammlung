// Waagerechte Reihe der Spielkarten.
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/game_data.dart';
import '../../../../domain/models/models.dart';
import '../../themes/theme.dart';
import '../widgets.dart';
import 'showcase_layout.dart';

/// Waagerechte Reihe der Spiele. Ohne [onSelect] nur zum Ansehen.
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.games, required this.selected, this.onSelect, this.locked = const {}});

  final List<ShowcaseGame> games;
  final GameType selected;
  final ValueChanged<GameType>? onSelect;

  /// Spiele mit Schloss und „Bald verfügbar“, die man nicht wählen kann.
  final Set<GameType> locked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 600 ? 112.0 : 150.0;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          spacing: 14,
          children: [
            for (final game in games)
              _Poster(
                game,
                width: width,
                selected: game.type == selected,
                locked: locked.contains(game.type),
                onPressed: onSelect == null || locked.contains(game.type) ? null : () => onSelect!(game.type),
              ),
          ],
        ),
      );
    },
  );
}

class _Poster extends StatelessWidget {
  const _Poster(
    this.game, {
    required this.width,
    required this.selected,
    required this.locked,
    required this.onPressed,
  });

  final ShowcaseGame game;
  final double width;
  final bool selected;
  final bool locked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final image = gamePosters[game.type];
    final tint = gameTints[game.type]!;
    return Pressable(
      key: ValueKey(game.type),
      radius: 6,
      selected: selected,
      onPressed: onPressed,
      semanticLabel: locked ? '${game.name}, bald verfügbar' : '${game.name}, ab ${game.minPlayers} Spielern',
      child: AnimatedScale(
        scale: selected ? 1.06 : 1,
        duration: context.motion(200),
        child: AnimatedContainer(
          duration: context.motion(200),
          width: width,
          height: width * 1.5,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: selected ? 0.6 : 0.35), blurRadius: 16)],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(tint, Colors.white, 0.15)!, Color.lerp(tint, Colors.black, 0.6)!],
            ),
          ),
          foregroundDecoration: locked ? BoxDecoration(color: Colors.black.withValues(alpha: 0.35)) : null,
          child: locked
              ? _LockedLabel(name: game.name, width: width)
              : image != null
              ? Image.asset(image, fit: BoxFit.cover, alignment: Alignment.topCenter)
              : Padding(
                  padding: const EdgeInsets.all(10),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Text(
                      game.name,
                      textAlign: TextAlign.center,
                      style: display(
                        width / 6,
                        height: 1.05,
                        color: Colors.white,
                      ).copyWith(shadows: const [Shadow(blurRadius: 8)]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Schloss, Name und „Bald verfügbar“ auf einem gesperrten Spiel.
class _LockedLabel extends StatelessWidget {
  const _LockedLabel({required this.name, required this.width});

  final String name;
  final double width;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      spacing: 8,
      children: [
        const Spacer(),
        Icon(Icons.lock, color: Colors.white, size: width / 4),
        const Spacer(),
        Text(
          name,
          textAlign: TextAlign.center,
          style: display(width / 6, height: 1.05, color: Colors.white).copyWith(shadows: const [Shadow(blurRadius: 8)]),
        ),
        Text(
          'Bald verfügbar',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: width / 11),
        ),
      ],
    ),
  );
}
