// Google Street View im Browser.
//
// Google rechnet jeden neu erzeugten Viewer ab (Dynamic Street View), Sprünge im selben Viewer dagegen
// nicht. Deshalb gibt es auf der ganzen Seite nur einen, samt Minikarte. Er wandert in den Rahmen der
// neuen Runde und springt dort zur nächsten Stadt, bei Abstimmungen zum Fund und danach zurück. Der
// Server zählt pro Spieler und Raum einen Viewer gegen sein Tageslimit (StreetViewBudget).
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../../domain/models/models.dart';
import '../../../../l10n/l10n.dart';
import '../viewer.dart';
import 'maps_api.dart';
import 'minimap.dart';
import 'pano_search.dart';

/// Suchabstände in Metern um den Startort. Erst eng, damit alle nah beieinander starten.
const _startRadii = [100, 500, 2000];

/// Viewer und Minikarte der Seite. Alles bleibt, bis die Seite neu lädt.
final _holder = web.HTMLDivElement()..style.cssText = 'position:relative;width:100%;height:100%';
Panorama? _panorama;
Minimap? _minimap;

JSObject _view(String pano, {required double heading, required double pitch, required double zoom}) => JSObject()
  ..['pano'] = pano.toJS
  ..['pov'] = {'heading': heading, 'pitch': pitch}.jsify()
  ..['zoom'] = zoom.toJS;

void _create(Pano start) {
  // Eigene Ebene, damit die Minikarte (Ebene 1) darüber liegen kann
  final panoBox = web.HTMLDivElement()..style.cssText = 'position:absolute;inset:0;z-index:0';
  _holder.append(panoBox);
  final panorama = Panorama(
    panoBox,
    _view(start.id, heading: 0, pitch: 0, zoom: 0)
      // Adresse und Vollbild stören im Spiel, Bewegungssensoren drehen ungewollt mit. Die Bedienknöpfe
      // rücken in die Mitte, weil unten rechts die Minikarte liegt.
      ..['addressControl'] = false.toJS
      ..['fullscreenControl'] = false.toJS
      ..['motionTracking'] = false.toJS
      ..['motionTrackingControl'] = false.toJS
      ..['zoomControlOptions'] = (JSObject()..['position'] = controlPosition('RIGHT_CENTER'))
      ..['panControlOptions'] = (JSObject()..['position'] = controlPosition('RIGHT_CENTER')),
  );
  _panorama = panorama;
  _minimap = Minimap(_holder, panorama, start);
}

class GoogleViewer implements Viewer {
  web.HTMLElement? _container;
  GeoBingoSpot? _home;

  @override
  Future<void> open(web.HTMLElement container, ({double lat, double lng}) start) async {
    if (googleMapsKey.isEmpty) throw StreetViewProblem(texts.streetViewNoGoogleKey);
    await loadMapsApi();
    final pano = await findGooglePano(start.lat, start.lng, _startRadii);
    if (pano == null) throw StreetViewProblem(texts.streetViewNoImages);
    _container = container;
    container.append(_holder);
    final panorama = _panorama;
    if (panorama == null) {
      _create(pano);
      return;
    }
    panorama.setOptions(_view(pano.id, heading: 0, pitch: 0, zoom: 0));
    _minimap?.shrink();
    triggerEvent(panorama, 'resize');
  }

  @override
  Future<void> show(GeoBingoSpot spot) async {
    _home ??= await read();
    _apply(spot);
  }

  @override
  Future<void> back() async {
    final home = _home;
    _home = null;
    if (home != null) _apply(home);
  }

  void _apply(GeoBingoSpot spot) =>
      _panorama?.setOptions(_view(spot.imageId, heading: spot.x * 360, pitch: spot.y * 180 - 90, zoom: spot.zoom));

  /// Himmelsrichtung 0 bis 360° und Blick -90 bis 90° auf 0 bis 1 umgerechnet, wie es der Server erwartet.
  @override
  Future<GeoBingoSpot?> read() async {
    final panorama = _panorama;
    final pano = panorama?.getPano();
    if (panorama == null || pano == null || _container == null) return null;
    final pov = panorama.getPov();
    return GeoBingoSpot(
      imageId: pano,
      x: pov.heading % 360 / 360,
      y: ((pov.pitch + 90) / 180).clamp(0, 1),
      zoom: (panorama.getZoom() ?? 0).clamp(0, 3),
    );
  }

  @override
  void resize() {
    final panorama = _panorama;
    if (panorama != null && _container != null) triggerEvent(panorama, 'resize');
  }

  /// Viewer und Karte bleiben für die nächste Runde, sie werden nur aus dem alten Rahmen genommen.
  @override
  void close() {
    final container = _container;
    if (container != null && _holder.parentNode == container) _holder.remove();
    _container = null;
  }
}
