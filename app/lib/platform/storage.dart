// Kleine Werte, die das Gerät behalten soll. Im Browser direkt in localStorage, unter denselben
// Schlüsseln wie die bisherige Webseite, in der App in den Einstellungen des Systems.
export 'storage_base.dart';
export 'storage_io.dart' if (dart.library.js_interop) 'storage_web.dart';
