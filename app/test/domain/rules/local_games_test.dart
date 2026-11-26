// Übertragen aus frontend/src/localGames.test.ts.
import 'package:arynta/data/repositories/game_data.dart';
import 'package:arynta/domain/rules/local_games.dart';
import 'package:arynta/domain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/support.dart';

/// Immer gleiche Zufallsfolge, damit Tests wiederholbar sind.
Random seeded(int seed) {
  var state = seed;
  return () {
    state = (state * 1103515245 + 12345) % 2147483648;
    return state / 2147483648;
  };
}

int count(List<String> ids, String id) => ids.where((x) => x == id).length;

void main() {
  setUpAll(loadGameData);

  group('Namen', () {
    test('füllt leere Felder mit Spieler-Nummern', () {
      expect(playerNames(4, ['Anna', '  ', '', 'Ben']), ['Anna', 'Spieler 2', 'Spieler 3', 'Ben']);
      expect(playerNames(2, []), ['Spieler 1', 'Spieler 2']);
    });

    test('entfernt unsichtbare Zeichen', () {
      expect(cleanName('Rich​ard'), 'Richard');
      expect(cleanName('  Ri \t chard '), 'Ri chard');
    });

    test('findet doppelte Namen ohne Groß- und Kleinschreibung', () {
      expect(duplicateName(['Anna', 'Ben', 'anna']), 'anna');
      expect(duplicateName(['Anna', 'Ben']), isNull);
    });
  });

  group('Werwolf', () {
    test('verteilt Werwölfe automatisch nach Spielerzahl', () {
      expect([4, 7, 8, 12].map(autoWerewolves), [1, 1, 2, 3]);
    });

    test('gibt jedem genau eine Karte, Rest Dorfbewohner', () {
      final deal = dealWerwolf(8, null, [seer], seeded(1));
      final ids = [for (final r in deal.perPlayer) r.id];
      expect(ids, hasLength(8));
      expect(count(ids, werewolf), 2);
      expect(count(ids, seer), 1);
      expect(count(ids, villager), 5);
      expect(deal.leftover, isEmpty);
    });

    test('blockiert zu viele Rollen', () {
      expect(
        werwolfProblem(4, 2, [seer, 'HEXE', 'JAEGER']),
        'Zu viele Rollen: 5 Rollen für 4 Spieler. Nimm Rollen raus oder weniger Werwölfe.',
      );
      expect(werwolfProblem(3, null, []), 'Es werden mindestens 4 Spieler gebraucht.');
      expect(() => dealWerwolf(4, 2, [seer, 'HEXE', 'JAEGER'], seeded(1)), throwsStateError);
    });

    test('legt mit Dieb zwei Karten zur Seite', () {
      final deal = dealWerwolf(5, null, [thief], seeded(3));
      expect(deal.perPlayer, hasLength(5));
      expect(deal.leftover, hasLength(2));
    });

    test('Rudel kennt sich, Günstling kennt das Rudel, aber nicht umgekehrt', () {
      final names = ['A', 'B', 'C', 'D', 'E', 'F'];
      for (var seed = 0; seed < 20; seed++) {
        final deal = dealWerwolf(6, 1, ['URWOLF', 'GUENSTLING'], seeded(seed));
        for (var i = 0; i < deal.perPlayer.length; i++) {
          final role = deal.perPlayer[i];
          final known = knownWolves(deal, names, i);
          if (role.id == 'GUENSTLING') {
            expect(known, hasLength(2));
          } else if (role.wolfPack) {
            expect(known, hasLength(1));
          } else {
            expect(known, isEmpty);
          }
        }
      }
    });

    test('sortiert die Rollenauswahl wie die Rollenliste', () {
      expect(normalizeRoles(['JAEGER', 'QUATSCH', 'HEXE']), ['HEXE', 'JAEGER']);
    });

    test('jede Sonderrolle hat Namen, Text und ein bekanntes Team', () {
      expect(gameData.specialRoles, hasLength(19));
      for (final role in gameData.specialRoles) {
        expect(role.name, isNotEmpty);
        expect(role.description, isNotEmpty);
        expect(gameData.teamNames, contains(role.team));
      }
    });
  });

  group('Impostor', () {
    test('braucht ab zwei Impostorn genug Mitspieler', () {
      expect(impostorProblem(3, 1), isNull);
      expect(impostorProblem(2, 1), 'Für Impostor braucht es mindestens 3 Mitspieler.');
      expect(impostorProblem(5, 2), 'Für 2 Impostor braucht es mindestens 6 Mitspieler.');
      expect(impostorProblem(6, 2), isNull);
      expect(impostorProblem(20, maxImpostorsOverall + 1), isNotNull);
    });

    test('lost die gewünschte Zahl Impostor und einen Startspieler aus der Crew', () {
      for (var seed = 0; seed < 50; seed++) {
        final options = ImpostorOptions(impostorCount: 2, randomStartPlayer: true, categories: gameData.categoryNames);
        final deal = dealImpostor(6, options, [], seeded(seed));
        expect(deal.impostors.toSet(), hasLength(2));
        expect(deal.startPlayer, isNotNull);
        expect(deal.impostors, isNot(contains(deal.startPlayer)));
      }
    });

    test('lost keinen Startspieler, wenn ausgeschaltet', () {
      final options = ImpostorOptions(impostorCount: 1, randomStartPlayer: false, categories: gameData.categoryNames);
      expect(dealImpostor(3, options, [], seeded(1)).startPlayer, isNull);
    });

    test('nimmt nur Wörter aus den gewählten Kategorien und wiederholt keine', () {
      final animals = gameData.categories.firstWhere((c) => c.name == 'Tiere');
      final used = <String>[];
      final random = seeded(7);
      for (var i = 0; i < animals.words.length; i++) {
        final picked = pickWord(['Tiere'], used, random);
        expect(picked.category, 'Tiere');
        expect(used, isNot(contains(picked.word)));
        used.add(picked.word);
      }
      // Alle verbraucht: dann geht es von vorne los
      expect(animals.words, contains(pickWord(['Tiere'], used, random).word));
    });
  });

  group('Tabu', () {
    test('braucht genug Spieler und vollständige Teams', () {
      expect(tabuProblem(3, 2, true, []), 'Für 2 Teams braucht es mindestens 4 Spieler.');
      expect(tabuProblem(4, 2, true, []), isNull);
      expect(tabuProblem(4, 2, false, [0, 0, 1, null]), '1 Spieler hat noch kein Team.');
      expect(tabuProblem(4, 2, false, [0, 0, 0, 1]), 'Jedes Team braucht mindestens 2 Spieler.');
      expect(tabuProblem(4, 2, false, [0, 1, 0, 1]), isNull);
      // Team 3 gibt es bei 2 Teams nicht mehr, das zählt wie keine Wahl
      expect(tabuProblem(4, 2, false, [0, 1, 0, 3]), '1 Spieler hat noch kein Team.');
    });

    test('verteilt automatisch gleich groß und sonst wie gewählt', () {
      final auto = makeTeams(5, 2, true, [], seeded(1));
      expect(auto.map((t) => t.length), [3, 2]);
      expect(auto.expand((t) => t).toList()..sort(), [0, 1, 2, 3, 4]);
      expect(makeTeams(4, 2, false, [1, 0, 1, 0], seeded(1)), [
        [1, 3],
        [0, 2],
      ]);
    });

    test('Erklärer und Aufpasser kommen aus verschiedenen Teams und wechseln reihum', () {
      final match = TabuMatch([
        [0, 1, 2],
        [3, 4, 5],
      ], 30);
      final explainers = <int>[];
      final watchers = <int>[];
      for (var turn = 0; turn < 6; turn++) {
        expect(match.teams[match.currentTeam], contains(explainerSeat(match)));
        expect(match.teams[watcherTeam(match)], contains(watcherSeat(match)));
        if (match.currentTeam == 0) {
          explainers.add(explainerSeat(match));
          watchers.add(watcherSeat(match));
        }
        endTurn(match);
      }
      expect(explainers, [0, 1, 2]);
      expect(watchers, [3, 4, 5]);
    });

    test('vergibt Punkte richtig und endet bei den Siegpunkten', () {
      final random = seeded(4);
      final match = TabuMatch([
        [0, 1],
        [2, 3],
      ], 3);
      drawCard(match, random);
      scoreCard(match, CardOutcome.correct, random);
      scoreCard(match, CardOutcome.skipped, random);
      scoreCard(match, CardOutcome.buzzed, random);
      expect(match.scores, [1, 0]);
      expect(match.turnResults.map((r) => r.scoringTeam), [0, null, null]);

      scoreCard(match, CardOutcome.correct, random);
      scoreCard(match, CardOutcome.correct, random);
      expect(match.winner, 0);
      expect(match.card, isNull);
      expect(match.lastTurn, hasLength(5));
      scoreCard(match, CardOutcome.correct, random);
      expect(match.scores, [3, 0]);
    });

    test('wiederholt keine Karte, bis alle dran waren', () {
      final random = seeded(9);
      final match = TabuMatch([
        [0, 1],
        [2, 3],
      ], 1000);
      final seen = <String>{};
      drawCard(match, random);
      for (var i = 0; i < gameData.tabuCards.length; i++) {
        expect(seen, isNot(contains(match.card!.word)));
        seen.add(match.card!.word);
        scoreCard(match, i.isOdd ? CardOutcome.skipped : CardOutcome.correct, random);
      }
      expect(seen, hasLength(gameData.tabuCards.length));
    });
  });

  group('Nobody is Perfect', () {
    /// Drei Spieler, alle haben geschrieben, die Antworten sind gemischt.
    NobodyIsPerfectMatch mixed(Random random) {
      final match = NobodyIsPerfectMatch(3, pickQuestions(3, [], random));
      expect(submitLie(match, 0, 'Lüge von Anna'), isNull);
      expect(submitLie(match, 1, 'Lüge von Ben'), isNull);
      expect(submitLie(match, 2, 'Lüge von Cem'), isNull);
      mixChoices(match, random);
      return match;
    }

    String choiceOf(NobodyIsPerfectMatch match, int? author) => match.choices.firstWhere((c) => c.author == author).id;

    test('zieht erst Fragen, die noch nicht dran waren', () {
      final random = seeded(2);
      final used = [for (final q in gameData.questions.skip(3)) q.question];
      final picked = [for (final q in pickQuestions(5, used, random)) q.question];
      expect(picked, hasLength(5));
      expect(picked.toSet(), hasLength(5));
      expect(picked.take(3).every((q) => !used.contains(q)), isTrue);
    });

    test('prüft und bereinigt die Antwort', () {
      final match = NobodyIsPerfectMatch(3, pickQuestions(3, [], seeded(1)));
      expect(submitLie(match, 0, '   '), isNotNull);
      expect(submitLie(match, 0, 'x' * 101), isNotNull);
      expect(submitLie(match, 0, '  Eine   Lüge '), isNull);
      expect(match.answers[0], 'Eine Lüge');
    });

    test('mischt alle Antworten und die echte mit Buchstaben', () {
      final match = mixed(seeded(3));
      expect(match.choices.map((c) => c.id), ['A', 'B', 'C', 'D']);
      expect(match.choices.firstWhere((c) => c.author == null).text, match.questions[0].answer);
    });

    test('verbietet den Tipp auf die eigene Antwort', () {
      final match = mixed(seeded(4));
      expect(guessChoice(match, 0, choiceOf(match, 0)), isNotNull);
      expect(guessChoice(match, 0, 'Z'), isNotNull);
      expect(match.guesses[0], isNull);
    });

    test('vergibt Punkte für richtige Tipps und gelungene Täuschungen', () {
      final match = mixed(seeded(5));
      guessChoice(match, 0, choiceOf(match, null)); // Anna richtig: +1 Anna
      guessChoice(match, 1, choiceOf(match, 0)); // Ben fällt auf Anna rein: +1 Anna
      guessChoice(match, 2, choiceOf(match, 1)); // Cem fällt auf Ben rein: +1 Ben
      revealQuestion(match);
      expect(match.gained, [2, 1, 0]);
      expect(match.scores, [2, 1, 0]);

      expect(isLastQuestion(match), isFalse);
      nextQuestion(match);
      expect(match.index, 1);
      expect(match.answers, [null, null, null]);
      expect(match.choices, isEmpty);
      expect(match.gained, [0, 0, 0]);
      expect(match.scores, [2, 1, 0]);
    });
  });
}
