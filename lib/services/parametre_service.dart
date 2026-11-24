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