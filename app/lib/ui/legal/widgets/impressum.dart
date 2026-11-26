// Impressum und Lizenzen.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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
      title: 'Impressum',
      children: [
        const LegalSection('Angaben zum Betreiber', [
          LegalText(['TEST Vorname Nachname\nTEST Straße und Hausnummer\nTEST Postleitzahl und Ort\nTEST Land']),
        ]),
        Builder(
          builder: (context) => LegalSection('Kontakt', [
            LegalText(['E-Mail: ', mailLink(context)]),
          ]),
        ),
        const LegalSection('Hinweis', [
          LegalText([
            'Arynta ist eine private, nicht kommerzielle Spielesammlung für Spieleabende mit Freunden. '
                'Es gibt keine Werbung, keine Konten und nichts zu kaufen.',
          ]),
        ]),
        LegalSection('Schriften und Lizenzen', [
          LegalBullets([
            [
              'Schrift „Atkinson Hyperlegible“ von Braille Institute of America, ',
              LegalLink('SIL Open Font License 1.1', () => license('Atkinson Hyperlegible', 'atkinson-hyperlegible')),
            ],
            [
              'Schrift „Grenze“ von The Grenze Project Authors, ',
              LegalLink('SIL Open Font License 1.1', () => license('Grenze', 'grenze')),
            ],
            ['Symbolbild (Mond über Dorf): eigene Gestaltung'],
          ]),
        ]),
        LegalText([LegalLink('Zur Datenschutzerklärung', () => Navigator.of(context).pushNamed(datenschutzRoute))]),
      ],
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
