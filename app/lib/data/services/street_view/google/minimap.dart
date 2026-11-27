// Minikarte unten rechts im Google-Viewer (Dynamic Maps, 10.000 Ladungen im Monat frei). Antippen
// vergrößert sie, in der großen Karte springt ein Klick zum nächsten Panorama dort, auch in andere Länder.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../../l10n/l10n.dart';
import 'maps_api.dart';
import 'pano_search.dart';

/// Suchabstände für einen Klick in die Karte. Weit herausgezoomt trifft man selten genau eine Straße.
const _jumpRadii = [50, 500, 5000];

class Minimap {
  /// Legt die Karte in [parent] über das [panorama] und verbindet beide.
  Minimap(web.HTMLElement parent, Panorama panorama, Pano start) : _panorama = panorama {
    parent.append(
      _frame
        ..append(_mapBox)
        ..append(_sizeButton),
    );
    _map = GoogleMap(
      _mapBox,
      JSObject()
        ..['center'] = latLngLiteral(start.lat, start.lng)
        ..['zoom'] = 15.toJS
        ..['disableDefaultUI'] = true.toJS
        // Das Männchen auf die Karte ziehen setzt den Viewer ebenfalls um
        ..['streetViewControl'] = true.toJS
        ..['streetView'] = panorama
        ..['clickableIcons'] = false.toJS
        ..['keyboardShortcuts'] = false.toJS
        ..['gestureHandling'] = 'greedy'.toJS,
    );
    CoverageLayer().setMap(_map);
    shrink();
    addListener(panorama, 'position_changed', _follow.toJS);
    addListener(_map, 'click', _onClick.toJS);
    _sizeButton.onClick.listen((_) => _setLarge(!_large));
  }

  final Panorama _panorama;
  late final GoogleMap _map;
  var _large = false;

  // Eigene Ebene über dem Panorama, das sonst mit seinen z-index-Werten darübermalt
  final _frame = web.HTMLDivElement()
    ..style.cssText =
        'position:absolute;right:10px;bottom:30px;z-index:1;isolation:isolate;overflow:hidden;'
        'border-radius:10px;border:2px solid rgba(255,255,255,.85);box-shadow:0 4px 14px rgba(0,0,0,.45);'
        'transition:width .2s ease,height .2s ease';
  final _mapBox = web.HTMLDivElement()..style.cssText = 'position:absolute;inset:0';
  final _sizeButton = web.HTMLButtonElement()
    ..type = 'button'
    ..style.cssText =
        'position:absolute;top:6px;left:6px;z-index:2;width:32px;height:32px;border:0;border-radius:6px;'
        'background:#fff;color:#333;font-size:18px;line-height:32px;cursor:pointer;'
        'box-shadow:0 1px 4px rgba(0,0,0,.3)';

  void shrink() => _setLarge(false);

  void _setLarge(bool large) {
    _large = large;
    final label = large ? texts.geoBingoMapShrink : texts.geoBingoMapGrow;
    _frame.style
      ..width = large ? 'min(720px, calc(100% - 20px))' : '220px'
      ..height = large ? 'min(480px, calc(100% - 120px))' : '150px';
    _sizeButton
      ..textContent = large ? '⤡' : '⤢'
      ..title = label
      ..ariaLabel = label;
    _map.setOptions(JSObject()..['zoomControl'] = large.toJS);
  }

  void _follow() {
    final position = _panorama.getPosition();
    if (position != null) _map.panTo(position);
  }

  void _onClick(MapClick event) {
    final at = event.latLng;
    if (!_large) {
      _setLarge(true);
    } else if (at != null) {
      unawaited(_jumpTo(at.lat(), at.lng()));
    }
  }

  Future<void> _jumpTo(double lat, double lng) async {
    try {
      final pano = await findGooglePano(lat, lng, _jumpRadii);
      if (pano == null) return;
      _panorama.setOptions(JSObject()..['pano'] = pano.id.toJS);
      shrink();
    } catch (e) {
      web.console.log('Straßenbild: $e'.toJS);
    }
  }
}
