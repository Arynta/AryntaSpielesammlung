// Lokaler Modus: Handy weitergeben, Karte ansehen, Tisch und Auflösung bei Impostor und Werwolf.
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../../../l10n/l10n.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../games/widgets/impostor.dart' show StartPlayer;
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

List<Widget> localPassView(LocalController local) {
  final name = local.players[local.index];
  return [
    PhaseHead(
      label: texts.cardOf(local.index + 1, local.players.length),
      title: texts.passPhoneTo(name),
      lead: texts.onlyNameMayLook(name),
    ),
    ActionColumn(
      children: [
        AppButton.primary(texts.iAmNameShowCard(name), onPressed: local.showCard),
        AppButton.quiet(texts.cancelRound, onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localCardView(LocalController local) {
  final last = local.index == local.players.length - 1;
  final CardTone tone;
  final Widget content;
  final impostor = local.impostor;
  if (impostor != null) {
    final isImpostor = impostor.impostors.contains(local.index);
    tone = isImpostor ? CardTone.wolves : CardTone.neutral;
    content = ImpostorCardContent(
      isImpostor: isImpostor,
      word: impostor.word,
      category: !isImpostor || local.setup.seesCategory ? impostor.category : null,
      fellowImpostors: [
        if (isImpostor)
          for (final seat in impostor.impostors)
            if (seat != local.index) local.players[seat],
      ],
    );
  } else {
    final deal = local.werwolf!;
    final role = deal.perPlayer[local.index];
    tone = CardTone.forTeam(role.team);
    content = RoleCardContent(
      role: gameData.cardFor(role),
      knownWolves: knownWolves(deal, local.players, local.index),
      leftoverRoles: [
        if (role.id == thief)
          for (final r in deal.leftover) r.name,
      ],
    );
  }
  return [
    GameLabel(texts.cardOfPlayer(local.players[local.index])),
    CardFace(tone: tone, child: content),
    ActionColumn(
      children: [
        AppButton.primary(
          last ? texts.hideAllHaveCards : texts.hideAndPass,
          onPressed: local.passOn,
        ),
      ],
    ),
  ];
}

List<Widget> localImpostorTable(LocalController local) {
  final start = local.impostor!.startPlayer;
  return [
    PhaseHead(
      label: 'Impostor',
      title: texts.everyoneKnowsTheirWord,
      lead: texts.localImpostorLead,
    ),
    if (start != null) StartPlayer(name: local.players[start]),
    ActionColumn(
      children: [
        AppButton.primary(texts.revealAction, onPressed: local.revealImpostor),
        AppButton.quiet(texts.cancelRound, onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localImpostorReveal(LocalController local) {
  final deal = local.impostor!;
  final names = [for (final seat in deal.impostors) local.players[seat]];
  return [
    PhaseHead(
      label: 'Impostor',
      title: texts.reveal,
      leadParts: [
        for (var i = 0; i < names.length; i++) ...[if (i > 0) texts.and, Strong(names[i])],
        names.length == 1 ? texts.wasTheImpostorSuffix : texts.wereTheImpostorsSuffix,
      ],
    ),
    ResultWord(intro: texts.theWordWas, word: deal.word, category: deal.category),
    ActionColumn(
      children: [
        AppButton.primary(texts.nextRound, onPressed: local.startRound),
        AppButton.quiet(texts.changeSettings, onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localWerwolfTable(LocalController local) {
  final deal = local.werwolf!;
  return [
    PhaseHead(
      label: texts.werwolf,
      title: texts.everyoneKnowsTheirRole,
      lead: texts.localWerwolfLead,
    ),
    ActionColumn(
      children: [
        if (local.overviewOpen) ...[
          RoleOverview(
            rows: [
              for (var i = 0; i < local.players.length; i++)
                (name: local.players[i], role: gameData.cardFor(deal.perPlayer[i])),
            ],
            leftoverRoles: [for (final r in deal.leftover) r.name],
          ),
          AppButton(texts.hideOverview, onPressed: local.hideOverview),
        ] else
          AppButton(texts.showOverview, onPressed: local.showOverview),
        AppButton.quiet(texts.redeal, onPressed: local.redeal),
        AppButton.quiet(texts.changeSettings, onPressed: local.backToSetup),
      ],
    ),
  ];
}
