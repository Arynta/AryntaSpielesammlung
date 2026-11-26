// Gemeinsamer Aufbau der Rechtstexte: Seite, Abschnitte, Text mit Links, Aufzählungen.
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/services/device/device.dart' as device;
import '../../core/themes/theme.dart';
import '../../core/widgets/widgets.dart';

const _mail = 'temp@test.com';

const impressumRoute = '/impressum';
const datenschutzRoute = '/datenschutz';

/// Gemeinsamer Rahmen beider Seiten.
class LegalScaffold extends StatelessWidget {
  const LegalScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: duskTheme,
    child: PageTitle(
      '$title · Arynta',
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: SelectionArea(
                  child: Gap(
                    spacing: 20,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Builder(
                          builder: (context) => LinkText(
                            'Zurück zum Spiel',
                            onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          ),
                        ),
                      ),
                      ScreenTitle(title),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LegalSection extends StatelessWidget {
  const LegalSection(this.title, this.children, {super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Gap(spacing: 12, children: [SectionTitle(title, size: 18.4), ...children]);
}

/// Ein Stück Text mit Link.
class LegalLink {
  const LegalLink(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
}

/// Absatz aus normalem Text, [Strong] und [LegalLink].
class LegalText extends StatefulWidget {
  const LegalText(this.parts, {super.key});

  final List<Object> parts;

  @override
  State<LegalText> createState() => _TextState();
}

class _TextState extends State<LegalText> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clear() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final accent = context.palette.accent;
    return Text.rich(
      TextSpan(
        children: [
          for (final part in widget.parts)
            switch (part) {
              Strong(:final text) => TextSpan(
                text: text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              LegalLink(:final text, :final onTap) => TextSpan(
                text: text,
                style: TextStyle(color: accent, decoration: TextDecoration.underline, decorationColor: accent),
                recognizer: _recognizers.addAndReturn(TapGestureRecognizer()..onTap = onTap),
                mouseCursor: SystemMouseCursors.click,
              ),
              _ => TextSpan(text: part as String),
            },
        ],
      ),
    );
  }
}

extension on List<TapGestureRecognizer> {
  TapGestureRecognizer addAndReturn(TapGestureRecognizer recognizer) {
    add(recognizer);
    return recognizer;
  }
}

class LegalBullets extends StatelessWidget {
  const LegalBullets(this.items, {super.key});

  final List<List<Object>> items;

  @override
  Widget build(BuildContext context) => Gap(
    spacing: 6,
    children: [
      for (final item in items)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 20, child: Text('•')),
            Expanded(child: LegalText(item)),
          ],
        ),
    ],
  );
}

LegalLink mailLink(BuildContext context) => LegalLink(_mail, () async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await device.writeMail(_mail)) {
    messenger.showSnackBar(const SnackBar(content: Text('E-Mail-Adresse kopiert')));
  }
});
