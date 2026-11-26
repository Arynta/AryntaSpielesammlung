// Rahmen der App: Farben je nach Spielphase, Seiten, Statuszeile, Meldungen und Rückfragen.
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/app_controller.dart';
import '../logic/connection.dart';
import '../logic/models.dart';
import 'games/buzzer.dart';
import 'games/impostor.dart';
import 'games/nobody_is_perfect.dart';
import 'games/tabu.dart';
import 'games/werwolf.dart';
import 'home.dart';
import 'legal.dart';
import 'lobby.dart';
import 'local.dart';
import 'theme.dart';
import 'widgets.dart';

class AryntaApp extends StatefulWidget {
  const AryntaApp(this.controller, {super.key});

  final AppController controller;

  @override
  State<AryntaApp> createState() => _AryntaAppState();
}

class _AryntaAppState extends State<AryntaApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.confirm = _confirm;
    _lifecycle = AppLifecycleListener(onResume: controller.resume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String question, String yesLabel) async {
    final context = _navigator.currentState?.overlay?.context;
    if (context == null) return false;
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xA60A0814),
      builder: (_) => ConfirmDialog(question: question, yesLabel: yesLabel),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Arynta',
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: duskTheme,
    builder: (context, child) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AnimatedTheme(
        data: themeFor(controller.local == null ? controller.room?.phase : null),
        duration: context.motion(700),
        child: child!,
      ),
    ),
    routes: {
      '/': (_) => GameScreen(controller),
      impressumRoute: (_) => const ImpressumScreen(),
      datenschutzRoute: (_) => const DatenschutzScreen(),
    },
  );
}

class GameScreen extends StatelessWidget {
  const GameScreen(this.controller, {super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) => PageTitle('Arynta', child: _screen());

  Widget _screen() => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final padding = MediaQuery.paddingOf(context);
      final toast = controller.toast;
      return Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                // Der Platz bleibt immer an derselben Stelle, damit darunter nichts neu aufgebaut wird
                controller.local == null && controller.status != ConnectionStatus.online
                    ? _StatusBar(controller.status)
                    : const SizedBox.shrink(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16 + padding.left,
                      padding.top > 24 ? padding.top : 24,
                      16 + padding.right,
                      padding.bottom > 32 ? padding.bottom : 32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 448),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 20,
                          children: [..._body(context), _Footer(controller)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (toast != null)
              Positioned(left: 16, right: 16, bottom: padding.bottom > 16 ? padding.bottom : 16, child: _Toast(toast)),
          ],
        ),
      );
    },
  );

  List<Widget> _body(BuildContext context) {
    final local = controller.local;
    if (local != null) return localView(context, local);
    final room = controller.room;
    if (room == null) {
      return controller.session != null ? reconnectingView(controller) : homeView(context, controller);
    }
    if (room.phase == Phase.lobby) return lobbyView(context, controller, room);
    if (room.werwolf case final werwolf?) return werwolfView(controller, room, werwolf);
    if (room.tabu case final tabu?) return tabuView(controller, room, tabu);
    if (room.nobodyIsPerfect case final game?) return nobodyIsPerfectView(controller, room, game);
    if (room.buzzer case final buzzer?) return buzzerView(controller, room, buzzer);
    if (room.impostor case final impostor?) return impostorView(controller, room, impostor);
    return lobbyView(context, controller, room);
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar(this.status);

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

class _Toast extends StatelessWidget {
  const _Toast(this.text);

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

class _Footer extends StatelessWidget {
  const _Footer(this.controller);

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
