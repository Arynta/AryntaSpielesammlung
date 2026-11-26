// Lokaler Modus: Handy weitergeben, Karte ansehen, Tisch und Auflösung bei Impostor und Werwolf.
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/game_data.dart';
import '../view_model/local_controller.dart';
import '../../../domain/rules/local_games.dart';
import '../../games/widgets/impostor.dart' show StartPlayer;
import '../../core/widgets/shared.dart';
import '../../core/widgets/widgets.dart';

List<Widget> localPassView(LocalController local) {
  final name = local.players[local.index];
  return [
    PhaseHead(
      label: 'Karte ${local.index + 1} von ${local.players.length}',
      title: 'Gib das Handy an $name',
      lead: 'Nur $name darf auf den Bildschirm schauen.',
    ),
    ActionColumn(
      children: [
        AppButton.primary('Ich bin $name, Karte zeigen', onPressed: local.showCard),
        AppButton.quiet('Runde abbrechen', onPressed: local.backToSetup),
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
    GameLabel('Karte von ${local.players[local.index]}'),
    CardFace(tone: tone, child: content),
    ActionColumn(
      children: [
        AppButton.primary(
          last ? 'Verstecken, alle haben ihre Karte' : 'Verstecken und weitergeben',
          onPressed: local.passOn,
        ),
      ],
    ),
  ];
}

List<Widget> localImpostorTable(LocalController local) {
  final start = local.impostor!.startPlayer;
  return [
    const PhaseHead(
      label: 'Impostor',
      title: 'Alle kennen ihr Wort',
      lead: 'Reihum sagt jeder ein Wort als Hinweis. Dann zeigt ihr gleichzeitig auf euren Verdacht.',
    ),
    if (start != null) StartPlayer(name: local.players[start]),
    ActionColumn(
      children: [
        AppButton.primary('Auflösen', onPressed: local.revealImpostor),
        AppButton.quiet('Runde abbrechen', onPressed: local.backToSetup),
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
      title: 'Auflösung',
      leadParts: [
        for (var i = 0; i < names.length; i++) ...[if (i > 0) ' und ', Strong(names[i])],
        names.length == 1 ? ' war der Impostor.' : ' waren die Impostor.',
      ],
    ),
    ResultWord(intro: 'Das Wort war', word: deal.word, category: deal.category),
    ActionColumn(
      children: [
        AppButton.primary('Nächste Runde', onPressed: local.startRound),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}

List<Widget> localWerwolfTable(LocalController local) {
  final deal = local.werwolf!;
  return [
    const PhaseHead(
      label: 'Werwolf',
      title: 'Alle kennen ihre Rolle',
      lead: 'Die Spielleitung führt jetzt durch Nacht und Tag.',
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
          AppButton('Übersicht verstecken', onPressed: local.hideOverview),
        ] else
          AppButton('Spielleitung: alle Rollen zeigen', onPressed: local.showOverview),
        AppButton.quiet('Neu verteilen', onPressed: local.redeal),
        AppButton.quiet('Einstellungen ändern', onPressed: local.backToSetup),
      ],
    ),
  ];
}
