import 'package:pocketbase/pocketbase.dart';
import '../models/file_attente.dart';
import '../utils/fmt.dart';
import '../utils/pb_utils.dart';
import 'pb_client.dart';

class FileAttenteService {
  PocketBase get _pb => PbClient.instance.pb;

  /// Passages du jour, classés par heure d'arrivée.
  Future<List<FileAttente>> listToday() async {
    final s = startOfDay(DateTime.now());
    final e = s.add(const Duration(days: 1));
    final r = await _pb.collection('file_attente').getFullList(
        filter: 'heure_arrivee >= "${pbFmt(s)}" && heure_arrivee < "${pbFmt(e)}"',
        sort: 'heure_arrivee',
        expand: 'patient,medecin');
    return r.map(FileAttente.fromRecord).toList();
  }

  /// Enregistre l'arrivée. Si le patient a un rendez-vous aujourd'hui, il est
  /// marqué « confirmé ». Retourne le RDV du jour (ou null) pour l'afficher.
  Future<RecordModel?> register({required String patientId, String motif = ''}) async {
    await _pb.collection('file_attente').create(body: {
      'patient': patientId,
      'heure_arrivee': pbFmt(DateTime.now()),
      'statut': 'attente',
      'motif': motif,
      'appel_reception': false,
    });
    return _syncRdv(patientId, 'confirme');
  }

  Future<void> setStatut(String id, String statut, {String? medecinId}) async {
    await _pb.collection('file_attente').update(id, body: {
      'statut': statut,
      if (medecinId != null && medecinId.isNotEmpty) 'medecin': medecinId,
      if (statut != 'en_consultation') 'appel_reception': false,
    });
    if (statut == 'a_encaisser' || statut == 'termine') {
      try {
        final rec = await _pb.collection('file_attente').getOne(id);
        await _syncRdv(rec.getStringValue('patient'), 'termine');
      } catch (_) {}
    }
  }

  /// Met à jour le statut du rendez-vous du jour encore ouvert de ce patient.
  Future<RecordModel?> _syncRdv(String patientId, String statut) async {
    try {
      final s = startOfDay(DateTime.now());
      final e = s.add(const Duration(days: 1));
      final r = await _pb.collection('rendez_vous').getFullList(
          filter: 'patient = "$patientId" && date_heure >= "${pbFmt(s)}" '
              '&& date_heure < "${pbFmt(e)}" && (statut = "planifie" || statut = "confirme")',
          sort: 'date_heure',
          expand: 'medecin');
      if (r.isEmpty) return null;
      final rdv = r.first;
      if (rdv.getStringValue('statut') != statut) {
        await _pb.collection('rendez_vous').update(rdv.id, body: {'statut': statut});
      }
      return rdv;
    } catch (_) {
      return null;
    }
  }

  Future<void> appelReception(String id, bool value) =>
      _pb.collection('file_attente').update(id, body: {'appel_reception': value});

  /// Pour les notifications : passages du jour concernés (léger).
  Future<List<FileAttente>> listActiveToday() async {
    final all = await listToday();
    return all.where((f) => f.statut != 'termine' && f.statut != 'annule').toList();
  }
}
