import 'package:pocketbase/pocketbase.dart';
import '../models/paiement.dart';
import 'pb_client.dart';

class PaiementService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<Paiement> create(Paiement p) async =>
      Paiement.fromRecord(await _pb.collection('paiements').create(body: p.toJson()));
  Future<List<Paiement>> listForPatient(String pid) async {
    final r = await _pb.collection('paiements').getFullList(
      filter: 'patient = "$pid"', sort: '-date');
    return r.map(Paiement.fromRecord).toList();
  }
  Future<void> delete(String id) => _pb.collection('paiements').delete(id);
}