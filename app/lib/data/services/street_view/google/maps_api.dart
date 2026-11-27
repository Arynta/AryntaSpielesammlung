// Anbindung an die Maps JavaScript API: Schlüssel, Laden und die Teile der API, die Geo-Bingo nutzt.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../../../l10n/l10n.dart';

/// Browser-Schlüssel aus der Google Cloud Console: --dart-define=GOOGLE_MAPS_KEY=…
/// Er steht offen in der Seite, deshalb dort auf die eigene Domain sowie die Maps JavaScript API und
/// die Street View Static API (nur für die kostenlose Metadaten-Suche) beschränken.
const googleMapsKey = String.fromEnvironment('GOOGLE_MAPS_KEY');

@JS('google.maps.importLibrary')
external JSPromise<JSObject> _importLibrary(String name);

@JS('google.maps.StreetViewPanorama')
extension type Panorama._(JSObject _) implements JSObject {
  external factory Panorama(web.HTMLElement container, JSObject options);
  external String? getPano();
  external LatLng? getPosition();
  external Pov getPov();
  external double? getZoom();
  external void setOptions(JSObject options);
}

extension type Pov._(JSObject _) implements JSObject {
  external double get heading;
  external double get pitch;
}

@JS('google.maps.Map')
extension type GoogleMap._(JSObject _) implements JSObject {
  external factory GoogleMap(web.HTMLElement container, JSObject options);
  external void panTo(JSObject position);
  external void setOptions(JSObject options);
}

@JS('google.maps.StreetViewCoverageLayer')
extension type CoverageLayer._(JSObject _) implements JSObject {
  external factory CoverageLayer();
  external void setMap(GoogleMap map);
}

extension type LatLng._(JSObject _) implements JSObject {
  external double lat();
  external double lng();
}

extension type MapClick._(JSObject _) implements JSObject {
  external LatLng? get latLng;
}

@JS('google.maps.event.trigger')
external void triggerEvent(JSObject instance, String eventName);

@JS('google.maps.event.addListener')
external JSObject addListener(JSObject instance, String eventName, JSFunction handler);

/// Konstante aus google.maps.ControlPosition, z. B. RIGHT_CENTER.
JSAny? controlPosition(String name) =>
    (((globalContext['google'] as JSObject)['maps'] as JSObject)['ControlPosition'] as JSObject)[name];

JSObject latLngLiteral(double lat, double lng) => {'lat': lat, 'lng': lng}.jsify() as JSObject;

Future<void>? _api;

/// Lädt die API einmal pro Seite, erst wenn jemand Geo-Bingo spielt.
Future<void> loadMapsApi() => _api ??= () async {
  final ready = Completer<void>();
  globalContext['geoBingoGoogleReady'] = (() => ready.complete()).toJS;
  final script = web.HTMLScriptElement()
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': googleMapsKey,
      'v': 'weekly',
      'loading': 'async',
      'callback': 'geoBingoGoogleReady',
      'language': appLanguage.wire,
    }).toString();
  unawaited(
    script.onError.first.then((_) {
      if (!ready.isCompleted) ready.completeError(StateError('Maps JavaScript API lädt nicht'));
    }),
  );
  web.document.head!.append(script);
  try {
    await ready.future;
    await Future.wait([_importLibrary('streetView').toDart, _importLibrary('maps').toDart]);
  } catch (_) {
    // Beim nächsten Versuch neu laden, etwa wenn man nur kurz offline war
    _api = null;
    script.remove();
    rethrow;
  }
}();
