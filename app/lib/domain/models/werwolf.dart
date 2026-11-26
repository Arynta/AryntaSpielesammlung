// Werwolf: Einstellungen, Rollen und Verteilung.
import 'json.dart';

class WerwolfSettings {
  WerwolfSettings.fromJson(Json j)
    : werewolfCount = j['werewolfCount'] as int?,
      effectiveWerewolfCount = j['effectiveWerewolfCount'] as int,
      allRoles = parseList(j['allRoles'], RoleCard.fromJson),
      selectedRoles = parseStrings(j['selectedRoles']),
      hostIsGameMaster = j['hostIsGameMaster'] as bool;

  /// null = automatisch passend zur Spielerzahl.
  final int? werewolfCount;
  final int effectiveWerewolfCount;
  final List<RoleCard> allRoles;
  final List<String> selectedRoles;
  final bool hostIsGameMaster;
}

class RoleCard {
  const RoleCard({
    required this.id,
    required this.name,
    required this.team,
    required this.teamName,
    required this.description,
  });
  RoleCard.fromJson(Json j)
    : id = j['id'] as String,
      name = j['name'] as String,
      team = j['team'] as String,
      teamName = j['teamName'] as String,
      description = j['description'] as String;
  final String id;
  final String name;
  final String team;
  final String teamName;
  final String description;
}

class RoleAssignment {
  RoleAssignment.fromJson(Json j)
    : playerId = j['playerId'] as String,
      playerName = j['playerName'] as String,
      role = RoleCard.fromJson(j['role'] as Json);
  final String playerId;
  final String playerName;
  final RoleCard role;
}

/// Mitspieler: role, knownWolves, beim Dieb leftoverRoles. Spielleitung: gameMaster, overview, leftoverRoles.
class WerwolfView {
  WerwolfView.fromJson(Json j)
    : gameMaster = j['gameMaster'] as bool,
      role = parseOptional(j['role'], RoleCard.fromJson),
      knownWolves = parseStrings(j['knownWolves']),
      leftoverRoles = parseStrings(j['leftoverRoles']),
      overview = j['overview'] == null ? null : parseList(j['overview'], RoleAssignment.fromJson);
  final bool gameMaster;
  final RoleCard? role;
  final List<String> knownWolves;
  final List<String> leftoverRoles;
  final List<RoleAssignment>? overview;
}
