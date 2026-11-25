import 'package:pocketbase/pocketbase.dart';
import '../models/ordonnance.dart';
import 'pb_client.dart';

class OrdonnanceService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<Ordonnance> create(Ordonnance o) async =>
      Ordonnance.fromRecord(await _pb.collection('ordonnances').create(body: o.toJson()));
  Future<List<Ordonnance>> listForPatient(String pid) async {
    final r = await _pb.collection('ordonnances').getFullList(
      filter: 'patient = "$pid"', sort: '-date');
    return r.map(Ordonnance.fromRecord).toList();
  }
  Future<void> delete(String id) => _pb.collection('ordonnances').delete(id);
}