// Impressum und Lizenzen. Die Texte stehen je Sprache in ../content/.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../content/impressum_de.dart';
import '../content/impressum_en.dart';
import 'legal_layout.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void license(String name, String file) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicenseScreen(name: name, file: file),
      ),
    );
    return LegalScaffold(
      title: texts.footerImprint,
      children: appLanguage == Language.en ? impressumEn(context, license) : impressumDe(context, license),
    );
  }
}

class _LicenseScreen extends StatelessWidget {
  const _LicenseScreen({required this.name, required this.file});

  final String name;
  final String file;

  @override
  Widget build(BuildContext context) => LegalScaffold(
    title: name,
    children: [
      FutureBuilder(
        future: rootBundle.loadString('assets/fonts/$file-OFL.txt'),
        builder: (context, snapshot) => Text(snapshot.data ?? '', style: const TextStyle(fontSize: 14.4)),
      ),
    ],
  );
}
