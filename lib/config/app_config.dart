import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { host, client }

class AppConfig {
  static const _kMode = 'app_mode';
  static const _kUrl = 'server_url';
  static const defaultUrl = 'http://127.0.0.1:8090';

  static AppMode _mode = AppMode.client;
  static String _url = defaultUrl;

  static AppMode get mode => _mode;
  static String get serverUrl => _url;
  static bool get isHost => _mode == AppMode.host;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _mode = p.getString(_kMode) == 'host' ? AppMode.host : AppMode.client;
    _url = p.getString(_kUrl) ?? defaultUrl;
  }

  static Future<void> setMode(AppMode m) async {
    _mode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMode, m.name);
  }

  static Future<void> setServerUrl(String u) async {
    _url = u;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUrl, u);
  }
}