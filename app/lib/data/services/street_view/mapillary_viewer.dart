// Mapillary-Viewer im Browser. Die Bibliothek liegt in web/mapillary/ und wird erst geladen,
// wenn jemand Geo-Bingo spielt, damit die übrigen Spiele nichts davon mitladen.
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../../../domain/models/models.dart';
import '../../../l10n/l10n.dart';
import 'viewer.dart';

/// Öffentlicher Client-Schlüssel von mapillary.com/developer: --dart-define=MAPILLARY_TOKEN=MLY|…
const _token = String.fromEnvironment('MAPILLARY_TOKEN');

/// Suchradien in Grad um den Startort. Erst eng, damit alle nah beieinander starten.
const _searchRadii = [0.002, 0.006, 0.02];

@JS('mapillary.Viewer')
extension type _Viewer._(JSObject _) implements JSObject {
  external factory _Viewer(JSObject options);
  external JSPromise<JSAny?> moveTo(String imageId);
  external JSPromise<_Image> getImage();
  external JSPromise<JSArray<JSNumber>> getCenter();
  external JSPromise<JSNumber> getZoom();
  external void setCenter(JSArray<JSNumber> center);
  external void setZoom(double zoom);
  external void resize();
  external void remove();
}

extension type _Image._(JSObject _) implements JSObject {
  external String get id;
}

Future<void>? _library;

Future<void> _loadLibrary() => _library ??= () async {
  final css = web.HTMLLinkElement()
    ..rel = 'stylesheet'
    ..href = 'mapillary/mapillary.css';
  final script = web.HTMLScriptElement()..src = 'mapillary/mapillary.js';
  web.document.head!
    ..append(css)
    ..append(script);
  await script.onLoad.first;
}();

/// Erstes Bild nahe am Startort, Panoramen bevorzugt. null, wenn es dort keine Bilder gibt.
Future<String?> _findImage(double lat, double lng) async {
  for (final pano in [true, false]) {
    for (final r in _searchRadii) {
      final uri = Uri.https('graph.mapillary.com', '/images', {
        'access_token': _token,
        'fields': 'id',
        'limit': '1',
        'bbox': '${lng - r},${lat - r},${lng + r},${lat + r}',
        if (pano) 'is_pano': 'true',
      });
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw http.ClientException('Mapillary antwortet mit ${response.statusCode}', uri);
      }
      final images = (jsonDecode(response.body) as Json)['data'] as List;
      if (images.isNotEmpty) return (images.first as Json)['id'] as String;
    }
  }
  return null;
}

/// Mapillary kostet nichts, deshalb bekommt jeder Rahmen seinen eigenen Viewer.
class MapillaryViewer implements Viewer {
  _Viewer? _viewer;
  GeoBingoSpot? _home;

  @override
  Future<void> open(web.HTMLElement container, ({double lat, double lng}) start) async {
    if (_token.isEmpty) throw StreetViewProblem(texts.streetViewNoToken);
    await _loadLibrary();
    final imageId = await _findImage(start.lat, start.lng);
    if (imageId == null) throw StreetViewProblem(texts.streetViewNoImages);
    final viewer = _Viewer(
      JSObject()
        ..['accessToken'] = _token.toJS
        ..['container'] = container
        // Ohne das liegt erst ein Vorschaubild mit Startknopf über dem Viewer
        ..['component'] = {'cover': false}.jsify(),
    );
    _viewer = viewer;
    await viewer.moveTo(imageId).toDart;
  }

  @override
  Future<void> show(GeoBingoSpot spot) async {
    _home ??= await read();
    await _moveTo(spot);
  }

  @override
  Future<void> back() async {
    final home = _home;
    _home = null;
    if (home != null) await _moveTo(home);
  }

  Future<void> _moveTo(GeoBingoSpot spot) async {
    final viewer = _viewer;
    if (viewer == null) return;
    await viewer.moveTo(spot.imageId).toDart;
    viewer
      ..setCenter([spot.x.toJS, spot.y.toJS].toJS)
      ..setZoom(spot.zoom);
  }

  @override
  Future<GeoBingoSpot?> read() async {
    final viewer = _viewer;
    if (viewer == null) return null;
    final image = await viewer.getImage().toDart;
    final center = (await viewer.getCenter().toDart).toDart;
    final zoom = (await viewer.getZoom().toDart).toDartDouble;
    return GeoBingoSpot(
      imageId: image.id,
      x: center[0].toDartDouble.clamp(0, 1),
      y: center[1].toDartDouble.clamp(0, 1),
      zoom: zoom.clamp(0, 3),
    );
  }

  @override
  void resize() => _viewer?.resize();

  @override
  void close() {
    _viewer?.remove();
    _viewer = null;
  }
}
