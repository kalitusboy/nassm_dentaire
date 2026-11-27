import 'package:shared_preferences/shared_preferences.dart';

enum AppMode { host, client }

class AppConfig {
  static const _kMode = 'app_mode';
  static const _kUrl = 'server_url';
  static const _kSetup = 'setup_done';
  static const _kDefPw = 'default_pw_active';

  /// Compte administrateur créé automatiquement à l'installation.
  static const defaultAdminUser = 'admin';
  static const defaultAdminPass = 'admin123';

  static const int serverPort = 8090;
  static const defaultUrl = 'http://127.0.0.1:$serverPort';

  static AppMode _mode = AppMode.client;
  static String _url = defaultUrl;
  static bool _setupDone = false;
  static bool _defaultPw = false;

  static AppMode get mode => _mode;
  static String get serverUrl => _mode == AppMode.host ? defaultUrl : _url;
  static bool get isHost => _mode == AppMode.host;
  static bool get setupDone => _setupDone;

  /// Vrai tant que le mot de passe par défaut (admin123) n'a pas été changé.
  static bool get defaultPasswordActive => _defaultPw;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _mode = p.getString(_kMode) == 'host' ? AppMode.host : AppMode.client;
    _url = p.getString(_kUrl) ?? defaultUrl;
    _setupDone = p.getBool(_kSetup) ?? false;
    _defaultPw = p.getBool(_kDefPw) ?? false;
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

  static Future<void> setSetupDone(bool v) async {
    _setupDone = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSetup, v);
  }

  static Future<void> setDefaultPasswordActive(bool v) async {
    _defaultPw = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDefPw, v);
  }
}
