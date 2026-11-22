import 'package:pocketbase/pocketbase.dart';
import '../models/rendez_vous.dart';
import 'pb_client.dart';

class RendezVousService {
  PocketBase get _pb => PbClient.instance.pb;
  Future<RendezVous> create(RendezVous r) async =>
      RendezVous.fromRecord(await _pb.collection('rendez_vous').create(body: r.toJson()));
  Future<RendezVous> update(String id, RendezVous r) async =>
      RendezVous.fromRecord(await _pb.collection('rendez_vous').update(id, body: r.toJson()));
  Future<void> delete(String id) => _pb.collection('rendez_vous').delete(id);
  Future<List<RendezVous>> listForDay(DateTime d) async {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1));
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'date_heure >= "${s.toIso8601String()}" && date_heure < "${e.toIso8601String()}"',
      sort: 'date_heure', expand: 'patient,medecin');
    return r.map(RendezVous.fromRecord).toList();
  }
  Future<List<RendezVous>> listForPatient(String pid) async {
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'patient = "$pid"', sort: '-date_heure', expand: 'medecin');
    return r.map(RendezVous.fromRecord).toList();
  }
}