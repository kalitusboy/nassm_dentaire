import 'package:pocketbase/pocketbase.dart';
import '../models/rendez_vous.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

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
      filter: 'date_heure >= "${pbFmt(s)}" && date_heure < "${pbFmt(e)}"',
      sort: 'date_heure', expand: 'patient,medecin');
    return r.map(RendezVous.fromRecord).toList();
  }
  /// Rendez-vous entre deux dates (from inclus, to exclu).
  Future<List<RendezVous>> listForRange(DateTime from, DateTime to) async {
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'date_heure >= "${pbFmt(from)}" && date_heure < "${pbFmt(to)}"',
      sort: 'date_heure', expand: 'patient,medecin');
    return r.map(RendezVous.fromRecord).toList();
  }

  /// Tous les rendez-vous, du plus ancien au plus récent.
  Future<List<RendezVous>> listAll() async {
    final r = await _pb.collection('rendez_vous').getFullList(
      sort: 'date_heure', expand: 'patient,medecin');
    return r.map(RendezVous.fromRecord).toList();
  }

  Future<List<RendezVous>> listForPatient(String pid) async {
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'patient = "$pid"', sort: '-date_heure', expand: 'medecin');
    return r.map(RendezVous.fromRecord).toList();
  }

  /// Autre rendez-vous actif du même patient le même jour (ou null).
  Future<RendezVous?> findPatientSameDay({
    required String patientId,
    required DateTime date,
    String? excludeId,
  }) async {
    final s = DateTime(date.year, date.month, date.day);
    final e = s.add(const Duration(days: 1));
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'patient = "$patientId" && date_heure >= "${pbFmt(s)}" '
          '&& date_heure < "${pbFmt(e)}" && statut != "annule"',
      sort: 'date_heure', expand: 'patient,medecin');
    for (final x in r.map(RendezVous.fromRecord)) {
      if (excludeId != null && x.id == excludeId) continue;
      return x;
    }
    return null;
  }

  /// Confie ces rendez-vous à un autre médecin (médecin absent). Retourne le nombre modifié.
  Future<int> reassign(List<String> ids, String medecinId) async {
    var n = 0;
    for (final id in ids) {
      await _pb.collection('rendez_vous').update(id, body: {'medecin': medecinId});
      n++;
    }
    return n;
  }

  /// Rendez-vous du même médecin qui chevauche le créneau demandé (ou null).
  Future<RendezVous?> findConflict({
    required String medecinId,
    required DateTime start,
    required int minutes,
    String? excludeId,
  }) async {
    final from = start.subtract(const Duration(hours: 4));
    final end = start.add(Duration(minutes: minutes));
    final r = await _pb.collection('rendez_vous').getFullList(
      filter: 'medecin = "$medecinId" && date_heure >= "${pbFmt(from)}" '
          '&& date_heure < "${pbFmt(end)}" && statut != "annule"',
      expand: 'patient');
    for (final x in r.map(RendezVous.fromRecord)) {
      if (excludeId != null && x.id == excludeId) continue;
      final xEnd = x.dateHeure.add(Duration(minutes: x.dureeMinutes));
      if (xEnd.isAfter(start)) return x;
    }
    return null;
  }
}
