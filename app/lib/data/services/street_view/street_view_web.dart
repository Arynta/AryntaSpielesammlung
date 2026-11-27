// Straßenbild im Browser: Google Street View oder Mapillary, je nachdem, was der Server für die Runde gewählt hat.
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import 'google/google_viewer.dart';
import 'mapillary_viewer.dart';
import 'street_view_controller.dart';
import 'viewer.dart';

/// Straßenbild zum Herumlaufen ab [start]. Ist [focus] gesetzt, zeigt es genau diese gemeldete Ansicht.
/// Wird [focus] wieder null, geht es dorthin zurück, wo man vorher war.
class StreetView extends StatefulWidget {
  const StreetView({super.key, required this.source, required this.start, this.focus, this.controller});

  final StreetViewSource source;
  final ({double lat, double lng}) start;
  final GeoBingoSpot? focus;
  final StreetViewController? controller;

  @override
  State<StreetView> createState() => _StreetViewState();
}

class _StreetViewState extends State<StreetView> {
  late final Viewer _viewer = switch (widget.source) {
    StreetViewSource.google => GoogleViewer(),
    StreetViewSource.mapillary => MapillaryViewer(),
  };
  var _opened = false;
  String? _problem;

  /// Sprünge nacheinander ausführen, sonst überholt ein später Sprung einen früheren, der noch lädt.
  Future<void> _steps = Future.value();

  @override
  void didUpdateWidget(StreetView old) {
    super.didUpdateWidget(old);
    if (_opened && old.focus != widget.focus) _focus(widget.focus);
  }

  @override
  void dispose() {
    widget.controller?.attach(null);
    _viewer.close();
    super.dispose();
  }

  void _focus(GeoBingoSpot? spot) {
    _steps = _steps
        .then((_) => spot == null ? _viewer.back() : _viewer.show(spot))
        .catchError((Object e) => debugPrint('Straßenbild: $e'));
  }

  Future<void> _open(web.HTMLElement container) async {
    // Google setzt im Viewer hohe z-index-Werte. Ohne eigene Ebene malen die sich über alles, was Flutter
    // darüberlegt (Uhr, Bingo-Karte, Abstimmung).
    container.style.isolation = 'isolate';
    try {
      await _viewer.open(container, widget.start);
      if (!mounted) {
        _viewer.close();
        return;
      }
      _opened = true;
      widget.controller?.attach(_viewer.read);
      if (widget.focus != null) _focus(widget.focus);
    } on StreetViewProblem catch (e) {
      if (mounted) setState(() => _problem = e.message);
    } catch (e) {
      if (mounted) setState(() => _problem = texts.streetViewLoadFailed);
      debugPrint('Straßenbild: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    if (problem != null) return Center(child: Text(problem, textAlign: TextAlign.center));
    // Die Viewer messen ihren Platz nur beim Start, also bei jeder Größenänderung neu messen lassen
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _viewer.resize());
        return HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: (element) => _open(element as web.HTMLElement),
        );
      },
    );
  }
}
