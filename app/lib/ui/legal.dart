// Impressum und Datenschutz. Der Text entspricht frontend/impressum.html und frontend/datenschutz.html,
// solange beide Seiten nebeneinander bestehen, Änderungen an beiden Stellen machen.
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../platform/device.dart' as device;
import 'theme.dart';
import 'widgets.dart';

const _mail = 'temp@test.com';

const impressumRoute = '/impressum';
const datenschutzRoute = '/datenschutz';

/// Gemeinsamer Rahmen beider Seiten.
class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: duskTheme,
    child: PageTitle(
      '$title · Arynta',
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: SelectionArea(
                  child: Gap(
                    spacing: 20,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Builder(
                          builder: (context) => LinkText(
                            'Zurück zum Spiel',
                            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          ),
                        ),
                      ),
                      ScreenTitle(title),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Gap(spacing: 12, children: [SectionTitle(title, size: 18.4), ...children]);
}

/// Ein Stück Text mit Link.
class _Link {
  const _Link(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
}

/// Absatz aus normalem Text, [Strong] und [_Link].
class _Text extends StatefulWidget {
  const _Text(this.parts);

  final List<Object> parts;

  @override
  State<_Text> createState() => _TextState();
}

class _TextState extends State<_Text> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final accent = context.palette.accent;
    return Text.rich(
      TextSpan(
        children: [
          for (final part in widget.parts)
            switch (part) {
              Strong(:final text) => TextSpan(
                text: text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _Link(:final text, :final onTap) => TextSpan(
                text: text,
                style: TextStyle(color: accent, decoration: TextDecoration.underline, decorationColor: accent),
                recognizer: _recognizers.addAndReturn(TapGestureRecognizer()..onTap = onTap),
                mouseCursor: SystemMouseCursors.click,
              ),
              _ => TextSpan(text: part as String),
            },
        ],
      ),
    );
  }
}

extension on List<TapGestureRecognizer> {
  TapGestureRecognizer addAndReturn(TapGestureRecognizer recognizer) {
    add(recognizer);
    return recognizer;
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<List<Object>> items;

  @override
  Widget build(BuildContext context) => Gap(
    spacing: 6,
    children: [
      for (final item in items)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 20, child: Text('•')),
            Expanded(child: _Text(item)),
          ],
        ),
    ],
  );
}

_Link _mailLink(BuildContext context) => _Link(_mail, () async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await device.writeMail(_mail)) {
    messenger.showSnackBar(const SnackBar(content: Text('E-Mail-Adresse kopiert')));
  }
});

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void license(String name, String file) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LicenseScreen(name: name, file: file),
      ),
    );
    return _LegalScaffold(
      title: 'Impressum',
      children: [
        const _Section('Angaben zum Betreiber', [
          _Text(['TEST Vorname Nachname\nTEST Straße und Hausnummer\nTEST Postleitzahl und Ort\nTEST Land']),
        ]),
        Builder(
          builder: (context) => _Section('Kontakt', [
            _Text(['E-Mail: ', _mailLink(context)]),
          ]),
        ),
        const _Section('Hinweis', [
          _Text([
            'Arynta ist eine private, nicht kommerzielle Spielesammlung für Spieleabende mit Freunden. '
                'Es gibt keine Werbung, keine Konten und nichts zu kaufen.',
          ]),
        ]),
        _Section('Schriften und Lizenzen', [
          _Bullets([
            [
              'Schrift „Atkinson Hyperlegible“ von Braille Institute of America, ',
              _Link('SIL Open Font License 1.1', () => license('Atkinson Hyperlegible', 'atkinson-hyperlegible')),
            ],
            [
              'Schrift „Grenze“ von The Grenze Project Authors, ',
              _Link('SIL Open Font License 1.1', () => license('Grenze', 'grenze')),
            ],
            ['Symbolbild (Mond über Dorf): eigene Gestaltung'],
          ]),
        ]),
        _Text([_Link('Zur Datenschutzerklärung', () => Navigator.of(context).pushNamed(datenschutzRoute))]),
      ],
    );
  }
}

class _LicenseScreen extends StatelessWidget {
  const _LicenseScreen({required this.name, required this.file});

  final String name;
  final String file;

  @override
  Widget build(BuildContext context) => _LegalScaffold(
    title: name,
    children: [
      FutureBuilder(
        future: rootBundle.loadString('assets/fonts/$file-OFL.txt'),
        builder: (context, snapshot) => Text(snapshot.data ?? '', style: const TextStyle(fontSize: 14.4)),
      ),
    ],
  );
}

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) => _LegalScaffold(
    title: 'Datenschutz',
    children: [
      const Lead('Kurz gesagt: Wir speichern so wenig wie möglich und nichts davon dauerhaft.'),
      Builder(
        builder: (context) => _Section('Wer ist verantwortlich?', [
          _Text([
            'Arynta\nE-Mail: ',
            _mailLink(context),
            '\nWeitere Angaben stehen im ',
            _Link('Impressum', () => Navigator.of(context).pushNamed(impressumRoute)),
            '.',
          ]),
        ]),
      ),
      const _Section('Welche Daten fallen beim Spielen an?', [
        _Bullets([
          [
            Strong('Dein Spielname.'),
            ' Du gibst ihn selbst ein, damit die anderen im Raum sehen, wer mitspielt. '
                'Ein Spitzname reicht, dein echter Name ist nicht nötig.',
          ],
          [
            Strong('Raumcode und Rolle.'),
            ' Der Server merkt sich, in welchem Raum du bist und welche Rolle du im Spiel hast.',
          ],
        ]),
        _Text([
          'Diese Daten liegen nur im Arbeitsspeicher des Servers, nicht in einer Datenbank. Sie werden '
              'gelöscht, sobald du den Raum verlässt, spätestens aber 6 Stunden nach der letzten Aktivität im '
              'Raum oder wenn der Server neu startet. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO: Ohne diese '
              'Angaben kann das Spiel nicht laufen.',
        ]),
      ]),
      const _Section('Was wird auf deinem Gerät gespeichert?', [
        _Text([
          'Im Speicher deines Browsers (localStorage) liegen dein Spielname und ein Zugangsschlüssel für den '
              'aktuellen Raum. Damit kommst du nach dem Neuladen oder Sperren des Handys wieder in denselben '
              'Raum. Das ist für die Funktion nötig und braucht deshalb keine Einwilligung '
              '(§ 25 Abs. 2 Nr. 2 TDDDG).',
        ]),
        _Text([
          'Löschen kannst du das jederzeit über ',
          Strong('„Meine Daten löschen“'),
          ' unten auf der Startseite oder über die Einstellungen deines Browsers.',
        ]),
        _Text([
          'Spielst du ',
          Strong('lokal'),
          ' mit einem Handy, bleiben die eingegebenen Namen und Einstellungen nur auf diesem Gerät. '
              'Sie werden nie an den Server geschickt.',
        ]),
        _Text(['Es gibt ', Strong('keine Cookies'), ', keine Werbung, keine Analyse und kein Tracking.']),
      ]),
      const _Section('Hosting', [
        _Text([
          'Damit die Seite erreichbar ist, nutzen wir externe Anbieter. Diese verarbeiten beim Aufruf '
              'technisch bedingt deine IP-Adresse sowie Datum, Uhrzeit und Browserkennung, unter anderem zum '
              'Schutz vor Angriffen:',
        ]),
        _Bullets([
          [
            Strong('GitHub Pages'),
            ' (GitHub Inc., USA) und ',
            Strong('Cloudflare Pages'),
            ' (Cloudflare Inc., USA) liefern die Webseite aus.',
          ],
          [Strong('Render'), ' (Render Services Inc., USA) betreibt den Spielserver.'],
        ]),
        _Text([
          'Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO. Unser berechtigtes Interesse ist, die Seite '
              'sicher und zuverlässig bereitzustellen. Da die Anbieter in den USA sitzen, können Daten dorthin '
              'übertragen werden. Die Übermittlung stützt sich auf das EU-US Data Privacy Framework oder die '
              'Standardvertragsklauseln der EU-Kommission, je nach Anbieter.',
        ]),
        _Text([
          'Die Schriften werden direkt von dieser Seite geladen, nicht von Google oder einem anderen '
              'Drittanbieter.',
        ]),
      ]),
      Builder(
        builder: (context) => _Section('Deine Rechte', [
          const _Text(['Du hast das Recht auf']),
          const _Bullets([
            ['Auskunft über deine Daten (Art. 15 DSGVO),'],
            ['Berichtigung (Art. 16 DSGVO),'],
            ['Löschung (Art. 17 DSGVO),'],
            ['Einschränkung der Verarbeitung (Art. 18 DSGVO),'],
            ['Datenübertragbarkeit (Art. 20 DSGVO),'],
            ['Widerspruch gegen die Verarbeitung (Art. 21 DSGVO).'],
          ]),
          _Text([
            'Schreib dafür einfach eine E-Mail an ',
            _mailLink(context),
            '. Außerdem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel in '
                'dem Bundesland, in dem du wohnst.',
          ]),
        ]),
      ),
      const Hint('Stand: Oktober 2026'),
    ],
  );
}
