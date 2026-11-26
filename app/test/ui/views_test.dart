// Jede Ansicht, die der Server liefern kann, auf kleinen und großen Bildschirmen.
import 'package:arynta/domain/models/models.dart';
import 'package:arynta/ui/games/widgets/buzzer.dart';
import 'package:arynta/ui/core/widgets/shared.dart';
import 'package:arynta/ui/core/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/harness.dart';

void main() {
  setUpAll(prepare);
  final fixtures = loadFixtures();

  /// Der Knopf mit genau dieser Beschriftung.
  Finder button(String label) => find.byWidgetPredicate((w) => w is AppButton && w.label == label);

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(320, 640), Size(390, 844), Size(1280, 800)]) {
    testWidgets('alle Ansichten passen auf ${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
      final app = await pumpApp(tester, size: size);
      for (final MapEntry(key: name, value: state) in fixtures.entries) {
        app.show(state);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull, reason: name);
        if (name.startsWith('lobby_')) {
          // Auch aufgeklappt darf nichts überlaufen
          app.controller.setSettingsOpen(true);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: '$name aufgeklappt');
          app.controller.setSettingsOpen(false);
          await tester.pump(const Duration(seconds: 1));
        }
      }
    });
  }

  testWidgets('Lobby: Host startet, wählt ein Spiel und ändert Einstellungen', (tester) async {
    final app = await pumpApp(tester);
    final state = fixtures['lobby_impostor_host']!;
    app.show(state);
    await tester.pumpAndSettle();
    expect(find.text(state['code'] as String), findsOneWidget);
    expect(tester.widget<AppButton>(button('Spiel starten')).onPressed, isNull);

    await tap(tester, button('Ich bin bereit'));
    expect(app.link.sent.last, {'type': 'setReady', 'ready': true});

    await tap(tester, find.text('Werwolf'));
    expect(app.link.sent.last, {'type': 'selectGame', 'game': 'WERWOLF'});

    await tap(tester, find.text('Spieleinstellungen'));
    expect(app.storage.values['arynta.settingsOpen'], 'true');
    await tap(tester, find.text('Impostor sieht die Kategorie'));
    expect(app.link.sent.last, {'type': 'configureImpostor', 'impostorSeesCategory': false, 'customWord': ''});
    await tap(tester, find.text('Essen und Trinken'));
    expect(app.link.sent.last, {
      'type': 'setImpostorCategories',
      'categories': ['Tiere', 'Essen und Trinken', 'Orte'],
    });
  });

  testWidgets('Lobby: Gäste sehen die Einstellungen, aber keine Knöpfe dafür', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['lobby_werwolf_guest']!);
    app.controller.setSettingsOpen(true);
    await tester.pumpAndSettle();
    expect(button('Spiel starten'), findsNothing);
    expect(find.byType(AppCheck), findsNothing);
    expect(find.byType(SettingsSummary), findsOneWidget);
    expect(find.textContaining('Seherin, Dieb', findRichText: true), findsOneWidget);
  });

  testWidgets('Geheime Karte zeigt das Wort nur, solange man sie hält', (tester) async {
    final app = await pumpApp(tester);
    final state = fixtures['impostor_word_crew']!;
    final word = (state['impostor'] as Json)['word'] as String;
    app.show(state);
    await tester.pumpAndSettle();
    expect(find.text(word), findsNothing);

    final hold = await tester.startGesture(tester.getCenter(find.byType(SecretCard)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(word), findsOneWidget);
    // Auch nach dem langen Drücken bleibt die Karte offen
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(word), findsOneWidget);
    await hold.up();
    await tester.pump();
    expect(find.text(word), findsNothing);
  });

  testWidgets('Werwolf: Karte zeigt die eigene Rolle, die Spielleitung sieht alle', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['werwolf_night_wolf']!);
    await tester.pumpAndSettle();
    final hold = await tester.startGesture(tester.getCenter(find.byType(SecretCard)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Image), findsOneWidget);
    await hold.up();
    await tester.pump();

    app.show(fixtures['werwolf_night_game_master']!);
    await tester.pumpAndSettle();
    expect(find.text('Alle Rollen'), findsOneWidget);
    expect(find.byType(SecretCard), findsNothing);
    await tap(tester, button('Weiter zum Tag'));
    expect(app.link.types.last, 'nextPhase');
  });

  testWidgets('Impostor: Abstimmen schickt die Stimme', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['impostor_voting']!);
    await tester.pumpAndSettle();
    await tap(tester, find.byType(VoteOption).first);
    expect(app.link.types.last, 'vote');
    expect(app.link.sent.last['targetId'], isNot((fixtures['impostor_voting']!['you'] as Json)['id']));
  });

  testWidgets('Tabu: jede Rolle bekommt nur ihre Knöpfe', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['tabu_ready_explainer']!);
    await tester.pumpAndSettle();
    await tap(tester, button('Uhr starten'));
    expect(app.link.types.last, 'startTurn');

    app.show(fixtures['tabu_turn_explainer']!);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ForbiddenCard), findsOneWidget);
    expect(find.byType(Countdown), findsOneWidget);
    expect(button('Verboten!'), findsNothing);
    await tester.tap(button('Richtig'));
    await tester.tap(button('Überspringen'));
    expect(app.link.types.sublist(app.link.types.length - 2), ['wordCorrect', 'wordSkip']);

    app.show(fixtures['tabu_turn_watcher']!);
    await tester.pump(const Duration(seconds: 1));
    expect(button('Richtig'), findsNothing);
    await tester.tap(button('Verboten!'));
    expect(app.link.types.last, 'buzz');

    for (final name in ['tabu_turn_guesser', 'tabu_turn_other']) {
      app.show(fixtures[name]!);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ForbiddenCard), findsNothing, reason: name);
    }
  });

  testWidgets('Nobody is Perfect: Antwort bleibt beim Tippen stehen und wird abgeschickt', (tester) async {
    final app = await pumpApp(tester);
    final writing = fixtures['nobody_writing_host']!;
    app.show(writing);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Eine Lüge');
    // Neue Ansicht derselben Frage: der Entwurf darf nicht verschwinden
    app.show(writing);
    await tester.pumpAndSettle();
    expect(app.controller.answerInput.text, 'Eine Lüge');
    await tap(tester, button('Antwort abgeben'));
    expect(app.link.sent.last, {'type': 'submitAnswer', 'answer': 'Eine Lüge'});

    app.show(fixtures['nobody_guessing']!);
    await tester.pumpAndSettle();
    expect(app.controller.answerInput.text, isEmpty);
    await tap(tester, find.byType(VoteOption).last);
    expect(app.link.types.last, 'guessAnswer');
  });

  testWidgets('Buzzer zählt schon beim Antippen', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['buzzer_player_open']!);
    await tester.pumpAndSettle();
    final press = await tester.startGesture(tester.getCenter(find.byType(BuzzerButton)));
    expect(app.link.types.last, 'pressBuzzer');
    await press.up();
    await tester.pumpAndSettle();
    expect(app.link.types.where((t) => t == 'pressBuzzer'), hasLength(1));

    app.show(fixtures['buzzer_player_first']!);
    await tester.pumpAndSettle();
    expect(find.text('Du warst Erster!'), findsOneWidget);
    await tester.tap(find.byType(BuzzerButton));
    expect(app.link.types.where((t) => t == 'pressBuzzer'), hasLength(1));
  });

  // Die Spieluhr tickt ständig, deshalb pump statt pumpAndSettle
  testWidgets('Geo-Bingo: abstimmen schickt die Stimme, eigene Meldung sperrt die Karte', (tester) async {
    final app = await pumpApp(tester);
    final vote = fixtures['geo_bingo_vote']!;
    app.show(vote);
    await tester.pump();
    final claimId = ((vote['geoBingo'] as Json)['claims'] as List).single['id'];
    await tester.ensureVisible(button('Ja, stimmt'));
    await tester.tap(button('Ja, stimmt'));
    expect(app.link.sent.last, {'type': 'voteGeoBingo', 'claimId': claimId, 'accept': true});

    app.show(fixtures['geo_bingo_claimer']!);
    await tester.pump();
    expect(find.text('Ja, stimmt'), findsNothing);
    final board = ((fixtures['geo_bingo_claimer']!['geoBingo'] as Json)['board'] as List).cast<String>();
    final tiles = tester.widgetList<Pressable>(
      find.byWidgetPredicate((w) => w is Pressable && board.any((m) => w.semanticLabel?.startsWith(m) ?? false)),
    );
    expect(tiles, hasLength(9));
    expect(tiles.where((t) => t.onPressed != null), isEmpty);
  });

  testWidgets('Geo-Bingo: ohne geladenes Straßenbild wird nichts gemeldet', (tester) async {
    final app = await pumpApp(tester);
    final start = fixtures['geo_bingo_start']!;
    app.show(start);
    await tester.pump();
    final motif = ((start['geoBingo'] as Json)['board'] as List).first as String;
    final tile = find.byWidgetPredicate((w) => w is Pressable && w.semanticLabel == motif);
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    expect(app.link.types, isNot(contains('claimGeoBingoField')));
    expect(app.controller.toast, 'Das Straßenbild ist noch nicht geladen.');
  });

  testWidgets('Rückfrage: Nein bricht ab, Ja führt aus', (tester) async {
    final app = await pumpApp(tester);
    app.show(fixtures['buzzer_host_pressed']!);
    await tester.pumpAndSettle();
    await tap(tester, button('Spiel beenden'));
    await tap(tester, button('Nein'));
    expect(app.link.types, isNot(contains('backToLobby')));
    await tap(tester, button('Spiel beenden'));
    await tap(tester, button('Ja, beenden'));
    expect(app.link.types.last, 'backToLobby');
  });
}
