// Rückfrage mit Ja und Nein.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'themes/theme.dart';
import 'widgets/widgets.dart';

/// Ja/Nein-Abfrage im Stil der Seite.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({super.key, required this.question, required this.yesLabel});

  final String question;
  final String yesLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(false)},
      child: Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.line, width: 2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Gap(
              spacing: 20,
              children: [
                Text(question, style: display(26, height: 1.15, color: p.text)),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      // Bei Fragen, die etwas kaputtmachen können, steht der Fokus sicherheitshalber auf "Nein"
                      Expanded(
                        child: AppButton('Nein', autofocus: true, onPressed: () => Navigator.of(context).pop(false)),
                      ),
                      Expanded(child: AppButton.primary(yesLabel, onPressed: () => Navigator.of(context).pop(true))),
                    ],
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
