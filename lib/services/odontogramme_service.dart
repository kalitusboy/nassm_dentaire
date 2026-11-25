import 'package:pocketbase/pocketbase.dart';
import '../models/odontogramme.dart';
import 'pb_client.dart';

class OdontogrammeService {
  PocketBase get _pb => PbClient.instance.pb;

  Future<Odontogramme?> getForPatient(String pid) async {
    final list = await _pb.collection('odontogrammes').getList(
      filter: 'patient = "$pid"', perPage: 1);
    return list.items.isEmpty ? null : Odontogramme.fromRecord(list.items.first);
  }

  Future<Odontogramme> save(Odontogramme o) async {
    if (o.id.isNotEmpty) {
      return Odontogramme.fromRecord(
          await _pb.collection('odontogrammes').update(o.id, body: o.toJson()));
    }
    try {
      return Odontogramme.fromRecord(
        await _pb.collection('odontogrammes').create(body: o.toJson()));
    } on ClientException {
      final ex = await getForPatient(o.patientId);
      if (ex == null) rethrow;
      return Odontogramme.fromRecord(
        await _pb.collection('odontogrammes').update(ex.id, body: o.toJson()));
    }
  }

  Future<Odontogramme> updateTooth({
    required String patientId, required String dent,
    required String status, String notes = '',
  }) async {
    var o = await getForPatient(patientId);
    o ??= Odontogramme(id: '', patientId: patientId);
    o.dents[dent] = ToothStatus(status: status, notes: notes);
    return save(o);
  }

  Future<Odontogramme> changeDentition(String patientId, TypeDentition type) async {
    var o = await getForPatient(patientId);
    o ??= Odontogramme(id: '', patientId: patientId);
    return save(o.copyWith(type: type));
  }
}