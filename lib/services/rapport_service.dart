import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';
import '../utils/pb_utils.dart';

class RapportService {
  PocketBase get _pb => PbClient.instance.pb;

  Future<double> recetteJour(DateTime d) =>
      _sum(DateTime(d.year, d.month, d.day), DateTime(d.year, d.month, d.day).add(const Duration(days: 1)));
  Future<double> recetteMois(int y, int m) => _sum(DateTime(y, m, 1), DateTime(y, m + 1, 1));
  Future<double> recettePeriode(DateTime a, DateTime b) => _sum(a, b);
  Future<double> recetteAnnee(int y) => _sum(DateTime(y, 1, 1), DateTime(y + 1, 1, 1));

  /// Détail des encaissements sur une période (pour rapport imprimé).
  Future<List<Map<String, dynamic>>> detailRecettePeriode(DateTime a, DateTime b) async {
    final r = await _pb.collection('paiements').getFullList(
      filter: 'date >= "${pbFmt(a)}" && date < "${pbFmt(b)}"',
      sort: '-date', expand: 'patient,acte');
    return r.map((p) {
      final pe = p.expand['patient'];
      final ae = p.expand['acte'];
      final pn = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}' : '';
      final at = (ae != null && ae.isNotEmpty) ? ae[0].getStringValue('type') : '';
      return {
        'patient': pn, 'acte': at, 'montant': p.getDoubleValue('montant'),
        'methode': p.getStringValue('methode'),
        'date': _df.format(pbDate(p, 'date') ?? DateTime.now()),
      };
    }).toList();
  }

  static final _df = DateFormat('dd/MM/yyyy', 'fr_FR');

  Future<Map<String, double>> recetteParMedecin(DateTime d) async {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1));
    final paiements = await _pb.collection('paiements').getFullList(
      filter: 'date >= "${pbFmt(s)}" && date < "${pbFmt(e)}"',
      expand: 'acte.medecin');
    final map = <String, double>{};
    for (final p in paiements) {
      final a = p.expand['acte'];
      if (a == null || a.isEmpty) continue;
      final m = a[0].expand['medecin'];
      final nom = (m != null && m.isNotEmpty)
          ? '${m[0].getStringValue('prenom')} ${m[0].getStringValue('nom')}'
          : 'Inconnu';
      map[nom] = (map[nom] ?? 0) + p.getDoubleValue('montant');
    }
    return map;
  }

  Future<double> totalResteAPayer() async {
    final actes = await _pb.collection('actes').getFullList(fields: 'id,montant_total');
    final paiements = await _pb.collection('paiements').getFullList(fields: 'acte,montant');
    final Map<String, double> parActe = {};
    for (final p in paiements) {
      parActe[p.getStringValue('acte')] =
          (parActe[p.getStringValue('acte')] ?? 0) + p.getDoubleValue('montant');
    }
    double r = 0;
    for (final a in actes) {
      final t = a.getDoubleValue('montant_total');
      final p = parActe[a.id] ?? 0;
      if (t > p) r += t - p;
    }
    return r;
  }

  Future<List<Map<String, dynamic>>> detailRecetteJour(DateTime d) async {
    final s = DateTime(d.year, d.month, d.day);
    final e = s.add(const Duration(days: 1));
    final paiements = await _pb.collection('paiements').getFullList(
      filter: 'date >= "${pbFmt(s)}" && date < "${pbFmt(e)}"',
      sort: '-date', expand: 'patient,acte');
    return paiements.map((p) {
      final pe = p.expand['patient'];
      final ae = p.expand['acte'];
      final pn = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}' : '';
      final at = (ae != null && ae.isNotEmpty) ? ae[0].getStringValue('type') : '';
      return {
        'patient': pn, 'acte': at, 'montant': p.getDoubleValue('montant'),
        'methode': p.getStringValue('methode'), 'date': pbDate(p, 'date'),
      };
    }).toList();
  }

  Future<double> _sum(DateTime a, DateTime b) async {
    final r = await _pb.collection('paiements').getFullList(
      filter: 'date >= "${pbFmt(a)}" && date < "${pbFmt(b)}"');
    return r.fold<double>(0, (s, p) => s + p.getDoubleValue('montant'));
  }
}