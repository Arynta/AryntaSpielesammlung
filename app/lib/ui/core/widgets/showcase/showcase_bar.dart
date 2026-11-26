// Kopfleiste mit Tabs, Sprache, Verbindung und Uhr.
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';
import '../../themes/theme.dart';
import '../widgets.dart';

class ShowcaseBar extends StatelessWidget {
  const ShowcaseBar({
    super.key,
    required this.online,
    this.language,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTab,
  });

  final bool online;

  /// Sprachumschalter links neben dem Verbindungssymbol.
  final Widget? language;
  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTab;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: 8,
        children: [
          if (constraints.maxWidth >= 420)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text('Arynta', style: display(22, color: p.muted, letterSpacing: 1)),
            ),
          for (final (index, label) in tabs.indexed)
            _TabPill(label, selected: index == selectedTab, onPressed: () => onTab?.call(index)),
          const Spacer(),
          ?language,
          // Auf sehr schmalen Handys reicht der Platz neben der Flagge nicht. Offline zeigt es dann die Statuszeile.
          if (constraints.maxWidth >= 360)
            Icon(
              online ? Icons.wifi : Icons.wifi_off,
              color: online ? const Color(0xFF3DDC84) : p.muted,
              size: 24,
              semanticLabel: online ? texts.serverOnline : texts.serverOffline,
            ),
          if (constraints.maxWidth >= 560) const Padding(padding: EdgeInsets.only(left: 12), child: _Clock()),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill(this.label, {required this.selected, required this.onPressed});

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Pressable(
    radius: 20,
    selected: selected,
    onPressed: selected ? null : onPressed,
    child: AnimatedContainer(
      duration: context.motion(200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: selected ? Colors.black : Colors.white),
      ),
    ),
  );
}

class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return ExcludeSemantics(
      child: Text('${two(now.hour)}:${two(now.minute)}', style: const TextStyle(fontSize: 22, color: Colors.white)),
    );
  }
}
