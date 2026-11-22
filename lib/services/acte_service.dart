import 'package:pocketbase/pocketbase.dart';
import '../models/acte.dart';
import 'pb_client.dart';

class ActeService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<Acte> create(Acte a) async =>
      Acte.fromRecord(await _pb.collection('actes').create(body: a.toJson()));
  Future<Acte> update(String id, Acte a) async =>
      Acte.fromRecord(await _pb.collection('actes').update(id, body: a.toJson()));
  Future<void> delete(String id) => _pb.collection('actes').delete(id);
  Future<List<Acte>> listForPatient(String pid) async {
    final r = await _pb.collection('actes').getFullList(
      filter: 'patient = "$pid"', sort: '-date', expand: 'medecin');
    return r.map(Acte.fromRecord).toList();
  }
  Future<double> totalPaye(String acteId) async {
    final r = await _pb.collection('paiements').getFullList(filter: 'acte = "$acteId"');
    return r.fold<double>(0, (s, p) => s + p.getDoubleValue('montant'));
  }
}