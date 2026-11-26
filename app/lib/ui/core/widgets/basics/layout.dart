// Anordnung: Abstände, Kästen, Raster, Aufklappbereiche und Listenzeilen.
import 'package:material_ui/material_ui.dart';

import '../../themes/theme.dart';
import 'buttons.dart';

/// Spalte, deren Kinder die volle Breite bekommen.
class Gap extends StatelessWidget {
  const Gap({super.key, this.spacing = 12, required this.children});

  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: spacing,
    children: children,
  );
}

/// Die Knöpfe am Ende eines Bildschirms.
class ActionColumn extends StatelessWidget {
  const ActionColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Gap(spacing: 10, children: children),
  );
}

/// Kasten mit Hintergrund.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.borderColor,
    this.border = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  });

  final Widget child;
  final Color? borderColor;
  final bool border;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.palette.surface,
      border: border ? Border.all(color: borderColor ?? context.palette.line, width: 2) : null,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

/// Gestrichelter Rahmen.
class DashedBorder extends CustomPainter {
  const DashedBorder({required this.color, required this.radius, this.width = 1});

  final Color color;
  final double radius;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(width / 2), Radius.circular(radius)));
    final dash = width * 3 + 1;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += dash * 2) {
        canvas.drawPath(metric.extractPath(at, at + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorder old) => old.color != color || old.radius != radius || old.width != width;
}

/// Abschnitt innerhalb der Einstellungen, oben durch eine Linie getrennt.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.palette.line)),
    ),
    child: Gap(children: children),
  );
}

/// So viele gleich breite Spalten, wie mit [minWidth] hineinpassen.
class AutoGrid extends StatelessWidget {
  const AutoGrid({super.key, required this.minWidth, this.spacing = 8, this.fit = false, required this.children});

  final double minWidth;
  final double spacing;

  /// Bei wenigen Kindern die ganze Breite unter ihnen aufteilen.
  final bool fit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      var columns = ((constraints.maxWidth + spacing) / (minWidth + spacing)).floor();
      if (fit && columns > children.length) columns = children.length;
      if (columns < 1) columns = 1;
      // Abrunden, damit Rundungsfehler keinen Umbruch auslösen
      final width = ((constraints.maxWidth - spacing * (columns - 1)) / columns).floorToDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(key: child.key, width: width, child: child)],
      );
    },
  );
}

/// Dreieck, das sich beim Aufklappen umdreht.
class Chevron extends StatelessWidget {
  const Chevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.5 : 0,
    duration: context.motion(250),
    child: Icon(Icons.expand_more, size: 20, color: context.palette.muted),
  );
}

/// Kopfzeile, unter der sich der Inhalt weich auf- und zuklappt.
class Expandable extends StatefulWidget {
  const Expandable({
    super.key,
    required this.open,
    required this.onChanged,
    required this.header,
    required this.child,
    this.radius = 12,
  });

  final bool open;
  final ValueChanged<bool> onChanged;
  final Widget header;
  final Widget child;
  final double radius;

  @override
  State<Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<Expandable> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, value: widget.open ? 1 : 0);
  late final _size = CurvedAnimation(parent: _controller, curve: Curves.ease);

  @override
  void didUpdateWidget(Expandable old) {
    super.didUpdateWidget(old);
    if (old.open == widget.open) return;
    _controller.duration = context.motion(250);
    widget.open ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _size.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        expanded: widget.open,
        child: Pressable(radius: widget.radius, onPressed: () => widget.onChanged(!widget.open), child: widget.header),
      ),
      AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => _controller.isDismissed
            ? const SizedBox.shrink()
            : SizeTransition(
                sizeFactor: _size,
                alignment: Alignment.topCenter,
                child: Padding(padding: const EdgeInsets.only(top: 10), child: child),
              ),
        child: widget.child,
      ),
    ],
  );
}

/// Zeile einer Liste mit Trennlinie darunter.
class ListLine extends StatelessWidget {
  const ListLine({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.palette.line)),
    ),
    child: child,
  );
}

/// Name links, Anmerkung rechts.
class NameLine extends StatelessWidget {
  const NameLine({super.key, required this.name, this.nameStyle, this.note, this.noteColor, this.trailing});

  final String name;
  final TextStyle? nameStyle;
  final Widget? note;
  final Color? noteColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListLine(
    child: Row(
      spacing: 10,
      children: [
        Expanded(child: Text(name, style: nameStyle)),
        if (note != null)
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: noteColor ?? context.palette.muted, fontSize: 14.4),
                textAlign: TextAlign.right,
                child: note!,
              ),
            ),
          ),
        ?trailing,
      ],
    ),
  );
}

/// Kleiner quadratischer Knopf neben einem Namen (entfernen, verschieben).
class IconSquare extends StatelessWidget {
  const IconSquare({super.key, required this.icon, required this.semanticLabel, required this.onPressed});

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    radius: 8,
    semanticLabel: semanticLabel,
    onPressed: onPressed,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: context.palette.muted),
    ),
  );
}
