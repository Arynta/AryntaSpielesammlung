// Eingaben: Textfeld, Häkchen und Zahl mit Plus und Minus.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../themes/theme.dart';
import 'buttons.dart';

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
        semanticLabel: lessLabel ?? texts.stepperLess(label),
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
        semanticLabel: moreLabel ?? texts.stepperMore(label),
        onPressed: value >= max ? null : () => onStep(1),
      ),
    ],
  );
}
