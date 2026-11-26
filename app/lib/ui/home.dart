// Startseite und Wiedereinstieg.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/app_controller.dart';
import '../logic/connection.dart';
import 'theme.dart';
import 'widgets.dart';

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

List<Widget> homeView(BuildContext context, AppController controller) {
  final p = context.palette;
  final online = controller.status == ConnectionStatus.online;
  Widget or(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(text, style: TextStyle(color: p.muted, fontSize: 15)),
  );

  return [
    const PhaseHead(
      key: ValueKey('home-head'),
      title: 'Arynta',
      lead: 'Spieleabend mit Freunden. Jeder spielt am eigenen Handy, gesprochen wird am Tisch.',
    ),
    AppField(
      key: const ValueKey('name'),
      label: 'Dein Name',
      controller: controller.nameInput,
      focusNode: controller.nameFocus,
      hint: 'z. B. Anna',
      maxLength: 20,
      capitalization: TextCapitalization.words,
      autofillHints: const [AutofillHints.nickname],
      onSubmitted: controller.submitName,
    ),
    AppButton.primary('Neuen Raum erstellen', onPressed: online ? controller.create : null),
    or('oder einem Raum beitreten'),
    Row(
      key: const ValueKey('join'),
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 10,
      children: [
        Expanded(
          child: AppField(
            label: 'Raumcode',
            controller: controller.codeInput,
            hint: 'K7QX',
            maxLength: 4,
            formatters: [_UpperCase()],
            capitalization: TextCapitalization.characters,
            style: display(26, color: p.text, letterSpacing: 6.5),
            dense: true,
            onSubmitted: online ? controller.join : null,
          ),
        ),
        AppButton('Beitreten', onPressed: online ? controller.join : null),
      ],
    ),
    or('oder ohne Internet mit nur einem Handy'),
    AppButton('Lokal spielen', onPressed: controller.openLocal),
  ];
}

List<Widget> reconnectingView(AppController controller) => [
  const ScreenTitle('Arynta'),
  Lead.rich(['Du kommst zurück in Raum ', Strong(controller.session!.code), ' …']),
  AppButton.quiet('Abbrechen', onPressed: controller.leave),
];
