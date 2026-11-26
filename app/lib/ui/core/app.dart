// Rahmen der App: Farben je nach Spielphase, Seiten und die Wahl der Ansicht.
import 'package:material_ui/material_ui.dart';

import 'view_model/app_controller.dart';
import '../../data/services/connection.dart';
import '../../data/repositories/game_data.dart';
import '../local/view_model/local_controller.dart';
import '../../domain/models/models.dart';
import '../games/widgets/buzzer.dart';
import '../games/widgets/impostor.dart';
import '../games/widgets/nobody_is_perfect.dart';
import '../games/widgets/tabu.dart';
import '../games/widgets/werwolf.dart';
import '../home/widgets/home.dart';
import '../legal/widgets/legal.dart';
import '../lobby/widgets/lobby.dart';
import '../local/widgets/local.dart';
import 'widgets/showcase.dart';
import 'themes/theme.dart';
import 'widgets/widgets.dart';
import 'app_frame.dart';
import 'confirm_dialog.dart';

export 'app_frame.dart';
export 'confirm_dialog.dart';

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
      barrierColor: const Color(0xA6140A0B),
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
                    ? StatusBar(controller.status)
                    : const SizedBox.shrink(),
                Expanded(child: _isShowcase ? _showcase(context, padding) : _narrow(context, padding)),
              ],
            ),
            if (toast != null)
              Positioned(left: 16, right: 16, bottom: padding.bottom > 16 ? padding.bottom : 16, child: Toast(toast)),
          ],
        ),
      );
    },
  );

  Widget _narrow(BuildContext context, EdgeInsets padding) => SingleChildScrollView(
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
          children: [..._body(context), Footer(controller)],
        ),
      ),
    ),
  );

  /// Start, Lokal-Einrichtung und Lobby nutzen die ganze Breite.
  bool get _isShowcase {
    final local = controller.local;
    if (local != null) return local.stage == Stage.setup;
    final room = controller.room;
    return room == null ? controller.session == null : room.phase == Phase.lobby;
  }

  Widget _showcase(BuildContext context, EdgeInsets padding) {
    final side = (MediaQuery.sizeOf(context).width * 0.04).clamp(16.0, 56.0);
    final atStart = controller.room == null;
    final local = controller.local;
    final room = controller.room;
    // Startbild, sonst das Bild des gewählten Spiels
    final backdrop = local != null
        ? gameHeroes[local.setup.game]
        : room != null
        ? gameHeroes[room.game]
        : controller.session == null
        ? homeImage
        : null;
    return DecoratedBox(
      decoration: showcaseBackground,
      child: CustomScrollView(
        slivers: [
          // Das große Bild reicht bis an den Rand, deshalb liegt der Abstand erst um den Inhalt
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ?backdrop == null ? null : ShowcaseBackdrop(backdrop),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    side + padding.left,
                    padding.top > 20 ? padding.top : 20,
                    side + padding.right,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: [
                      ShowcaseBar(
                        online: controller.status == ConnectionStatus.online,
                        tabs: atStart ? const ['Multiplayer', 'Lokal'] : const [],
                        selectedTab: controller.local == null ? 0 : 1,
                        onTab: (tab) => tab == 1 ? controller.openLocal() : controller.local?.quit(),
                      ),
                      ..._body(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bei wenig Inhalt rutscht der Fuß an den unteren Rand des Fensters
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                side + padding.left,
                24,
                side + padding.right,
                padding.bottom > 32 ? padding.bottom : 32,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(width: double.infinity, child: Footer(controller)),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
