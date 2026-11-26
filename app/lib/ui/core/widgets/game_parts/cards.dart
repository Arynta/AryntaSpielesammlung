// Karten mit geheimem Inhalt: Rolle, Wort und die Übersicht der Spielleitung.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/repositories/game_data.dart';
import '../../../../domain/models/models.dart';
import '../../../../l10n/l10n.dart';
import '../../themes/theme.dart';
import '../widgets.dart';

/// Kartenfarbe nach Team bzw. Impostor-Rolle.
enum CardTone {
  wolves(Color(0xFF7D2424), Color(0xFFA63A3A)),
  village(Color(0xFF355A37), Color(0xFF4F7D51)),
  neutral(Color(0xFF4A3D8C), Color(0xFF6D5FB8));

  const CardTone(this.fill, this.border);
  final Color fill;
  final Color border;

  static CardTone forTeam(String team) => switch (team) {
    'WOELFE' => wolves,
    'DORF' => village,
    _ => neutral,
  };
}

/// Die Kartenfläche. Ohne [tone] ist sie verdeckt.
class CardFace extends StatelessWidget {
  const CardFace({super.key, required this.tone, required this.child});

  final CardTone? tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = tone;
    final face = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: open?.fill ?? p.surface,
        border: open == null ? null : Border.all(color: open.border, width: 2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DefaultTextStyle.merge(
        textAlign: TextAlign.center,
        style: TextStyle(color: open == null ? p.text : Colors.white),
        child: child,
      ),
    );
    if (open != null) return face;
    return CustomPaint(
      foregroundPainter: DashedBorder(color: p.line, radius: 18, width: 2),
      child: face,
    );
  }
}

Widget _cardText(String text, {bool bold = false}) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 290),
  child: Text(text, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
);

class RoleCardContent extends StatelessWidget {
  const RoleCardContent({super.key, required this.role, required this.knownWolves, required this.leftoverRoles});

  final RoleCard role;
  final List<String> knownWolves;
  final List<String> leftoverRoles;

  @override
  Widget build(BuildContext context) {
    final data = gameData.roleById(role.id);
    final String? wolves;
    if (data.seesWolfPack) {
      wolves = knownWolves.isEmpty
          ? texts.noKnownWolves
          : texts.theWerewolves(knownWolves.join(', '));
    } else if (data.wolfPack) {
      wolves = knownWolves.isEmpty ? texts.huntAlone : texts.huntingWithYou(knownWolves.join(', '));
    } else {
      wolves = null;
    }
    final image = roleImages[role.id];
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (image != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 256),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              // Die Karte ist quadratisch-unabhängig, die Höhe ergibt sich aus der Breite
              child: Image.asset(image, semanticLabel: role.name, fit: BoxFit.fitWidth),
            ),
          )
        else ...[
          Text(
            role.teamName.toUpperCase(),
            semanticsLabel: role.teamName,
            style: const TextStyle(fontSize: 13.6, fontWeight: FontWeight.w700, letterSpacing: 1.1),
          ),
          Text(role.name, style: display(48)),
        ],
        _cardText(role.description),
        if (wolves != null) _cardText(wolves, bold: true),
        if (leftoverRoles.isNotEmpty) _cardText(texts.leftoverCards(leftoverRoles.join(texts.and)), bold: true),
      ],
    );
  }
}

class ImpostorCardContent extends StatelessWidget {
  const ImpostorCardContent({
    super.key,
    required this.isImpostor,
    required this.word,
    required this.category,
    required this.fellowImpostors,
  });

  final bool isImpostor;
  final String? word;
  final String? category;
  final List<String> fellowImpostors;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: [
      Text(isImpostor ? 'Impostor' : word ?? '', style: display(48)),
      if (category != null)
        isImpostor ? RichLine(['${texts.category}: ', Strong(category!)]) : _cardText('${texts.category}: $category')
      else if (isImpostor)
        _cardText(texts.impostorBluff),
      if (isImpostor && fellowImpostors.isNotEmpty) _cardText(texts.withYou(fellowImpostors.join(', ')), bold: true),
    ],
  );
}

/// Karte, die ihren Inhalt nur zeigt, solange man sie gedrückt hält.
class SecretCard extends StatefulWidget {
  const SecretCard({super.key, required this.tone, required this.what, required this.content});

  final CardTone tone;

  /// Satzende für den Hinweis, z. B. „um dein Wort zu sehen“.
  final String what;
  final Widget content;

  @override
  State<SecretCard> createState() => _SecretCardState();
}

class _SecretCardState extends State<SecretCard> {
  bool _revealing = false;
  bool _focused = false;

  /// Verdeckt die Karte auch, wenn das Fenster den Fokus verliert.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onInactive: () => _set(false));

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bilder vorab laden, damit sie beim Aufdecken sofort da sind
    for (final image in roleImages.values) {
      precacheImage(AssetImage(image), context);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _set(bool revealing) {
    if (mounted && _revealing != revealing) setState(() => _revealing = revealing);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (event is KeyDownEvent) _set(true);
    if (event is KeyUpEvent) _set(false);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _onKey,
    onFocusChange: (focused) {
      if (!focused) _set(false);
      setState(() => _focused = focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional);
    },
    child: Semantics(
      button: true,
      label: _revealing ? null : texts.holdTo(widget.what),
      excludeSemantics: !_revealing,
      child: Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        // Hält die Geste fest, damit die Seite unter dem Finger nicht wegscrollt
        child: GestureDetector(
          onVerticalDragStart: (_) {},
          onLongPress: () {},
          onLongPressEnd: (_) => _set(false),
          excludeFromSemantics: true,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: FocusRing(
              show: _focused,
              radius: 18,
              child: CardFace(
                tone: _revealing ? widget.tone : null,
                child: _revealing
                    ? widget.content
                    : Text(
                        texts.holdToTwoLines(widget.what),
                        style: TextStyle(color: context.palette.muted, fontSize: 17.6),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Liste „Name – Rolle“ für die Spielleitung.
class RoleOverview extends StatelessWidget {
  const RoleOverview({super.key, required this.rows, required this.leftoverRoles});

  final List<({String name, RoleCard role})> rows;
  final List<String> leftoverRoles;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Gap(
      spacing: 0,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionTitle(texts.allRoles)),
        for (final row in rows)
          NameLine(
            name: row.name,
            noteColor: switch (CardTone.forTeam(row.role.team)) {
              CardTone.wolves => p.wolfNote,
              CardTone.village => p.villageNote,
              CardTone.neutral => p.neutralNote,
            },
            note: Text('${row.role.name} · ${row.role.teamName}'),
          ),
        if (leftoverRoles.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Hint(texts.leftoverCards(leftoverRoles.join(texts.and)))),
      ],
    );
  }
}
