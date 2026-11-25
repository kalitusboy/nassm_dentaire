import 'package:pocketbase/pocketbase.dart';
import '../models/encaissement.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

class EncaissementService {
  PocketBase get _pb => PbClient.instance.pb;

  /// Encaissements du jour, les plus récents d'abord.
  Future<List<Encaissement>> listForDay(DateTime d) async {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1));
    final r = await _pb.collection('encaissements').getFullList(
      filter: 'created >= "${pbFmt(s)}" && created < "${pbFmt(e)}"',
      sort: '-created', expand: 'patient,acte,medecin');
    return r.map(Encaissement.fromRecord).toList();
  }

  Future<List<Encaissement>> enAttente() async {
    final r = await _pb.collection('encaissements').getFullList(
      filter: 'statut = "en_attente"', sort: '-created',
      expand: 'patient,acte,medecin');
    return r.map(Encaissement.fromRecord).toList();
  }

  Future<void> create({
    required String patientId, required String acteId,
    required String medecinId, required double montant,
  }) async {
    // Un seul encaissement « en attente » par acte.
    final exist = await _pb.collection('encaissements').getFullList(
      filter: 'acte = "$acteId" && statut = "en_attente"');
    if (exist.isNotEmpty) return;
    await _pb.collection('encaissements').create(body: {
      'patient': patientId, 'acte': acteId,
      'medecin': medecinId, 'montant': montant, 'statut': 'en_attente',
    });
  }

  /// Marque comme encaissé (après enregistrement du paiement par la réception).
  Future<void> marquerEncaisse(String id) =>
      _pb.collection('encaissements').update(id, body: {'statut': 'encaisse'});

  Future<void> delete(String id) => _pb.collection('encaissements').delete(id);
}
