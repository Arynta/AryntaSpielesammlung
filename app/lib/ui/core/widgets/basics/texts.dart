// Überschriften und Texte.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../themes/theme.dart';

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
