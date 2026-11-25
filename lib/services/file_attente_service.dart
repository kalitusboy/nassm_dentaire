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

  Future<void> register({required String patientId, String motif = ''}) =>
      _pb.collection('file_attente').create(body: {
        'patient': patientId,
        'heure_arrivee': pbFmt(DateTime.now()),
        'statut': 'attente',
        'motif': motif,
        'appel_reception': false,
      });

  Future<void> setStatut(String id, String statut, {String? medecinId}) =>
      _pb.collection('file_attente').update(id, body: {
        'statut': statut,
        if (medecinId != null && medecinId.isNotEmpty) 'medecin': medecinId,
        if (statut != 'en_consultation') 'appel_reception': false,
      });

  Future<void> appelReception(String id, bool value) =>
      _pb.collection('file_attente').update(id, body: {'appel_reception': value});

  /// Pour les notifications : passages du jour concernés (léger).
  Future<List<FileAttente>> listActiveToday() async {
    final all = await listToday();
    return all.where((f) => f.statut != 'termine' && f.statut != 'annule').toList();
  }
}
