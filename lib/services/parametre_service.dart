import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../models/parametre.dart';
import 'pb_client.dart';

class ParametreService {
  PocketBase get _pb => PbClient.instance.pb;
  static Parametre? _cache;

  /// Notifie les écrans (logo…) quand les paramètres changent.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void invalidate() {
    _cache = null;
    changes.value++;
  }

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
    changes.value++;
  }

  Future<void> uploadLogo(String id, String path) async {
    _cache = Parametre.fromRecord(await _pb.collection('parametres').update(
      id,
      files: [await http.MultipartFile.fromPath('logo', path)],
    ));
    changes.value++;
  }

  Future<void> removeLogo(String id) async {
    _cache = Parametre.fromRecord(
        await _pb.collection('parametres').update(id, body: {'logo': null}));
    changes.value++;
  }

  /// Octets du logo (pour les PDF), ou null.
  Future<Uint8List?> logoBytes() async {
    try {
      final p = await get();
      if (p == null || p.logoUrl.isEmpty) return null;
      final r = await http.get(Uri.parse(p.logoUrl)).timeout(const Duration(seconds: 8));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }
}
