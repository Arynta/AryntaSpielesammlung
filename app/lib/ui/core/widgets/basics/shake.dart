// Kurzes Kopfschütteln eines Widgets, z. B. bei falscher Eingabe.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../themes/theme.dart';

/// Wackelt einmal waagerecht, sobald sich [trigger] ändert. Ohne Animationen (Systemeinstellung) bleibt es ruhig.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(Shake oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.trigger == oldWidget.trigger) return;

    _controller.duration = context.motion(450);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      // Drei Ausschläge, die nach hinten schwächer werden
      final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}
