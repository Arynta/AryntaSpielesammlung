// Suche nach dem nächsten Google-Panorama über die Metadaten-Suche (bei Google kostenlos und ohne
// Kontingent). Der kostenpflichtige StreetViewService wird bewusst nicht genutzt.
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../../domain/models/models.dart';
import 'maps_api.dart';

typedef Pano = ({String id, double lat, double lng});

/// Nächstes Panorama aus Googles eigenen Aufnahmen, der Reihe nach in den Abständen [radii] (Meter).
///
/// Die Suche liefert auch 360°-Fotos von Privatleuten. Die sind Einzelbilder ohne Wege, man könnte dort
/// nicht laufen. Deshalb zählt nur ein Treffer mit „Google“ im Copyright. Liegt am Ort ein privates
/// Foto, wird ringsum im selben Abstand weitergesucht, alle Punkte eines Rings gleichzeitig.
/// null, wenn es im größten Abstand keine Google-Aufnahme gibt.
Future<Pano?> findGooglePano(double lat, double lng, List<int> radii) async {
  for (final radius in radii) {
    final ring = [
      (lat: lat, lng: lng),
      for (var i = 0; i < 8; i++) _offset(lat, lng, metres: radius.toDouble(), angle: i * pi / 4),
    ];
    final found = await Future.wait([for (final p in ring) _lookup(p.lat, p.lng, radius)]);
    final hit = found.nonNulls.firstOrNull;
    if (hit != null) return hit;
  }
  return null;
}

/// Ein Punkt [metres] vom Ort entfernt in Richtung [angle] (0 = Norden).
({double lat, double lng}) _offset(double lat, double lng, {required double metres, required double angle}) {
  const metresPerDegree = 111320.0;
  return (
    lat: lat + metres * cos(angle) / metresPerDegree,
    lng: lng + metres * sin(angle) / (metresPerDegree * cos(lat * pi / 180)),
  );
}

/// Eine Metadaten-Anfrage. null bei keinem Treffer oder einem privaten Foto.
Future<Pano?> _lookup(double lat, double lng, int radius) async {
  final uri = Uri.https('maps.googleapis.com', '/maps/api/streetview/metadata', {
    'location': '$lat,$lng',
    'radius': '$radius',
    'source': 'outdoor',
    'key': googleMapsKey,
  });
  final body = jsonDecode((await http.get(uri)).body) as Json;
  final status = body['status'];
  if (status == 'ZERO_RESULTS') return null;
  if (status != 'OK') {
    throw http.ClientException('Google antwortet mit $status: ${body['error_message'] ?? ''}', uri);
  }
  if (!'${body['copyright'] ?? ''}'.contains('Google')) return null;
  final location = body['location'] as Json?;
  return (
    id: body['pano_id'] as String,
    lat: (location?['lat'] as num?)?.toDouble() ?? lat,
    lng: (location?['lng'] as num?)?.toDouble() ?? lng,
  );
}
