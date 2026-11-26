// Werwolf lokal, wie RoleDistribution im Backend.
import 'dart:math' as math;

import '../../data/repositories/game_data.dart';
import '../../l10n/l10n.dart';
import '../models/models.dart';
import 'common.dart';

/// Ein Werwolf pro angefangene vier Spieler (4–7 → 1, 8–11 → 2, ...).
int autoWerewolves(int playerCount) => math.max(1, playerCount ~/ 4);

/// [chosen] ist null, wenn die Anzahl automatisch sein soll.
int werewolves(int playerCount, int? chosen) => chosen ?? autoWerewolves(playerCount);

String? werwolfProblem(int playerCount, int? chosen, List<String> specialRoles) {
  final needed = minPlayers[GameType.werwolf]!;
  if (playerCount < needed) return texts.werwolfMinPlayers(needed);
  final cards = werewolves(playerCount, chosen) + specialRoles.length;
  if (cards > playerCount) {
    return texts.tooManyRoles(cards, playerCount);
  }
  return null;
}

/// Bringt die Auswahl in die Reihenfolge der Rollenliste und lässt Unbekanntes weg.
List<String> normalizeRoles(Iterable<String> ids) => [
  for (final role in gameData.specialRoles)
    if (ids.contains(role.id)) role.id,
];

class WerwolfDeal {
  const WerwolfDeal(this.perPlayer, this.leftover);
  final List<RoleData> perPlayer;

  /// Nur mit Dieb: die zwei übrigen Karten.
  final List<RoleData> leftover;
}

WerwolfDeal dealWerwolf(int playerCount, int? chosen, List<String> specialRoles, Random random) {
  final problem = werwolfProblem(playerCount, chosen, specialRoles);
  if (problem != null) throw StateError(problem);

  final extra = specialRoles.contains(thief) ? thiefExtraCards : 0;
  final cards = <RoleData>[
    for (var i = 0; i < werewolves(playerCount, chosen); i++) gameData.roleById(werewolf),
    for (final id in specialRoles) gameData.roleById(id),
  ];
  while (cards.length < playerCount + extra) {
    cards.add(gameData.roleById(villager));
  }

  final mixed = shuffled(cards, random);
  return WerwolfDeal(mixed.sublist(0, playerCount), mixed.sublist(playerCount));
}

/// Das Rudel kennt sich gegenseitig, der Günstling kennt das Rudel.
List<String> knownWolves(WerwolfDeal deal, List<String> names, int index) {
  final role = deal.perPlayer[index];
  if (!role.wolfPack && !role.seesWolfPack) return [];
  return [
    for (var i = 0; i < names.length; i++)
      if (i != index && deal.perPlayer[i].wolfPack) names[i],
  ];
}
