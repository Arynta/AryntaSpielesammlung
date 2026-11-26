import 'package:web/web.dart' as web;

import 'storage_base.dart';

Future<Storage> openStorage() async => _BrowserStorage();

class _BrowserStorage extends Storage {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String? value) {
    try {
      if (value == null) {
        web.window.localStorage.removeItem(key);
      } else {
        web.window.localStorage.setItem(key, value);
      }
    } catch (_) {
      // privater Modus o. ä. Dann klappt nur das Wiedereinsteigen nach Neuladen nicht.
    }
  }
}
