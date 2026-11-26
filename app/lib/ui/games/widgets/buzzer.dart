// Online-Ansichten für den Buzzer: Einstellung in der Lobby, Knopf für Spieler, Reihenfolge für die Spielleitung.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/view_model/app_controller.dart';
import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../core/widgets/players.dart';
import '../../core/widgets/shared.dart';
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

class BuzzerSettingsView extends StatelessWidget {
  const BuzzerSettingsView({super.key, required this.controller, required this.room});

  final AppController controller;
  final RoomView room;

  @override
  Widget build(BuildContext context) {
    final lockout = room.buzzerSettings.lockout;
    if (!room.you.host) {
      return SettingsSummary([
        [lockout ? texts.buzzerLockedAfterFirst : texts.buzzerEveryoneOnce],
      ]);
    }
    return AppCheck(
      value: lockout,
      onChanged: controller.setBuzzerLockout,
      label: texts.buzzerLockoutOption,
    );
  }
}

List<Widget> buzzerView(AppController controller, RoomView room, BuzzerView game) => [
  GameLabel(texts.buzzerQuestion(room.round)),
  if (room.you.host) ..._order(controller, room, game) else ..._button(controller, game),
  ActionColumn(children: [endOrLeave(controller, room)]),
];

List<Widget> _button(AppController controller, BuzzerView game) {
  final rank = game.yourRank;
  final status = rank != null
      ? (rank == 1 ? texts.buzzerFirst : texts.buzzerRank(rank))
      : !game.canPress
      ? texts.buzzerLocked
      : texts.buzzerPressWhenYouKnow;
  return [
    BuzzerButton(key: const ValueKey('buzzer'), onPress: game.canPress ? controller.pressBuzzer : null),
    Semantics(
      liveRegion: true,
      child: Builder(
        builder: (context) => Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.muted),
        ),
      ),
    ),
  ];
}

class BuzzerButton extends StatefulWidget {
  const BuzzerButton({super.key, required this.onPress});

  /// null = gesperrt.
  final VoidCallback? onPress;

  @override
  State<BuzzerButton> createState() => _BuzzerButtonState();
}

class _BuzzerButtonState extends State<BuzzerButton> {
  bool _down = false;
  bool _focused = false;

  void _setDown(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.space && key != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (event is KeyDownEvent) widget.onPress?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onPress != null;
    final pressed = _down && enabled;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth * 0.85).clamp(0.0, 288.0);
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Center(
            child: Focus(
              canRequestFocus: enabled,
              onKeyEvent: _onKey,
              onFocusChange: (focused) => setState(
                () => _focused = focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional,
              ),
              child: Semantics(
                button: true,
                enabled: enabled,
                label: 'Buzzer',
                excludeSemantics: true,
                onTap: widget.onPress,
                // Der Buzzer zählt schon beim Antippen, nicht erst beim Loslassen: Es geht um Millisekunden
                child: Listener(
                  onPointerDown: (_) {
                    widget.onPress?.call();
                    _setDown(true);
                  },
                  onPointerUp: (_) => _setDown(false),
                  onPointerCancel: (_) => _setDown(false),
                  child: MouseRegion(
                    cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    child: FocusRing(
                      show: _focused,
                      radius: size,
                      child: AnimatedContainer(
                        duration: context.motion(100),
                        width: size,
                        height: size,
                        transform: Matrix4.translationValues(0, pressed ? 6 : 0, 0),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled ? dangerColor : p.surface,
                          border: Border.all(color: enabled ? dangerBorder : p.line, width: 6),
                          boxShadow: enabled
                              ? [BoxShadow(color: const Color(0xFF6E1712), offset: Offset(0, pressed ? 3 : 10))]
                              : null,
                        ),
                        child: Text(
                          'Buzz!',
                          style: TextStyle(
                            color: enabled ? Colors.white : p.muted,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<Widget> _order(AppController controller, RoomView room, BuzzerView game) => [
  PhaseHead(
    title: game.presses.isEmpty ? texts.buzzerWaiting : texts.isUp(room.nameOf(game.presses.first.playerId)),
    lead: game.lockout
        ? texts.buzzerLockoutOn
        : texts.buzzerEveryoneOnce,
  ),
  if (game.presses.isEmpty)
    TurnTextBox(texts.buzzerNobodyYet)
  else
    Gap(
      spacing: 8,
      children: [
        for (final press in game.presses)
          _PressRow(key: ValueKey(press.playerId), press: press, name: room.nameOf(press.playerId)),
      ],
    ),
  ActionColumn(
    children: [
      AppButton.primary(texts.buzzerRelease, onPressed: game.presses.isEmpty ? null : controller.releaseBuzzer),
    ],
  ),
];

class TurnTextBox extends StatelessWidget {
  const TurnTextBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Panel(
    border: false,
    padding: const EdgeInsets.all(20),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19)),
  );
}

class _PressRow extends StatelessWidget {
  const _PressRow({super.key, required this.press, required this.name});

  final BuzzerPress press;
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = press.rank == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        border: first ? Border.all(color: p.accent, width: 2) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(fontSize: first ? 22 : 18),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text('${press.rank}.', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(name)),
            if (!first)
              Text(
                '+${press.offsetMs} ms',
                style: TextStyle(color: p.muted, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
          ],
        ),
      ),
    );
  }
}
