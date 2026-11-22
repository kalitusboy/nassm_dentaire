import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class UserService {
  PocketBase get _pb => PbClient.instance.pb;

  static const roleLabels = {
    'admin': 'Administrateur',
    'dentiste': 'Dentiste',
    'reception': 'Réceptionniste',
  };

  Future<List<RecordModel>> list() =>
      _pb.collection('users').getFullList(sort: 'nom,prenom');

  Future<void> create({
    required String username,
    required String password,
    required String nom,
    required String prenom,
    required String role,
  }) =>
      _pb.collection('users').create(body: {
        'username': username,
        'password': password,
        'passwordConfirm': password,
        'emailVisibility': false,
        'nom': nom,
        'prenom': prenom,
        'role': role,
      });

  Future<void> update(
    String id, {
    required String nom,
    required String prenom,
    required String role,
    String? newPassword,
  }) =>
      _pb.collection('users').update(id, body: {
        'nom': nom,
        'prenom': prenom,
        'role': role,
        if (newPassword != null && newPassword.isNotEmpty) ...{
          'password': newPassword,
          'passwordConfirm': newPassword,
        },
      });

  Future<void> delete(String id) => _pb.collection('users').delete(id);

  /// Message lisible à partir d'une erreur PocketBase.
  static String errorMessage(Object e) {
    if (e is ClientException) {
      final data = e.response['data'];
      if (data is Map && data.isNotEmpty) {
        final parts = <String>[];
        data.forEach((k, v) {
          final m = v is Map ? (v['message'] ?? '') : v.toString();
          parts.add('$k : $m');
        });
        return parts.join('\n');
      }
      final m = e.response['message'];
      if (m is String && m.isNotEmpty) return m;
    }
    return e.toString();
  }
}
