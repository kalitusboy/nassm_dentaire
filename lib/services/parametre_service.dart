import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../models/parametre.dart';
import 'pb_client.dart';

class ParametreService {
  PocketBase get _pb => PbClient.instance.pb;
  Parametre? _cache;

  Future<Parametre?> get({bool refresh = false}) async {
    if (_cache != null && !refresh) return _cache;
    final list = await _pb.collection('parametres').getFullList();
    if (list.isEmpty) return null;
    return _cache = Parametre.fromRecord(list.first);
  }

  /// Téléverse le logo de la clinique et l'attache à la fiche paramètres.
  Future<bool> uploadLogo(String filePath) async {
    final cur = await get(refresh: true);
    if (cur == null) return false;
    final f = await http.MultipartFile.fromPath('logo', filePath,
        filename: 'logo_clinique.png');
    final rec = await _pb.collection('parametres').update(cur.id,
        files: [f]);
    _cache = Parametre.fromRecord(rec);
    return true;
  }

  /// URL publique du logo téléversé (pour l'affichage et les PDF).
  /// ( getFileUrl n'existe pas dans le SDK Dart 0.21 : URL construite manuellement )
  static String logoFileUrl(Parametre? p, PocketBase pb) =>
      (p == null || p.logoUrl.isEmpty)
          ? ''
          : '${pb.baseUrl}/api/files/parametres/${p.id}/${p.logoUrl}';

  Future<void> save(Parametre p) async {
    if (p.id.isEmpty) {
      _cache = Parametre.fromRecord(
        await _pb.collection('parametres').create(body: p.toJson()));
    } else {
      _cache = Parametre.fromRecord(
        await _pb.collection('parametres').update(p.id, body: p.toJson()));
    }
  }
}