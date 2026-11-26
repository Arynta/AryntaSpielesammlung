// Online-Ansicht für Werwolf: Nacht und Tag, eigene Rolle oder Übersicht der Spielleitung.
import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../domain/models/models.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

List<Widget> werwolfView(AppController controller, RoomView room, WerwolfView werwolf) {
  final night = room.phase == Phase.night;
  final role = werwolf.role;
  return [
    PhaseHead(
      label: 'Werwolf',
      title: '${night ? 'Nacht' : 'Tag'} ${room.round}',
      lead: night
          ? 'Alle schließen die Augen. Die Spielleitung ruft die Rollen nacheinander auf.'
          : 'Diskutiert, wer ein Werwolf sein könnte, und stimmt ab.',
    ),
    if (werwolf.gameMaster)
      RoleOverview(
        rows: [for (final a in werwolf.overview ?? <RoleAssignment>[]) (name: a.playerName, role: a.role)],
        leftoverRoles: werwolf.leftoverRoles,
      )
    else if (role != null)
      SecretCard(
        key: const ValueKey('secret'),
        tone: CardTone.forTeam(role.team),
        what: 'um deine Rolle zu sehen',
        content: RoleCardContent(role: role, knownWolves: werwolf.knownWolves, leftoverRoles: werwolf.leftoverRoles),
      ),
    PlayerList(room: room),
    ActionColumn(
      children: [
        if (room.you.host) ...[
          AppButton.primary(night ? 'Weiter zum Tag' : 'Weiter zur Nacht', onPressed: controller.nextPhase),
          AppButton.quiet('Spiel beenden', onPressed: controller.backToLobby),
        ] else
          AppButton.quiet('Raum verlassen', onPressed: controller.leave),
      ],
    ),
  ];
}
