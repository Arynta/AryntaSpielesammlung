// Online-Ansicht für Werwolf: Nacht und Tag, eigene Rolle oder Übersicht der Spielleitung.
import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

List<Widget> werwolfView(AppController controller, RoomView room, WerwolfView werwolf) {
  final night = room.phase == Phase.night;
  final role = werwolf.role;
  return [
    PhaseHead(
      label: texts.werwolf,
      title: night ? texts.werwolfNight(room.round) : texts.werwolfDay(room.round),
      lead: night ? texts.werwolfNightLead : texts.werwolfDayLead,
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
        what: texts.toSeeYourRole,
        content: RoleCardContent(role: role, knownWolves: werwolf.knownWolves, leftoverRoles: werwolf.leftoverRoles),
      ),
    PlayerList(room: room),
    ActionColumn(
      children: [
        if (room.you.host) ...[
          AppButton.primary(night ? texts.toDay : texts.toNight, onPressed: controller.nextPhase),
          AppButton.quiet(texts.endGame, onPressed: controller.backToLobby),
        ] else
          AppButton.quiet(texts.leaveRoom, onPressed: controller.leave),
      ],
    ),
  ];
}
