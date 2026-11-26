// Großes Bild hinter Kopfleiste und Titel.
import 'package:material_ui/material_ui.dart';

import '../../themes/theme.dart';
import 'showcase_layout.dart';

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
              child: fadeOut(
                key: ValueKey(image),
                Alignment.centerLeft,
                wide ? 0.5 : 0.2,
                fadeOut(
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
