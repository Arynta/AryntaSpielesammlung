import 'package:shared_preferences/shared_preferences.dart';

import 'storage_base.dart';

Future<Storage> openStorage() async => _PreferencesStorage(
  await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()),
);

class _PreferencesStorage extends Storage {
  _PreferencesStorage(this._preferences);
  final SharedPreferencesWithCache _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  void write(String key, String? value) {
    if (value == null) {
      _preferences.remove(key);
    } else {
      _preferences.setString(key, value);
    }
  }
}
