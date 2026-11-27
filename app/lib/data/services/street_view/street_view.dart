// Straßenbilder für Geo-Bingo von Google Street View oder Mapillary, je nachdem, was der Server für die
// Runde wählt. Die Viewer gibt es nur im Browser, sonst steht dort ein Hinweis.
export 'pointer_shield_io.dart' if (dart.library.js_interop) 'pointer_shield_web.dart';
export 'street_view_controller.dart';
export 'street_view_io.dart' if (dart.library.js_interop) 'street_view_web.dart';
