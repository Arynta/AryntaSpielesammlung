// Datenschutzerklärung.
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import 'legal_layout.dart';

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) => LegalScaffold(
    title: 'Datenschutz',
    children: [
      const Lead('Kurz gesagt: Wir speichern so wenig wie möglich und nichts davon dauerhaft.'),
      Builder(
        builder: (context) => LegalSection('Wer ist verantwortlich?', [
          LegalText([
            'Arynta\nE-Mail: ',
            mailLink(context),
            '\nWeitere Angaben stehen im ',
            LegalLink('Impressum', () => Navigator.of(context).pushNamed(impressumRoute)),
            '.',
          ]),
        ]),
      ),
      const LegalSection('Welche Daten fallen beim Spielen an?', [
        LegalBullets([
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
        LegalText([
          'Diese Daten liegen nur im Arbeitsspeicher des Servers, nicht in einer Datenbank. Sie werden '
              'gelöscht, sobald du den Raum verlässt, spätestens aber 6 Stunden nach der letzten Aktivität im '
              'Raum oder wenn der Server neu startet. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b DSGVO: Ohne diese '
              'Angaben kann das Spiel nicht laufen.',
        ]),
      ]),
      const LegalSection('Was wird auf deinem Gerät gespeichert?', [
        LegalText([
          'Im Speicher deines Browsers (localStorage) liegen dein Spielname und ein Zugangsschlüssel für den '
              'aktuellen Raum. Damit kommst du nach dem Neuladen oder Sperren des Handys wieder in denselben '
              'Raum. Das ist für die Funktion nötig und braucht deshalb keine Einwilligung '
              '(§ 25 Abs. 2 Nr. 2 TDDDG).',
        ]),
        LegalText([
          'Löschen kannst du das jederzeit über ',
          Strong('„Meine Daten löschen“'),
          ' unten auf der Startseite oder über die Einstellungen deines Browsers.',
        ]),
        LegalText([
          'Spielst du ',
          Strong('lokal'),
          ' mit einem Handy, bleiben die eingegebenen Namen und Einstellungen nur auf diesem Gerät. '
              'Sie werden nie an den Server geschickt.',
        ]),
        LegalText(['Es gibt ', Strong('keine Cookies'), ', keine Werbung, keine Analyse und kein Tracking.']),
      ]),
      const LegalSection('Hosting', [
        LegalText([
          'Damit die Seite erreichbar ist, nutzen wir externe Anbieter. Diese verarbeiten beim Aufruf '
              'technisch bedingt deine IP-Adresse sowie Datum, Uhrzeit und Browserkennung, unter anderem zum '
              'Schutz vor Angriffen:',
        ]),
        LegalBullets([
          [
            Strong('GitHub Pages'),
            ' (GitHub Inc., USA) und ',
            Strong('Cloudflare Pages'),
            ' (Cloudflare Inc., USA) liefern die Webseite aus.',
          ],
          [Strong('Render'), ' (Render Services Inc., USA) betreibt den Spielserver.'],
        ]),
        LegalText([
          'Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO. Unser berechtigtes Interesse ist, die Seite '
              'sicher und zuverlässig bereitzustellen. Da die Anbieter in den USA sitzen, können Daten dorthin '
              'übertragen werden. Die Übermittlung stützt sich auf das EU-US Data Privacy Framework oder die '
              'Standardvertragsklauseln der EU-Kommission, je nach Anbieter.',
        ]),
        LegalText([
          'Die Schriften werden direkt von dieser Seite geladen, nicht von Google oder einem anderen '
              'Drittanbieter.',
        ]),
      ]),
      Builder(
        builder: (context) => LegalSection('Deine Rechte', [
          const LegalText(['Du hast das Recht auf']),
          const LegalBullets([
            ['Auskunft über deine Daten (Art. 15 DSGVO),'],
            ['Berichtigung (Art. 16 DSGVO),'],
            ['Löschung (Art. 17 DSGVO),'],
            ['Einschränkung der Verarbeitung (Art. 18 DSGVO),'],
            ['Datenübertragbarkeit (Art. 20 DSGVO),'],
            ['Widerspruch gegen die Verarbeitung (Art. 21 DSGVO).'],
          ]),
          LegalText([
            'Schreib dafür einfach eine E-Mail an ',
            mailLink(context),
            '. Außerdem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel in '
                'dem Bundesland, in dem du wohnst.',
          ]),
        ]),
      ),
      const Hint('Stand: Oktober 2026'),
    ],
  );
}
