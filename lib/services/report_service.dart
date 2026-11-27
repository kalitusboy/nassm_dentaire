import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/acte.dart';
import '../utils/fmt.dart';
import '../utils/pb_utils.dart';
import 'pb_client.dart';

enum Granularite { jour, mois, annee }

class PaiementLigne {
  final String id;
  final DateTime date;
  final String patient, acte, methode, medecin;
  final double montant;
  PaiementLigne(this.id, this.date, this.patient, this.acte, this.methode, this.medecin, this.montant);
}

class ReportData {
  final Granularite gran;
  final DateTime from, to;
  double totalRecette = 0;
  double totalFacture = 0;
  int nbPaiements = 0, nbActes = 0, nbRdv = 0, nbNouveauxPatients = 0, nbPatientsVus = 0;
  final Map<String, double> parMethode = {};
  final Map<String, double> parMedecin = {};
  final Map<String, int> nbParType = {};
  final Map<String, double> factureParType = {};
  final List<MapEntry<String, double>> serie = [];
  final List<PaiementLigne> lignes = [];

  ReportData(this.gran, this.from, this.to);

  String get libellePeriode {
    switch (gran) {
      case Granularite.jour:
        return DateFormat.yMMMMEEEEd('fr_FR').format(from);
      case Granularite.mois:
        return DateFormat.yMMMM('fr_FR').format(from);
      case Granularite.annee:
        return 'Année ${from.year}';
    }
  }

  String get titre => switch (gran) {
        Granularite.jour => 'Rapport journalier',
        Granularite.mois => 'Rapport mensuel',
        Granularite.annee => 'Rapport annuel',
      };
}

class ReportService {
  static const methodeLibelles = {
    'espece': 'Espèces',
    'cheque': 'Chèque',
    'carte': 'Carte',
    'virement': 'Virement',
  };

  static DateTime start(Granularite g, DateTime ref) => switch (g) {
        Granularite.jour => DateTime(ref.year, ref.month, ref.day),
        Granularite.mois => DateTime(ref.year, ref.month, 1),
        Granularite.annee => DateTime(ref.year, 1, 1),
      };

  static DateTime end(Granularite g, DateTime ref) => switch (g) {
        Granularite.jour => DateTime(ref.year, ref.month, ref.day + 1),
        Granularite.mois => DateTime(ref.year, ref.month + 1, 1),
        Granularite.annee => DateTime(ref.year + 1, 1, 1),
      };

  Future<ReportData> build(Granularite g, DateTime ref) async {
    final pb = PbClient.instance.pb;
    final from = start(g, ref), to = end(g, ref);
    final d = ReportData(g, from, to);
    final range = '>= "${pbFmt(from)}"';
    final rangeEnd = '< "${pbFmt(to)}"';

    // ── Encaissements ──
    final paiements = await pb.collection('paiements').getFullList(
        filter: 'date $range && date $rangeEnd',
        sort: 'date',
        expand: 'patient,acte.medecin');
    final buckets = <int, double>{};
    for (final p in paiements) {
      final m = p.getDoubleValue('montant');
      final date = pbDate(p, 'date') ?? DateTime.now();
      final pe = p.expand['patient'];
      final ae = p.expand['acte'];
      final patient = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}'.trim()
          : '—';
      String acte = '', medecin = 'Inconnu';
      if (ae != null && ae.isNotEmpty) {
        acte = Acte.typesLibelles[ae[0].getStringValue('type')] ?? ae[0].getStringValue('type');
        final me = ae[0].expand['medecin'];
        if (me != null && me.isNotEmpty) {
          medecin = 'Dr. ${me[0].getStringValue('prenom')} ${me[0].getStringValue('nom')}'.trim();
        }
      }
      final meth = methodeLibelles[p.getStringValue('methode')] ?? p.getStringValue('methode');
      d.totalRecette += m;
      d.parMethode[meth] = (d.parMethode[meth] ?? 0) + m;
      d.parMedecin[medecin] = (d.parMedecin[medecin] ?? 0) + m;
      d.lignes.add(PaiementLigne(p.id, date, patient, acte, meth, medecin, m));
      final key = switch (g) {
        Granularite.jour => date.hour,
        Granularite.mois => date.day,
        Granularite.annee => date.month,
      };
      buckets[key] = (buckets[key] ?? 0) + m;
    }
    d.nbPaiements = paiements.length;

    // ── Série pour le graphique ──
    switch (g) {
      case Granularite.jour:
        for (var h = 8; h <= 20; h++) {
          d.serie.add(MapEntry('${h}h', buckets[h] ?? 0));
        }
      case Granularite.mois:
        final days = DateTime(from.year, from.month + 1, 0).day;
        for (var i = 1; i <= days; i++) {
          d.serie.add(MapEntry('$i', buckets[i] ?? 0));
        }
      case Granularite.annee:
        for (var i = 1; i <= 12; i++) {
          d.serie.add(MapEntry(
              DateFormat.MMM('fr_FR').format(DateTime(from.year, i, 1)), buckets[i] ?? 0));
        }
    }

    // ── Actes ──
    final actes = await pb.collection('actes').getFullList(
        filter: 'date $range && date $rangeEnd', fields: 'id,patient,type,montant_total');
    final patients = <String>{};
    for (final a in actes) {
      final t = Acte.typesLibelles[a.getStringValue('type')] ?? a.getStringValue('type');
      final m = a.getDoubleValue('montant_total');
      d.nbParType[t] = (d.nbParType[t] ?? 0) + 1;
      d.factureParType[t] = (d.factureParType[t] ?? 0) + m;
      d.totalFacture += m;
      patients.add(a.getStringValue('patient'));
    }
    d.nbActes = actes.length;
    d.nbPatientsVus = patients.length;

    // ── Rendez-vous et nouveaux patients ──
    final rdv = await pb.collection('rendez_vous').getList(
        page: 1, perPage: 1, filter: 'date_heure $range && date_heure $rangeEnd');
    d.nbRdv = rdv.totalItems;
    final np = await pb.collection('patients').getList(
        page: 1, perPage: 1, filter: 'created $range && created $rangeEnd');
    d.nbNouveauxPatients = np.totalItems;
    return d;
  }

  /// Exporte le rapport en CSV (ouvrable dans Excel) et retourne le chemin.
  Future<String?> exportCsv(ReportData d, {String clinic = 'DentaGest'}) async {
    final rows = <List<dynamic>>[
      [clinic, d.titre],
      ['Période', d.libellePeriode],
      ['Généré le', fmtDateTime(DateTime.now())],
      [],
      ['RÉSUMÉ'],
      ['Recette encaissée', d.totalRecette],
      ['Montant facturé (actes)', d.totalFacture],
      ['Nombre d\'encaissements', d.nbPaiements],
      ['Nombre d\'actes', d.nbActes],
      ['Patients vus', d.nbPatientsVus],
      ['Nouveaux patients', d.nbNouveauxPatients],
      ['Rendez-vous', d.nbRdv],
      [],
      ['RECETTE PAR MODE DE PAIEMENT'],
      for (final e in d.parMethode.entries) [e.key, e.value],
      [],
      ['RECETTE PAR MÉDECIN'],
      for (final e in d.parMedecin.entries) [e.key, e.value],
      [],
      ['ACTES PAR TYPE', 'Nombre', 'Montant facturé'],
      for (final e in d.nbParType.entries) [e.key, e.value, d.factureParType[e.key] ?? 0],
      [],
      ['DÉTAIL DES ENCAISSEMENTS'],
      ['Date', 'Heure', 'Patient', 'Acte', 'Médecin', 'Mode', 'Montant'],
      for (final l in d.lignes)
        [fmtDate(l.date), fmtTime(l.date), l.patient, l.acte, l.medecin, l.methode, l.montant],
      [],
      ['TOTAL', '', '', '', '', '', d.totalRecette],
    ];
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final tag = switch (d.gran) {
        Granularite.jour => DateFormat('yyyy-MM-dd').format(d.from),
        Granularite.mois => DateFormat('yyyy-MM').format(d.from),
        Granularite.annee => '${d.from.year}',
      };
      final file = File('${dir.path}/rapport_${d.gran.name}_$tag.csv');
      await file.writeAsString('\uFEFF$csv');
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
