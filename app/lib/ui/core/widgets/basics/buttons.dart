// Knöpfe und alles, was man antippen kann.
import 'package:material_ui/material_ui.dart';

import '../../themes/theme.dart';

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
