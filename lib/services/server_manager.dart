import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';

/// Lance et arrête PocketBase automatiquement (mode « poste principal »).
///
/// L'utilisateur n'a jamais à toucher à PocketBase : l'exécutable est livré
/// avec l'application (renommé `dental_db.exe`), les données sont stockées
/// dans le dossier de l'application et un compte administrateur interne est
/// créé automatiquement avec un mot de passe aléatoire.
class ServerManager {
  ServerManager._();
  static final ServerManager instance = ServerManager._();

  static const exeName = 'dental_db.exe';
  static const adminEmail = 'admin@clinic.local';

  Process? _proc;
  final List<String> _log = [];
  String? _dataRoot;
  String? _adminPass;

  String get logTail => _log.join('\n');
  String get adminPass => _adminPass ?? '';
  bool get supported => Platform.isWindows;

  /// Teste si un serveur PocketBase répond à cette adresse.
  static Future<bool> ping(String url) async {
    try {
      final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final r = await http
          .get(Uri.parse('$base/api/health'))
          .timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── Dossiers ─────────────────────────
  Future<String> dataRoot() async {
    if (_dataRoot != null) return _dataRoot!;
    final d = await getApplicationSupportDirectory();
    final dir = Directory('${d.path}${Platform.pathSeparator}database');
    await dir.create(recursive: true);
    return _dataRoot = dir.path;
  }

  Future<String> pbDataDir() async =>
      '${await dataRoot()}${Platform.pathSeparator}pb_data';

  Future<String> backupsDir() async =>
      '${await pbDataDir()}${Platform.pathSeparator}backups';

  /// Cherche l'exécutable PocketBase à côté de l'application.
  File? _findExe() {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    final sep = Platform.pathSeparator;
    final candidates = [
      '$appDir$sep$exeName',
      '$appDir${sep}pocketbase$sep$exeName',
      '$appDir${sep}pocketbase.exe', // mode développement
      '${Directory.current.path}${sep}pocketbase${sep}pocketbase.exe',
    ];
    for (final c in candidates) {
      final f = File(c);
      if (f.existsSync()) return f;
    }
    return null;
  }

  // ───────────────────────── État ─────────────────────────
  Future<bool> isHealthy() => ping(AppConfig.defaultUrl);

  Future<bool> waitUntilHealthy({int seconds = 30}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      if (await isHealthy()) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  // ───────────────────────── Compte admin interne ─────────────────────────
  Future<File> _credFile() async =>
      File('${await dataRoot()}${Platform.pathSeparator}internal.json');

  static String _randomPassword() {
    const chars =
        'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(28, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _ensureAdminAccount(File exe) async {
    final cred = await _credFile();
    if (cred.existsSync()) {
      try {
        final j = jsonDecode(await cred.readAsString());
        _adminPass = j['admin_password'] as String?;
      } catch (_) {}
      if (_adminPass != null && _adminPass!.isNotEmpty) return;
    }
    final pass = _randomPassword();
    final dir = await pbDataDir();
    // Le compte existe peut-être déjà (fichier d'identifiants perdu) → update, sinon create.
    var r = await Process.run(
        exe.path, ['admin', 'update', adminEmail, pass, '--dir=$dir']);
    if (r.exitCode != 0) {
      r = await Process.run(
          exe.path, ['admin', 'create', adminEmail, pass, '--dir=$dir']);
    }
    if (r.exitCode != 0) {
      throw Exception(
          'Impossible de créer le compte interne de la base de données.\n${r.stderr}${r.stdout}');
    }
    _adminPass = pass;
    await cred.writeAsString(jsonEncode({'admin_password': pass}));
  }

  // ───────────────────────── Démarrage / arrêt ─────────────────────────
  /// Démarre la base de données si elle ne tourne pas déjà.
  Future<void> ensureRunning() async {
    if (!supported) {
      throw Exception(
          'Le mode « poste principal » n\'est disponible que sous Windows.');
    }
    final exe = _findExe();
    if (exe == null) {
      throw Exception(
          'Fichier de base de données introuvable ($exeName).\n'
          'Réinstallez l\'application.');
    }
    // Une base répond déjà alors que ce n'est pas nous qui l'avons lancée :
    // soit un reste de notre propre base (fermeture brutale), soit un autre programme.
    if (_proc == null && await isHealthy()) {
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/IM', exeName]);
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 2));
      }
      if (await isHealthy()) {
        throw Exception(
            'Le port ${AppConfig.serverPort} est déjà utilisé par un autre programme '
            '(par exemple un PocketBase lancé manuellement).\n'
            'Fermez-le (Gestionnaire des tâches → pocketbase.exe) puis réessayez.');
      }
    }

    await _ensureAdminAccount(exe);

    if (await isHealthy()) return; // déjà lancée par cette instance

    final dir = await pbDataDir();
    await Directory(dir).create(recursive: true);
    _log.clear();
    final p = await Process.start(
      exe.path,
      [
        'serve',
        '--http=0.0.0.0:${AppConfig.serverPort}',
        '--dir=$dir',
        '--migrationsDir=${await dataRoot()}${Platform.pathSeparator}pb_migrations',
      ],
      workingDirectory: exe.parent.path,
    );
    _proc = p;
    void collect(List<int> d) {
      _log.addAll(utf8.decode(d, allowMalformed: true).split('\n'));
      if (_log.length > 80) _log.removeRange(0, _log.length - 80);
    }

    p.stdout.listen(collect);
    p.stderr.listen(collect);

    if (!await waitUntilHealthy(seconds: 40)) {
      throw Exception(
          'La base de données n\'a pas démarré.\n$logTail\n'
          'Vérifiez que le port ${AppConfig.serverPort} n\'est pas utilisé '
          'et que l\'antivirus ne bloque pas $exeName.');
    }
  }

  Future<void> stop() async {
    try {
      _proc?.kill();
    } catch (_) {}
    _proc = null;
    if (Platform.isWindows) {
      // Couvre aussi le cas d'un redémarrage interne de PocketBase (restauration).
      try {
        await Process.run('taskkill', ['/F', '/IM', exeName]);
      } catch (_) {}
    }
  }

  /// Régénère le mot de passe du compte interne (ex. base restaurée depuis un autre poste).
  Future<void> resetAdmin() async {
    await stop();
    final f = await _credFile();
    if (f.existsSync()) await f.delete();
    _adminPass = null;
    await Future.delayed(const Duration(seconds: 1));
    await ensureRunning();
  }

  Future<void> restart() async {
    await stop();
    await Future.delayed(const Duration(seconds: 1));
    await ensureRunning();
  }

  /// Adresses IPv4 locales à saisir sur les autres postes.
  Future<List<String>> localAddresses() async {
    try {
      final ifs = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final i in ifs)
          for (final a in i.addresses)
            if (!a.address.startsWith('169.254.'))
              'http://${a.address}:${AppConfig.serverPort}'
      ];
    } catch (_) {
      return [];
    }
  }
}
