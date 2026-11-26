// Datenschutzerklärung. Die Texte stehen je Sprache in ../content/.
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../content/datenschutz_de.dart';
import '../content/datenschutz_en.dart';
import 'legal_layout.dart';

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) => LegalScaffold(
    title: texts.footerPrivacy,
    children: appLanguage == Language.en ? datenschutzEn() : datenschutzDe(),
  );
}
