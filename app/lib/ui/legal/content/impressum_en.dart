// Impressum auf Englisch, übersetzt aus impressum_de.dart. Maßgeblich ist die deutsche Fassung.
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../widgets/legal_layout.dart';

/// [license] öffnet den Lizenztext einer Schrift.
List<Widget> impressumEn(BuildContext context, void Function(String name, String file) license) => [
  const Hint('This translation is provided for convenience. The German version is legally binding.'),
  const LegalSection('Operator', [
    LegalText(['TEST Vorname Nachname\nTEST Straße und Hausnummer\nTEST Postleitzahl und Ort\nTEST Land']),
  ]),
  Builder(
    builder: (context) => LegalSection('Contact', [
      LegalText(['Email: ', mailLink(context)]),
    ]),
  ),
  const LegalSection('Note', [
    LegalText([
      'Arynta is a private, non-commercial game collection for game nights with friends. '
          'There are no ads, no accounts and nothing to buy.',
    ]),
  ]),
  LegalSection('Fonts and licences', [
    LegalBullets([
      [
        'Font “Atkinson Hyperlegible” by Braille Institute of America, ',
        LegalLink('SIL Open Font License 1.1', () => license('Atkinson Hyperlegible', 'atkinson-hyperlegible')),
      ],
      [
        'Font “Grenze” by The Grenze Project Authors, ',
        LegalLink('SIL Open Font License 1.1', () => license('Grenze', 'grenze')),
      ],
      ['Illustration (moon over a village): our own design'],
    ]),
  ]),
  LegalText([LegalLink('To the privacy policy', () => Navigator.of(context).pushNamed(datenschutzRoute))]),
];
