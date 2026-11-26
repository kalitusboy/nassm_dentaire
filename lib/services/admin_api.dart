import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'server_manager.dart';

class AdminApiException implements Exception {
  final String message;
  AdminApiException(this.message);
  @override
  String toString() => message;
}

/// Accès « administrateur » à PocketBase (poste principal uniquement).
/// Sert à créer le schéma, le premier utilisateur et les sauvegardes.
/// Utilise l'API REST directement afin de ne pas dépendre de la version du SDK.
class AdminApi {
  final String base;
  String? _token;
  AdminApi({String? base}) : base = base ?? AppConfig.defaultUrl;

  Future<void> auth() async {
    final r = await http
        .post(
          Uri.parse('$base/api/admins/auth-with-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'identity': ServerManager.adminEmail,
            'password': ServerManager.instance.adminPass,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw AdminApiException(
          'Authentification interne refusée (${r.statusCode}). Si un autre PocketBase '
          'tourne déjà sur le port ${AppConfig.serverPort}, fermez-le ou créez-y le compte '
          '${ServerManager.adminEmail} / ${ServerManager.adminPassword}.');
    }
    _token = (jsonDecode(r.body) as Map)['token'] as String;
  }

  Map<String, String> get _h => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': _token!,
      };

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    if (_token == null) await auth();
    final req = http.Request(method, Uri.parse('$base$path'))
      ..headers.addAll(_h);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 60)));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isEmpty ? null : jsonDecode(res.body);
    }
    throw AdminApiException('$method $path → ${res.statusCode}: ${res.body}');
  }

  // ── Collections ──
  Future<List<Map<String, dynamic>>> listCollections() async {
    final j = await _send('GET', '/api/collections?perPage=200');
    return List<Map<String, dynamic>>.from(
        (j['items'] as List).map((e) => Map<String, dynamic>.from(e)));
  }

  Future<Map<String, dynamic>> createCollection(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _send('POST', '/api/collections', body));

  Future<Map<String, dynamic>> updateCollection(
          String id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await _send('PATCH', '/api/collections/$id', body));

  // ── Enregistrements ──
  Future<List<Map<String, dynamic>>> listRecords(String collection,
      {String? filter, int perPage = 50}) async {
    final q = Uri(queryParameters: {
      'perPage': '$perPage',
      if (filter != null) 'filter': filter,
    }).query;
    final j = await _send('GET', '/api/collections/$collection/records?$q');
    return List<Map<String, dynamic>>.from(
        (j['items'] as List).map((e) => Map<String, dynamic>.from(e)));
  }

  Future<Map<String, dynamic>> createRecord(
          String collection, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
          await _send('POST', '/api/collections/$collection/records', body));

  Future<void> updateRecord(
          String collection, String id, Map<String, dynamic> body) =>
      _send('PATCH', '/api/collections/$collection/records/$id', body);

  // ── Sauvegardes ──
  Future<List<Map<String, dynamic>>> listBackups() async {
    final j = await _send('GET', '/api/backups');
    return List<Map<String, dynamic>>.from(
        (j as List).map((e) => Map<String, dynamic>.from(e)));
  }

  Future<void> createBackup(String name) =>
      _send('POST', '/api/backups', {'name': name});

  Future<void> deleteBackup(String key) => _send('DELETE', '/api/backups/$key');

  Future<void> restoreBackup(String key) =>
      _send('POST', '/api/backups/$key/restore');
}
