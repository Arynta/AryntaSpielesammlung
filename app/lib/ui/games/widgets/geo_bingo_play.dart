// Laufende Geo-Bingo-Runde im Vollbild: Das Straßenbild füllt alles, links liegt die Bingo-Karte zum
// Einklappen, oben rechts die Uhr, Abstimmungen erscheinen unten als Karte.
import 'package:material_ui/material_ui.dart';

import '../../../data/services/street_view/street_view.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/view_model/app_controller.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';
import 'geo_bingo.dart';

class GeoBingoPlay extends StatefulWidget {
  const GeoBingoPlay({super.key, required this.controller, required this.room, required this.game});

  final AppController controller;
  final RoomView room;
  final GeoBingoView game;

  @override
  State<GeoBingoPlay> createState() => _GeoBingoPlayState();
}

class _GeoBingoPlayState extends State<GeoBingoPlay> {
  var _boardOpen = true;

  /// Unten bleibt frei: Dort stehen Logo und Quellenangabe des Anbieters, die sichtbar bleiben müssen.
  static const _attribution = 40.0;
  static const _gap = 12.0;
  static const _voteWidth = 420.0;

  // Die Statuszeile über dem Spiel kann Platz wegnehmen, deshalb zählt der Platz hier, nicht der Bildschirm
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _build(context, box.biggest.width));

  Widget _build(BuildContext context, double width) {
    final controller = widget.controller;
    final room = widget.room;
    final game = widget.game;
    final toVote = game.claims.where((c) => c.playerId != room.you.id && c.yourVote == null).firstOrNull;
    final deadline = controller.geoBingoDeadline;
    final safe = MediaQuery.paddingOf(context);
    // Rechts bleibt Platz für die Uhr, damit die Karte sie auf dem Handy nicht verdeckt
    final panelWidth = (width - 3 * _gap - 96 - safe.horizontal).clamp(200.0, 340.0);

    return Stack(
      children: [
        // Ein Straßenbild für alles: Bei einer Abstimmung springt es zum Fund und danach zurück. Google rechnet
        // jeden neuen Viewer ab, deshalb gibt es keinen zweiten nur für die Abstimmung.
        Positioned.fill(
          child: ColoredBox(
            color: context.palette.surface,
            child: StreetView(
              key: ValueKey('street-${room.round}'),
              source: game.source,
              start: (lat: game.lat, lng: game.lng),
              focus: toVote?.spot,
              controller: controller.streetView,
            ),
          ),
        ),
        if (deadline != null)
          Positioned(
            top: _gap + safe.top,
            right: _gap + safe.right,
            child: PointerShield(child: Countdown(deadline, clock: true)),
          ),
        // Eingeklappt schaut nur der Griff am linken Bildschirmrand heraus
        AnimatedPositioned(
          duration: context.motion(250),
          curve: Curves.easeOutCubic,
          top: _gap + safe.top,
          bottom: _attribution + safe.bottom,
          left: _boardOpen ? _gap + safe.left : -panelWidth + safe.left,
          width: panelWidth + _BoardHandle.width,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: PointerShield(
                    child: _BoardPanel(controller: controller, room: room, game: game, canClaim: toVote == null),
                  ),
                ),
                PointerShield(
                  child: _BoardHandle(open: _boardOpen, onPressed: () => setState(() => _boardOpen = !_boardOpen)),
                ),
              ],
            ),
          ),
        ),
        if (toVote != null)
          Positioned(
            // Rechts neben der Karte, wenn dort Platz ist, sonst darüber
            left: _boardOpen && width >= panelWidth + _voteWidth + 3 * _gap
                ? panelWidth + 2 * _gap + safe.left
                : _gap + safe.left,
            right: _gap + safe.right,
            bottom: _attribution + safe.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _voteWidth),
                child: PointerShield(
                  child: _Vote(key: ValueKey(toVote.id), controller: controller, room: room, game: game, claim: toVote),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Die ausgeklappte Seite: Ort, Hinweis, Karte, Neuigkeiten und Spiel beenden. So hoch wie der Inhalt,
/// bei wenig Platz scrollt sie.
class _BoardPanel extends StatelessWidget {
  const _BoardPanel({required this.controller, required this.room, required this.game, required this.canClaim});

  final AppController controller;
  final RoomView room;
  final GeoBingoView game;
  final bool canClaim;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.bg.withValues(alpha: 0.94),
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Gap(
          spacing: 14,
          children: [
            GameLabel(texts.geoBingoPlace(game.place)),
            Hint(texts.geoBingoLookAround),
            GeoBingoBoard(game: game, playerId: room.you.id, onClaim: canClaim ? controller.claimGeoBingoField : null),
            ...geoBingoNews(room, game),
            ActionColumn(children: [endOrLeave(controller, room)]),
          ],
        ),
      ),
    );
  }
}

/// Griff am rechten Rand der Leiste: zeigt nach rechts zum Ausklappen, nach links zum Einklappen.
class _BoardHandle extends StatelessWidget {
  const _BoardHandle({required this.open, required this.onPressed});

  static const width = 32.0;

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      radius: 10,
      semanticLabel: open ? texts.geoBingoHideBoard : texts.geoBingoShowBoard,
      onPressed: onPressed,
      child: Container(
        width: width,
        height: 76,
        decoration: BoxDecoration(
          color: p.bg.withValues(alpha: 0.94),
          border: Border(
            top: BorderSide(color: p.line),
            right: BorderSide(color: p.line),
            bottom: BorderSide(color: p.line),
          ),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(2, 4))],
        ),
        child: Icon(open ? Icons.chevron_left : Icons.chevron_right, size: 24, color: p.accent),
      ),
    );
  }
}

class _Vote extends StatelessWidget {
  const _Vote({super.key, required this.controller, required this.room, required this.game, required this.claim});

  final AppController controller;
  final RoomView room;
  final GeoBingoView game;
  final GeoBingoClaim claim;

  @override
  Widget build(BuildContext context) {
    final deadline = controller.voteDeadlines[claim.id];
    return Panel(
      borderColor: context.palette.accent,
      child: Gap(
        children: [
          Row(
            children: [
              Expanded(
                child: RichLine([
                  Strong(room.nameOf(claim.playerId)),
                  texts.claimHas,
                  Strong(game.board[claim.field]),
                  texts.claimFound,
                ]),
              ),
              if (deadline != null) Countdown(deadline),
            ],
          ),
          Hint(texts.geoBingoVoteView),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: AppButton.primary(texts.yesCorrect, onPressed: () => controller.voteGeoBingo(claim.id, true)),
              ),
              Expanded(
                child: AppButton(texts.no, onPressed: () => controller.voteGeoBingo(claim.id, false)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
