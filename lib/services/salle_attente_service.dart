import 'package:pocketbase/pocketbase.dart';
import '../models/salle_attente.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

class SalleAttenteService {
  PocketBase get _pb => PbClient.instance.pb;

  /// Liste du jour, triée par heure d'arrivée (premier arrivé, premier appelé).
  Future<List<SalleAttente>> listForDay(DateTime d) async {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1));
    final r = await _pb.collection('salle_attente').getFullList(
          filter: 'arrivee >= "${pbFmt(s)}" && arrivee < "${pbFmt(e)}"',
          sort: 'arrivee',
        );
    return r.map(SalleAttente.fromRecord).toList();
  }

  Future<SalleAttente> create(SalleAttente w) async => SalleAttente.fromRecord(
      await _pb.collection('salle_attente').create(body: w.toJson()));

  Future<SalleAttente> update(String id, SalleAttente w) async =>
      SalleAttente.fromRecord(
          await _pb.collection('salle_attente').update(id, body: w.toJson()));

  Future<void> delete(String id) => _pb.collection('salle_attente').delete(id);

  /// Relie l'entrée de la salle d'attente à la fiche patient créée par la
  /// réception (ou trouvée par recherche).
  Future<void> lierPatient(String entryId, String patientId) async =>
      _pb.collection('salle_attente').update(entryId, body: {'patient': patientId});
}
