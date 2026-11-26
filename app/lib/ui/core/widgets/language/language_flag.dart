// Sprachumschalter: zeigt die Flagge der aktuellen Sprache, ein Tipp wechselt zur anderen.
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../view_model/app_controller.dart';
import '../widgets.dart';
import 'flag_painter.dart';

class LanguageFlag extends StatelessWidget {
  const LanguageFlag(this.controller, {super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final language = controller.language.value;
    return Pressable(
      key: const ValueKey('language'),
      radius: 4,
      onPressed: controller.toggleLanguage,
      semanticLabel: texts.languageSwitch,
      // 48 × 48 Tippfläche, die Flagge selbst ist kleiner
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 36,
            height: 22,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white38),
            ),
            child: CustomPaint(painter: FlagPainter(language)),
          ),
        ),
      ),
    );
  }
}
