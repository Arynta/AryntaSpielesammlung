// Statuszeile, Meldungen und Fußzeile.
import 'package:material_ui/material_ui.dart';

import 'view_model/app_controller.dart';
import '../../data/services/connection.dart';
import '../legal/widgets/legal.dart';
import 'themes/theme.dart';
import 'widgets/widgets.dart';

class StatusBar extends StatelessWidget {
  const StatusBar(this.status, {super.key});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: p.accent,
        padding: EdgeInsets.fromLTRB(16, 11 + MediaQuery.paddingOf(context).top, 16, 11),
        child: Text(
          status == ConnectionStatus.waking
              ? 'Der Server wird geweckt. Beim ersten Aufruf kann das bis zu einer Minute dauern.'
              : 'Verbindung unterbrochen. Ich verbinde neu …',
          textAlign: TextAlign.center,
          style: TextStyle(color: p.onAccent, fontSize: 15),
        ),
      ),
    );
  }
}

class Toast extends StatelessWidget {
  const Toast(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 448),
        child: Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(10)),
            child: Text(
              text,
              style: TextStyle(color: p.bg, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer(this.controller, {super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget link(String label, VoidCallback onTap) => LinkText(label, onTap: onTap, color: p.muted, size: 15);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 4,
        children: [
          link('Impressum', () => Navigator.of(context).pushNamed(impressumRoute)),
          link('Datenschutz', () => Navigator.of(context).pushNamed(datenschutzRoute)),
          link('Meine Daten löschen', controller.forgetDevice),
        ],
      ),
    );
  }
}
