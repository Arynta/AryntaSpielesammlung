// Datenschutzerklärung auf Englisch, übersetzt aus datenschutz_de.dart. Maßgeblich ist die deutsche Fassung.
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/widgets.dart';
import '../widgets/legal_layout.dart';

List<Widget> datenschutzEn() => [
  const Hint('This translation is provided for convenience. The German version is legally binding.'),
  const Lead('In short: we store as little as possible and none of it permanently.'),
  Builder(
    builder: (context) => LegalSection('Who is responsible?', [
      LegalText([
        'Arynta\nEmail: ',
        mailLink(context),
        '\nFurther details are in the ',
        LegalLink('legal notice', () => Navigator.of(context).pushNamed(impressumRoute)),
        '.',
      ]),
    ]),
  ),
  const LegalSection('What data is processed while playing?', [
    LegalBullets([
      [
        Strong('Your player name.'),
        ' You enter it yourself so the others in the room can see who is playing. '
            'A nickname is enough, your real name is not needed.',
      ],
      [
        Strong('Room code and role.'),
        ' The server remembers which room you are in and which role you have in the game.',
      ],
      [
        Strong('Language.'),
        ' The server remembers whether you see the site in German or English, so that hints reach you in '
            'your language.',
      ],
    ]),
    LegalText([
      'This data is kept only in the server’s memory, not in a database. It is deleted as soon as you '
          'leave the room, at the latest 6 hours after the last activity in the room or when the server '
          'restarts. The legal basis is Art. 6(1)(b) GDPR: the game cannot run without this information.',
    ]),
  ]),
  const LegalSection('What is stored on your device?', [
    LegalText([
      'Your browser’s storage (localStorage) holds your player name, an access key for the current room '
          'and the language you chose. This lets you get back into the same room after reloading or locking '
          'your phone, and keeps the site in your language. This is necessary for the site to work and '
          'therefore needs no consent (Section 25(2) No. 2 TDDDG).',
    ]),
    LegalText([
      'You can delete it at any time via ',
      Strong('“Delete my data”'),
      ' at the bottom of the start page or in your browser settings.',
    ]),
    LegalText([
      'If you play ',
      Strong('locally'),
      ' on one phone, the names and settings you enter stay on that device only. '
          'They are never sent to the server.',
    ]),
    LegalText(['There are ', Strong('no cookies'), ', no ads, no analytics and no tracking.']),
  ]),
  const LegalSection('Hosting', [
    LegalText([
      'To make the site available, we use external providers. When you visit, they necessarily process '
          'your IP address as well as the date, time and browser identifier, among other things to protect '
          'against attacks:',
    ]),
    LegalBullets([
      [
        Strong('GitHub Pages'),
        ' (GitHub Inc., USA) and ',
        Strong('Cloudflare Pages'),
        ' (Cloudflare Inc., USA) deliver the website.',
      ],
      [Strong('Render'), ' (Render Services Inc., USA) runs the game server.'],
    ]),
    LegalText([
      'The legal basis is Art. 6(1)(f) GDPR. Our legitimate interest is to provide the site securely '
          'and reliably. As the providers are based in the USA, data may be transferred there. The transfer '
          'is based on the EU-US Data Privacy Framework or the European Commission’s standard contractual '
          'clauses, depending on the provider.',
    ]),
    LegalText([
      'The fonts are loaded directly from this site, not from Google or any other third party.',
    ]),
  ]),
  const LegalSection('Street images in Geo Bingo', [
    LegalText([
      'Only when you play ',
      Strong('Geo Bingo'),
      ' does your browser load street images directly from ',
      Strong('Google Street View'),
      ' (Google Ireland Limited, Ireland, and Google LLC, USA). To do so, it also loads the display '
          'software from Google (Google Maps JavaScript API). Google necessarily receives your IP address, '
          'the date, time, browser identifier, the address of this site and which images you view. How '
          'Google processes this data is described in Google\'s privacy policy at policies.google.com/privacy.',
    ]),
    LegalText([
      'Once the free daily quota for Google is used up, the images come from ',
      Strong('Mapillary'),
      ' (part of Meta Platforms Inc., USA) instead. Mapillary then receives the same information. The '
          'software for that display is hosted on this site and is not loaded from Mapillary.',
    ]),
    LegalText([
      'The legal basis is Art. 6(1)(f) GDPR. Our legitimate interest is being able to offer the game with '
          'street images. For the transfer to the USA, what is said above under Hosting applies.',
    ]),
  ]),
  Builder(
    builder: (context) => LegalSection('Your rights', [
      const LegalText(['You have the right to']),
      const LegalBullets([
        ['access your data (Art. 15 GDPR),'],
        ['rectification (Art. 16 GDPR),'],
        ['erasure (Art. 17 GDPR),'],
        ['restriction of processing (Art. 18 GDPR),'],
        ['data portability (Art. 20 GDPR),'],
        ['object to the processing (Art. 21 GDPR).'],
      ]),
      LegalText([
        'Just send an email to ',
        mailLink(context),
        '. You can also lodge a complaint with a data protection supervisory authority, for example in '
            'the German federal state where you live.',
      ]),
    ]),
  ),
  const Hint('Last updated: November 2026'),
];
