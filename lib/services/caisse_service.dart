import 'package:pocketbase/pocketbase.dart';
import '../models/acte.dart';
import '../models/paiement.dart';
import 'pb_client.dart';

/// Un acte avec ce qui reste à payer.
class ActeDu {
  final Acte acte;
  final double paye;
  ActeDu(this.acte, this.paye);
  double get reste => acte.montantTotal - paye;
}

class CaisseService {
  PocketBase get _pb => PbClient.instance.pb;

  /// Actes du patient avec un reste à payer, du plus ancien au plus récent.
  Future<List<ActeDu>> actesDus(String patientId) async {
    final actes = await _pb.collection('actes').getFullList(
        filter: 'patient = "$patientId"', sort: 'date', expand: 'medecin');
    final paiements = await _pb.collection('paiements').getFullList(
        filter: 'patient = "$patientId"', fields: 'acte,montant');
    final map = <String, double>{};
    for (final p in paiements) {
      final k = p.getStringValue('acte');
      map[k] = (map[k] ?? 0) + p.getDoubleValue('montant');
    }
    final res = <ActeDu>[];
    for (final r in actes) {
      final a = Acte.fromRecord(r);
      final d = ActeDu(a, map[a.id] ?? 0);
      if (d.reste > 0.009) res.add(d);
    }
    return res;
  }

  /// Enregistre un encaissement en le répartissant sur les actes (du plus ancien
  /// au plus récent). Retourne le montant effectivement affecté.
  /// Si le montant dépasse le dû, l'excédent est affecté au dernier acte.
  Future<double> encaisser({
    required String patientId,
    required double montant,
    required String methode,
    required List<ActeDu> dus,
  }) async {
    var reste = montant;
    for (var i = 0; i < dus.length && reste > 0.009; i++) {
      final d = dus[i];
      final isLast = i == dus.length - 1;
      final part = isLast ? reste : (reste < d.reste ? reste : d.reste);
      await _pb.collection('paiements').create(
          body: Paiement(
        id: '',
        acteId: d.acte.id,
        patientId: patientId,
        montant: part,
        date: DateTime.now(),
        methode: methode,
      ).toJson());
      reste -= part;
    }
    return montant - reste;
  }
}
