import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class BackupService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<String?> createBackup() async {
    try {
      final b = await _pb.backups.create('manual_${DateTime.now().millisecondsSinceEpoch}');
      return b.key;
    } catch (_) { return null; }
  }
  Future<List<BackupFile>> listBackups() => _pb.backups.getFullList();
  Future<void> restoreBackup(String key) => _pb.backups.restore(key);
  Future<void> deleteBackup(String key) => _pb.backups.delete(key);
}