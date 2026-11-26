// Startseite, Wiedereinstieg, gespeicherte Daten, Rechtliches und der lokale Modus.
import 'package:arynta/logic/local_controller.dart';
import 'package:arynta/platform/storage_base.dart';
import 'package:arynta/ui/legal.dart';
import 'package:arynta/ui/shared.dart';
import 'package:arynta/ui/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

void main() {
  setUpAll(prepare);

  Finder button(String label) => find.byWidgetPredicate((w) => w is AppButton && w.label == label);
  Finder buttonStarting(String label) => find.byWidgetPredicate((w) => w is AppButton && w.label.startsWith(label));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Startseite: ohne Name kein Raum, mit Name und Code beitreten', (tester) async {
    final app = await pumpApp(tester);
    await tap(tester, button('Neuen Raum erstellen'));
    expect(find.text('Gib zuerst deinen Namen ein.'), findsOneWidget);
    expect(app.link.sent, isEmpty);

    await tester.enterText(find.byType(TextField).first, '  Anna ');
    await tap(tester, button('Beitreten'));
    expect(find.text('Gib den Raumcode ein, den dir deine Freunde geschickt haben.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'k7qx');
    await tap(tester, button('Beitreten'));
    expect(app.link.sent.last, {'type': 'join', 'code': 'K7QX', 'name': 'Anna'});
    expect(app.storage.values['werwolf.name'], '"Anna"');
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Raumcode ein'), findsNothing);
  });

  testWidgets('Gespeicherter Raum: zurückmelden, bei Fehler vergessen', (tester) async {
    final storage = MemoryStorage()..values['werwolf.session'] = '{"code":"ABCD","secret":"geheim"}';
    final app = await pumpApp(tester, storage: storage);
    expect(app.link.sent.single, {'type': 'rejoin', 'code': 'ABCD', 'secret': 'geheim'});
    expect(find.textContaining('Du kommst zurück in Raum', findRichText: true), findsOneWidget);

    app.receive({'type': 'error', 'message': 'Diesen Raum gibt es nicht.'});
    await tester.pumpAndSettle();
    expect(find.text('Diesen Raum gibt es nicht.'), findsOneWidget);
    expect(storage.values, isNot(contains('werwolf.session')));
    expect(button('Neuen Raum erstellen'), findsOneWidget);
  });

  testWidgets('Meine Daten löschen räumt alles weg', (tester) async {
    final storage = MemoryStorage()
      ..values['werwolf.name'] = '"Anna"'
      ..values['werwolf.session'] = '{"code":"ABCD","secret":"geheim"}'
      ..values['arynta.local'] = '{"playerCount":4}';
    final app = await pumpApp(tester, storage: storage);
    await tap(tester, find.text('Meine Daten löschen'));
    await tap(tester, button('Ja, löschen'));
    expect(app.link.types.last, 'leave');
    expect(storage.values, isEmpty);
    expect(app.controller.nameInput.text, isEmpty);
  });

  testWidgets('Impressum und Datenschutz', (tester) async {
    await pumpApp(tester, size: const Size(320, 640));
    await tap(tester, find.text('Impressum'));
    expect(find.byType(ImpressumScreen), findsOneWidget);
    expect(find.text('Angaben zum Betreiber'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tap(tester, find.text('Zurück zum Spiel'));
    expect(find.byType(ImpressumScreen), findsNothing);

    await tap(tester, find.text('Datenschutz'));
    expect(find.byType(DatenschutzScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Lokal', () {
    Future<LocalController> open(WidgetTester tester, {MemoryStorage? storage}) async {
      final app = await pumpApp(tester, size: const Size(320, 640), storage: storage);
      await tap(tester, button('Lokal spielen'));
      expect(app.link.sent, isEmpty);
      return app.controller.local!;
    }

    testWidgets('Einrichtung übernimmt, was die alte Webseite gespeichert hat', (tester) async {
      final storage = MemoryStorage()
        ..values['arynta.local'] =
            '{"game":"TABU","playerCount":99,"names":["Anna"],"roles":["HEXE","QUATSCH"],'
            '"categories":[],"autoTeams":false,"teams":[1,7,null],"teamCount":2,"werewolfCount":null}';
      final local = await open(tester, storage: storage);
      expect(local.setup.playerCount, 20);
      expect(local.setup.roles, ['HEXE']);
      expect(local.setup.categories, isNotEmpty);
      expect(local.setup.teams, [1, null, null]);
      expect(find.text('Anna'), findsWidgets);
      expect(find.text('17 Spieler haben noch kein Team.'), findsNothing);
      expect(find.text('19 Spieler haben noch kein Team.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('doppelte Namen sperren den Start', (tester) async {
      await open(tester);
      final fields = find.byType(TextField);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), 'Anna');
      await tester.enterText(fields.at(1), 'anna');
      await tester.pumpAndSettle();
      expect(find.text('Der Name „anna“ kommt doppelt vor.'), findsOneWidget);
      expect(tester.widget<AppButton>(button('Karten verteilen')).onPressed, isNull);
    });

    testWidgets('Impostor: Karten reihum, dann auflösen', (tester) async {
      final local = await open(tester);
      await tap(tester, button('Karten verteilen'));
      for (var seat = 1; seat <= 5; seat++) {
        await tap(tester, button('Ich bin Spieler $seat, Karte zeigen'));
        expect(find.byType(CardFace), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, buttonStarting('Verstecken'));
      }
      expect(find.text('Alle kennen ihr Wort'), findsOneWidget);
      await tap(tester, button('Auflösen'));
      await tap(tester, button('Ja, auflösen'));
      expect(find.text(local.impostor!.word, findRichText: true), findsNothing);
      expect(find.textContaining(local.impostor!.word, findRichText: true), findsOneWidget);
    });

    testWidgets('Werwolf: Übersicht erst nach Rückfrage', (tester) async {
      await open(tester);
      await tap(tester, find.text('Werwolf'));
      await tap(tester, button('Karten verteilen'));
      for (var seat = 1; seat <= 5; seat++) {
        await tap(tester, button('Ich bin Spieler $seat, Karte zeigen'));
        expect(tester.takeException(), isNull);
        await tap(tester, buttonStarting('Verstecken'));
      }
      await tap(tester, button('Spielleitung: alle Rollen zeigen'));
      expect(find.byType(RoleOverview), findsNothing);
      await tap(tester, button('Ja, zeigen'));
      expect(find.byType(RoleOverview), findsOneWidget);
    });

    testWidgets('Tabu: Punkte zählen, Zeit läuft ab', (tester) async {
      final local = await open(tester);
      await tap(tester, find.text('Tabu'));
      await tap(tester, button('Karten verteilen'));
      await tester.ensureVisible(button('Uhr starten (60 s)'));
      await tester.pumpAndSettle();
      await tester.tap(button('Uhr starten (60 s)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ForbiddenCard), findsOneWidget);
      await tester.tap(button('Richtig'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(local.match!.scores, [1, 0]);
      expect(tester.takeException(), isNull);

      local.tick(DateTime.now().add(const Duration(seconds: 61)));
      await tester.pumpAndSettle();
      expect(find.text('Team Blau ist dran'), findsOneWidget);
      expect(find.text('Letzter Zug'), findsOneWidget);
    });

    testWidgets('Nobody is Perfect: ein ganzes Spiel', (tester) async {
      final local = await open(tester);
      await tap(tester, find.text('Nobody is Perfect'));
      while (local.setup.playerCount > 3) {
        await tap(tester, find.bySemanticsLabel('Spieler verringern'));
      }
      while (local.setup.questionCount > 3) {
        await tap(tester, find.bySemanticsLabel('Fragen verringern'));
      }
      await tap(tester, button('Los geht\'s'));
      for (var question = 1; question <= 3; question++) {
        for (var seat = 1; seat <= 3; seat++) {
          await tap(tester, button('Ich bin Spieler $seat, Frage zeigen'));
          await tester.enterText(find.byType(TextField), 'Lüge $seat');
          await tap(tester, button('Abgeben und weitergeben'));
        }
        for (var seat = 1; seat <= 3; seat++) {
          await tap(tester, button('Ich bin Spieler $seat, Antworten zeigen'));
          final right = local.fib!.choices.firstWhere((c) => c.author == null);
          await tap(tester, find.text(right.text));
          await tap(tester, button('Tipp abgeben und weitergeben'));
          expect(tester.takeException(), isNull);
        }
        if (question < 3) await tap(tester, button('Nächste Frage'));
      }
      expect(find.text('Gleichstand: Spieler 1 und Spieler 2 und Spieler 3'), findsOneWidget);
      expect(find.text('Mit 3 Punkten.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
