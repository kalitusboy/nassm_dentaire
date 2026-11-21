import 'package:pocketbase/pocketbase.dart';
import '../models/patient.dart';
import '../models/acte.dart';
import 'pb_client.dart';

class PatientService {
  PocketBase get _pb => PbClient.instance.pb;

  Future<List<Patient>> search(String q) async {
    final f = q.isEmpty ? '' : 'nom ~ "$q" || prenom ~ "$q" || numero_dossier ~ "$q"';
    final r = await _pb.collection('patients').getList(
      page: 1, perPage: 100, filter: f, sort: 'nom,prenom');
    return r.items.map(Patient.fromRecord).toList();
  }

  Future<Patient?> getById(String id) async =>
      Patient.fromRecord(await _pb.collection('patients').getOne(id));

  Future<Patient> create(Patient p) async =>
      Patient.fromRecord(await _pb.collection('patients').create(body: p.toJson()));

  Future<Patient> update(String id, Patient p) async =>
      Patient.fromRecord(await _pb.collection('patients').update(id, body: p.toJson()));

  Future<void> delete(String id) => _pb.collection('patients').delete(id);

  Future<String> nextNumero() async {
    final all = await _pb.collection('patients').getFullList(sort: '-created');
    if (all.isEmpty) return 'P0001';
    final n = int.tryParse(
      all.first.getStringValue('numero_dossier').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'P${(n + 1).toString().padLeft(4, '0')}';
  }

  Future<DateTime?> lastVisit(String pid) async {
    final r = await _pb.collection('actes').getList(
      filter: 'patient = "$pid" && statut = "termine"', sort: '-date', perPage: 1);
    return r.items.isEmpty ? null : r.items.first.getDateTimeValue('date');
  }

  Future<List<Acte>> actesForPatient(String pid) async {
    final r = await _pb.collection('actes').getList(
      filter: 'patient = "$pid"', sort: '-date', expand: 'medecin', perPage: 200);
    return r.items.map(Acte.fromRecord).toList();
  }
}