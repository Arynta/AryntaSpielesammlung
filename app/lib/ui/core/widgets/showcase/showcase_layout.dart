// Gemeinsames der TV-Oberfläche: Hintergrund, Farben der Spiele, Auslaufen der Bilder, Lesebreite.
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/models.dart';
import '../widgets.dart';

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
const gameTints = {
  GameType.werwolf: Color(0xFF7A1622),
  GameType.impostor: Color(0xFF2B3F7A),
  GameType.tabu: Color(0xFFA6561C),
  GameType.nobodyIsPerfect: Color(0xFF1F6B57),
  GameType.buzzer: Color(0xFF7A2468),
};

/// Lässt das Bild ab [from] auf dem Anteil [share] ins Dunkle auslaufen, damit Titel und Spielereihe lesbar bleiben.
/// Mit [both] auch auf der Gegenseite.
Widget fadeOut(Alignment from, double share, Widget child, {bool both = false, Key? key}) => ShaderMask(
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
