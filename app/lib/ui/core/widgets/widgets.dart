// Allgemeine Bausteine: Knöpfe, Felder, Häkchen, Überschriften, Aufklappbereiche.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../themes/theme.dart';

/// Alles, was man antippen kann: gibt beim Drücken nach, zeigt den Tastaturfokus
/// und lässt sich mit Enter oder Leertaste auslösen.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.radius = 10,
    this.semanticLabel,
    this.selected,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double radius;

  /// Ersetzt für Screenreader den sichtbaren Inhalt.
  final String? semanticLabel;

  /// Nur für Knöpfe, die an oder aus sein können.
  final bool? selected;
  final bool autofocus;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  void _setDown(bool down) {
    if (mounted && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    void activate() => widget.onPressed?.call();
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: widget.selected,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        onTap: enabled ? activate : null,
        child: FocusableActionDetector(
          enabled: enabled,
          autofocus: widget.autofocus,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => activate()),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => activate()),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: enabled ? (_) => _setDown(true) : null,
            onTapUp: enabled ? (_) => _setDown(false) : null,
            onTapCancel: enabled ? () => _setDown(false) : null,
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _down && enabled ? 0.97 : 1,
              duration: context.motion(100),
              child: FocusRing(show: _focused, radius: widget.radius, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rahmen in Akzentfarbe um das Element, das gerade den Tastaturfokus hat.
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.show, required this.child, this.radius = 10});

  final bool show;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      child,
      if (show)
        Positioned(
          left: -5,
          top: -5,
          right: -5,
          bottom: -5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: context.palette.accent, width: 3),
                borderRadius: BorderRadius.circular(radius + 5),
              ),
            ),
          ),
        ),
    ],
  );
}

enum ButtonStyleKind { plain, primary, quiet, danger }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = ButtonStyleKind.plain,
    this.small = false,
    this.icon,
    this.width,
    this.semanticLabel,
    this.highlighted = false,
    this.selected,
    this.autofocus = false,
  });

  const AppButton.primary(this.label, {super.key, required this.onPressed, this.icon, this.autofocus = false})
    : kind = ButtonStyleKind.primary,
      small = false,
      width = null,
      semanticLabel = null,
      highlighted = false,
      selected = null;

  const AppButton.quiet(this.label, {super.key, required this.onPressed})
    : kind = ButtonStyleKind.quiet,
      small = false,
      icon = null,
      width = null,
      semanticLabel = null,
      highlighted = false,
      selected = null,
      autofocus = false;

  final String label;
  final VoidCallback? onPressed;
  final ButtonStyleKind kind;
  final bool small;
  final IconData? icon;
  final double? width;
  final String? semanticLabel;

  /// Akzentfarbener Rand, z. B. wenn man bereit ist.
  final bool highlighted;
  final bool? selected;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    var (background, border, foreground) = switch (kind) {
      ButtonStyleKind.plain => (p.surface, p.line, p.text),
      ButtonStyleKind.primary => (p.accent, p.accent, p.onAccent),
      ButtonStyleKind.quiet => (Colors.transparent, Colors.transparent, p.muted),
      ButtonStyleKind.danger => (dangerColor, dangerBorder, Colors.white),
    };
    if (highlighted) (border, foreground) = (p.accent, p.accent);
    final danger = kind == ButtonStyleKind.danger;
    final size = small
        ? 15.0
        : danger
        ? 22.0
        : 17.0;
    final style = TextStyle(
      color: foreground,
      fontWeight: FontWeight.w700,
      fontSize: width != null ? 20 : size,
      height: 1.3,
      decoration: kind == ButtonStyleKind.quiet ? TextDecoration.underline : null,
      decorationColor: foreground,
    );

    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Pressable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        selected: selected,
        autofocus: autofocus,
        child: Container(
          width: width,
          constraints: BoxConstraints(
            minHeight: small
                ? 40
                : danger
                ? 72
                : 52,
          ),
          padding: width != null
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(horizontal: small ? 14 : 20, vertical: small ? 6 : 10),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (icon != null) Icon(icon, color: foreground, size: size + 3),
                Flexible(
                  child: Text(label, style: style, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unterstrichener Link in Fußzeile und Rechtstexten.
class LinkText extends StatelessWidget {
  const LinkText(this.label, {super.key, required this.onTap, this.color, this.size});

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.palette.accent;
    return Semantics(
      link: true,
      child: Pressable(
        radius: 2,
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(color: tint, fontSize: size, decoration: TextDecoration.underline, decorationColor: tint),
        ),
      ),
    );
  }
}

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

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: display(48, color: context.palette.text, letterSpacing: 0.5)),
  );
}

/// Kleine Überschrift in Akzentfarbe, z. B. „WERWOLF“.
class GameLabel extends StatelessWidget {
  const GameLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    semanticsLabel: text,
    style: TextStyle(color: context.palette.accent, fontWeight: FontWeight.w700, fontSize: 14.4, letterSpacing: 0.9),
  );
}

class Lead extends StatelessWidget {
  const Lead(this.text, {super.key}) : parts = null;
  const Lead.rich(List<Object> this.parts, {super.key}) : text = null;

  final String? text;
  final List<Object>? parts;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: RichLine(parts ?? [text!], style: TextStyle(color: context.palette.muted)),
    ),
  );
}

/// Fett gesetzter Teil in einer [RichLine].
class Strong {
  const Strong(this.text);
  final String text;
}

/// Text aus normalen (String) und fetten ([Strong]) Teilen. Namen werden so nie als Markup gelesen.
class RichLine extends StatelessWidget {
  const RichLine(this.parts, {super.key, this.style, this.textAlign});

  final List<Object> parts;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final part in parts)
          part is Strong
              ? TextSpan(
                  text: part.text,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : TextSpan(text: part as String),
      ],
    ),
    style: style,
    textAlign: textAlign,
  );
}

/// Überschrift mit Kopfzeile, Titel und Erklärung.
class PhaseHead extends StatelessWidget {
  const PhaseHead({super.key, this.label, required this.title, this.lead, this.leadParts});

  final String? label;
  final String title;
  final String? lead;
  final List<Object>? leadParts;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: GameLabel(label!)),
      ScreenTitle(title),
      if (lead != null || leadParts != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: leadParts != null ? Lead.rich(leadParts!) : Lead(lead!)),
    ],
  );
}

class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.textAlign}) : parts = null;
  const Hint.rich(List<Object> this.parts, {super.key}) : text = null, textAlign = null;

  final String? text;
  final List<Object>? parts;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => RichLine(
    parts ?? [text!],
    textAlign: textAlign,
    style: TextStyle(color: context.palette.muted, fontSize: 15),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.count, this.size = 16});

  final String text;
  final String? count;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (count != null)
            TextSpan(
              text: ' $count',
              style: TextStyle(color: context.palette.muted, fontWeight: FontWeight.w400),
            ),
        ],
      ),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w700),
    ),
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

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    this.label,
    required this.controller,
    required this.hint,
    required this.maxLength,
    this.semanticLabel,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.formatters = const [],
    this.capitalization = TextCapitalization.none,
    this.autofillHints,
    this.style,
    this.dense = false,
  });

  final String? label;
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter> formatters;
  final TextCapitalization capitalization;
  final Iterable<String>? autofillHints;
  final TextStyle? style;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
    final field = Semantics(
      label: semanticLabel ?? label,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        textCapitalization: capitalization,
        autofillHints: autofillHints,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [...formatters, LengthLimitingTextInputFormatter(maxLength)],
        style: style ?? TextStyle(color: p.text, fontSize: 18),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: p.surface,
          hoverColor: Colors.transparent,
          hintText: hint,
          hintStyle: (style ?? const TextStyle(fontSize: 18)).copyWith(color: p.muted.withValues(alpha: 0.7)),
          contentPadding: EdgeInsets.symmetric(horizontal: dense ? 12 : 14, vertical: dense ? 10 : 15),
          enabledBorder: border(p.line, 2),
          focusedBorder: border(p.accent, 3),
        ),
      ),
    );
    if (label == null) return field;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        ExcludeSemantics(
          child: Text(label!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        field,
      ],
    );
  }
}

class AppCheck extends StatefulWidget {
  const AppCheck({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.description,
    this.bold = true,
  });

  final bool value;

  /// null = gesperrt.
  final ValueChanged<bool>? onChanged;
  final String label;

  /// Zweite Zeile, z. B. was eine Rolle kann.
  final String? description;
  final bool bold;

  @override
  State<AppCheck> createState() => _AppCheckState();
}

class _AppCheckState extends State<AppCheck> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onChanged != null;
    final description = widget.description;
    void toggle() => widget.onChanged?.call(!widget.value);

    final box = FocusRing(
      show: _focused,
      radius: 4,
      child: Container(
        width: 21,
        height: 21,
        decoration: BoxDecoration(
          color: widget.value ? p.accent : p.surface,
          border: Border.all(color: widget.value ? p.accent : p.muted, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: widget.value ? Icon(Icons.check, size: 17, color: p.onAccent) : null,
      ),
    );

    return MergeSemantics(
      child: Semantics(
        checked: widget.value,
        enabled: enabled,
        onTap: enabled ? toggle : null,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => toggle())},
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: enabled ? toggle : null,
            child: Row(
              crossAxisAlignment: description == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Opacity(
                  opacity: enabled ? 1 : 0.5,
                  child: Padding(
                    padding: EdgeInsets.only(top: description == null ? 0 : 2),
                    child: box,
                  ),
                ),
                Expanded(
                  child: Opacity(
                    opacity: enabled ? 1 : 0.7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontWeight: widget.bold || description != null ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        if (description != null)
                          Text(description, style: TextStyle(color: p.muted, fontSize: 15, height: 1.35)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zahl mit Minus- und Plus-Knopf.
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onStep,
    this.lessLabel,
    this.moreLabel,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onStep;
  final String? lessLabel;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) => Row(
    spacing: 8,
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      AppButton(
        '−',
        small: true,
        width: 44,
        semanticLabel: lessLabel ?? '$label verringern',
        onPressed: value <= min ? null : () => onStep(-1),
      ),
      Semantics(
        liveRegion: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 28),
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
        ),
      ),
      AppButton(
        '+',
        small: true,
        width: 44,
        semanticLabel: moreLabel ?? '$label erhöhen',
        onPressed: value >= max ? null : () => onStep(1),
      ),
    ],
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

/// Titel im Browser-Tab. Wird neu gesetzt, sobald die Seite wieder vorne liegt.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.isCurrentOf(context) ?? true) {
      SystemChrome.setApplicationSwitcherDescription(
        ApplicationSwitcherDescription(label: title, primaryColor: context.palette.bg.toARGB32()),
      );
    }
    return child;
  }
}
