import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import '../models/radiographie.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

class RadiographieService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<Radiographie> upload({
    required String patientId, required File file,
    required String type, String acteId = '', String notes = '',
  }) async {
    final r = await _pb.collection('radiographies').create(
      body: {
        'patient': patientId, 'acte': acteId, 'type': type,
        'date': pbFmt(DateTime.now()), 'notes': notes,
      },
      files: [await http.MultipartFile.fromPath('fichier', file.path)],
    );
    return Radiographie.fromRecord(r);
  }
  Future<List<Radiographie>> listForPatient(String pid) async {
    final r = await _pb.collection('radiographies').getFullList(
      filter: 'patient = "$pid"', sort: '-date');
    return r.map(Radiographie.fromRecord).toList();
  }
  Future<void> delete(String id) => _pb.collection('radiographies').delete(id);
}