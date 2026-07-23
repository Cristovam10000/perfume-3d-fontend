import 'package:shared_preferences/shared_preferences.dart';

abstract class SalesOfflineStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SharedPreferencesSalesOfflineStore implements SalesOfflineStore {
  static const _key = 'perfume_3d_sales_offline_v1';

  @override
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, value);
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}
