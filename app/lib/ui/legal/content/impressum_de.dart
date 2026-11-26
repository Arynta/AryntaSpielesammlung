// Impressum auf Deutsch. Diese Fassung ist maßgeblich.
import 'package:material_ui/material_ui.dart';

import '../widgets/legal_layout.dart';

/// [license] öffnet den Lizenztext einer Schrift.
List<Widget> impressumDe(BuildContext context, void Function(String name, String file) license) => [
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
];
