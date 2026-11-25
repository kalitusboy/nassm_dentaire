import 'package:pocketbase/pocketbase.dart';
import '../models/patient.dart';
import '../models/acte.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

class PatientService {
  PocketBase get _pb => PbClient.instance.pb;

  static String _esc(String q) =>
      q.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  /// Première page de résultats (100 max) — pour les listes de sélection.
  Future<List<Patient>> search(String q) async =>
      (await searchPage(q, perPage: 100)).items;

  /// Patients portant déjà ce nom et ce prénom (détection des doublons).
  Future<List<Patient>> findSimilar(String nom, String prenom) async {
    final r = await _pb.collection('patients').getList(
        page: 1, perPage: 10,
        filter: 'nom ~ "${_esc(nom)}" && prenom ~ "${_esc(prenom)}"');
    return r.items.map(Patient.fromRecord).toList();
  }

  /// Recherche paginée : la base accepte un nombre illimité de patients.
  Future<PatientPage> searchPage(String q,
      {int page = 1, int perPage = 50}) async {
    final e = _esc(q);
    final f = q.isEmpty
        ? ''
        : 'nom ~ "$e" || prenom ~ "$e" || numero_dossier ~ "$e"';
    final r = await _pb.collection('patients').getList(
        page: page, perPage: perPage, filter: f, sort: 'nom,prenom');
    return PatientPage(
        r.items.map(Patient.fromRecord).toList(), r.totalPages, r.totalItems);
  }

  Future<Patient?> getById(String id) async =>
      Patient.fromRecord(await _pb.collection('patients').getOne(id));

  /// Crée le patient. Si deux postes ont obtenu le même numéro de dossier
  /// automatique au même moment, un nouveau numéro est attribué (3 essais).
  Future<Patient> create(Patient p) async {
    final body = p.toJson();
    for (var i = 0;; i++) {
      try {
        return Patient.fromRecord(
            await _pb.collection('patients').create(body: body));
      } on ClientException catch (e) {
        final dup = e.response['data'] is Map &&
            (e.response['data'] as Map).containsKey('numero_dossier');
        final auto = RegExp(r'^P\d+$').hasMatch('${body['numero_dossier']}');
        if (!dup || !auto || i >= 2) rethrow;
        body['numero_dossier'] = await nextNumero();
      }
    }
  }

  Future<Patient> update(String id, Patient p) async =>
      Patient.fromRecord(await _pb.collection('patients').update(id, body: p.toJson()));

  Future<void> delete(String id) => _pb.collection('patients').delete(id);

  Future<String> nextNumero() async {
    final last = await _pb.collection('patients').getList(
      page: 1, perPage: 1, sort: '-created', fields: 'id,numero_dossier');
    if (last.items.isEmpty) return 'P0001';
    final n = int.tryParse(
      last.items.first.getStringValue('numero_dossier').replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return 'P${(n + 1).toString().padLeft(4, '0')}';
  }

  Future<DateTime?> lastVisit(String pid) async {
    final r = await _pb.collection('actes').getList(
      filter: 'patient = "$pid" && statut = "termine"', sort: '-date', perPage: 1);
    return r.items.isEmpty ? null : pbDate(r.items.first, 'date');
  }

  Future<List<Acte>> actesForPatient(String pid) async {
    final r = await _pb.collection('actes').getList(
      filter: 'patient = "$pid"', sort: '-date', expand: 'medecin', perPage: 200);
    return r.items.map(Acte.fromRecord).toList();
  }
}

class PatientPage {
  final List<Patient> items;
  final int totalPages, totalItems;
  PatientPage(this.items, this.totalPages, this.totalItems);
}
