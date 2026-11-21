import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import '../models/radiographie.dart';
import 'pb_client.dart';

class RadiographieService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<Radiographie> upload({
    required String patientId, required File file,
    required String type, String acteId = '', String notes = '',
  }) async {
    final r = await _pb.collection('radiographies').create(
      body: {
        'patient': patientId, 'acte': acteId, 'type': type,
        'date': DateTime.now().toIso8601String(), 'notes': notes,
      },
      files: [MultipartFile.fromPath('fichier', file.path)],
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