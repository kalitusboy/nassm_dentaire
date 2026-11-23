import 'dart:io';

import 'admin_api.dart';
import 'server_manager.dart';

/// Sauvegardes de la base (poste principal uniquement).
class BackupService {
  final AdminApi _api = AdminApi();

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _stamp(DateTime d) =>
      '${d.year}${_two(d.month)}${_two(d.day)}';

  Future<String?> createBackup() async {
    try {
      final n = DateTime.now();
      final name =
          'manual_${_stamp(n)}_${_two(n.hour)}${_two(n.minute)}${_two(n.second)}.zip';
      await _api.createBackup(name);
      return name;
    } catch (_) {
      return null;
    }
  }

  /// Liste triée du plus récent au plus ancien : {key, size, modified}.
  Future<List<Map<String, dynamic>>> listBackups() async {
    final l = await _api.listBackups();
    l.sort((a, b) =>
        (b['modified'] ?? '').toString().compareTo((a['modified'] ?? '').toString()));
    return l;
  }

  /// Une sauvegarde automatique par jour, 30 conservées.
  Future<void> autoDaily() async {
    try {
      final today = 'auto_${_stamp(DateTime.now())}.zip';
      final list = await _api.listBackups();
      if (!list.any((b) => b['key'] == today)) {
        await _api.createBackup(today);
      }
      final autos = (await _api.listBackups())
          .map((b) => b['key'].toString())
          .where((k) => k.startsWith('auto_'))
          .toList()
        ..sort((a, b) => b.compareTo(a));
      for (final old in autos.skip(30)) {
        await _api.deleteBackup(old);
      }
    } catch (_) {
      // une sauvegarde automatique ne doit jamais bloquer l'application
    }
  }

  /// Restaure puis attend que la base redémarre.
  Future<bool> restoreBackup(String key) async {
    await _api.restoreBackup(key);
    await Future.delayed(const Duration(seconds: 3));
    return ServerManager.instance.waitUntilHealthy(seconds: 60);
  }

  /// Copie un fichier de sauvegarde vers un dossier (clé USB, disque externe…).
  Future<String> copyTo(String key, String directory) async {
    final src = File(
        '${await ServerManager.instance.backupsDir()}${Platform.pathSeparator}$key');
    if (!src.existsSync()) throw Exception('Fichier de sauvegarde introuvable.');
    final dst = '$directory${Platform.pathSeparator}$key';
    await src.copy(dst);
    return dst;
  }
}
