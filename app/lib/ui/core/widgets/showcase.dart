// Startseite im Stil einer TV-Oberfläche: Kopfleiste mit Tabs, großes Spiel oben, Spielereihe darunter.
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../../../domain/models/models.dart';
import '../themes/theme.dart';
import 'widgets.dart';

typedef ShowcaseGame = ({GameType type, String name, String description, int minPlayers});

const showcaseBackground = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0.5, -0.8),
    radius: 1.4,
    colors: [Color(0xFF6E1A1F), Color(0xFF3B0F12), Color(0xFF140A0B)],
    stops: [0, 0.5, 1],
  ),
);

/// Grundfarbe der Platzhalter, solange ein Spiel noch kein Bild hat.
const _tints = {
  GameType.werwolf: Color(0xFF7A1622),
  GameType.impostor: Color(0xFF2B3F7A),
  GameType.tabu: Color(0xFFA6561C),
  GameType.nobodyIsPerfect: Color(0xFF1F6B57),
  GameType.buzzer: Color(0xFF7A2468),
};

class ShowcaseBar extends StatelessWidget {
  const ShowcaseBar({super.key, required this.online, this.tabs = const [], this.selectedTab = 0, this.onTab});

  final bool online;
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTab;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: 8,
        children: [
          if (constraints.maxWidth >= 420)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text('Arynta', style: display(22, color: p.muted, letterSpacing: 1)),
            ),
          for (final (index, label) in tabs.indexed)
            _TabPill(label, selected: index == selectedTab, onPressed: () => onTab?.call(index)),
          const Spacer(),
          Icon(
            online ? Icons.wifi : Icons.wifi_off,
            color: online ? const Color(0xFF3DDC84) : p.muted,
            size: 24,
            semanticLabel: online ? 'Mit dem Server verbunden' : 'Keine Verbindung zum Server',
          ),
          if (constraints.maxWidth >= 560) const Padding(padding: EdgeInsets.only(left: 12), child: _Clock()),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill(this.label, {required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    radius: 20,
    selected: selected,
    onPressed: selected ? null : onPressed,
    child: AnimatedContainer(
      duration: context.motion(200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: selected ? Colors.black : Colors.white),
      ),
    ),
  );
}

class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return ExcludeSemantics(
      child: Text('${two(now.hour)}:${two(now.minute)}', style: const TextStyle(fontSize: 22, color: Colors.white)),
    );
  }
}

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
                  colors: [_tints[game]!.withValues(alpha: 0.5), _tints[game]!.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lässt das Bild ab [from] auf dem Anteil [share] ins Dunkle auslaufen, damit Titel und Spielereihe lesbar bleiben.
/// Mit [both] auch auf der Gegenseite.
Widget _fade(Alignment from, double share, Widget child, {bool both = false, Key? key}) => ShaderMask(
  key: key,
  blendMode: BlendMode.dstIn,
  shaderCallback: (rect) => LinearGradient(
    begin: from,
    end: -from,
    colors: [Colors.transparent, Colors.white, Colors.white, if (both) Colors.transparent else Colors.white],
    stops: [0, share, 1 - share, 1],
  ).createShader(rect),
  child: child,
);

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

/// Waagerechte Reihe der Spiele. Ohne [onSelect] nur zum Ansehen.
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.games, required this.selected, this.onSelect});

  final List<ShowcaseGame> games;
  final GameType selected;
  final ValueChanged<GameType>? onSelect;

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
                onPressed: onSelect == null ? null : () => onSelect!(game.type),
              ),
          ],
        ),
      );
    },
  );
}

class _Poster extends StatelessWidget {
  const _Poster(this.game, {required this.width, required this.selected, required this.onPressed});

  final ShowcaseGame game;
  final double width;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final image = gamePosters[game.type];
    final tint = _tints[game.type]!;
    return Pressable(
      key: ValueKey(game.type),
      radius: 6,
      selected: selected,
      onPressed: onPressed,
      semanticLabel: '${game.name}, ab ${game.minPlayers} Spielern',
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
          child: image != null
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

/// Inhalt unter der Spielereihe in Lesebreite.
class Narrow extends StatelessWidget {
  const Narrow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Gap(spacing: 20, children: children),
    ),
  );
}

/// Großes Bild hinter Kopfleiste und Startbereich, randlos bis an den rechten und oberen Rand.
/// Läuft nach links und unten in den Hintergrund aus. Auf schmalen Bildschirmen liegt es blass hinter dem Text.
class ShowcaseBackdrop extends StatelessWidget {
  const ShowcaseBackdrop(this.image, {super.key});

  final String image;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 700;
    return Positioned(
      top: 0,
      right: 0,
      width: wide ? size.width * 0.68 : size.width,
      height: wide ? (size.height * 0.85).clamp(420.0, 900.0) : 420,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: wide ? 1 : 0.3,
            child: AnimatedSwitcher(
              duration: context.motion(400),
              // Ohne StackFit.expand bekäme das Bild nur seine eigene Größe und säße klein in der Mitte
              layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
              child: _fade(
                key: ValueKey(image),
                Alignment.centerLeft,
                wide ? 0.5 : 0.2,
                _fade(
                  Alignment.bottomCenter,
                  0.4,
                  Image.asset(image, fit: BoxFit.cover, alignment: const Alignment(0.4, -0.6)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
