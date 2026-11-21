import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'pb_client.dart';

class ExcelService {
  final _df = DateFormat('dd/MM/yyyy', 'fr_FR');

  /// تصدير تقرير شهري شامل (كل الدفعات + العلاجات)
  Future<String?> exportRapportMensuel(int year, int month) async {
    final pb = PbClient.instance.pb;
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // جلب كل الدفعات والعلاجات في الشهر
    final paiements = await pb.collection('paiements').getFullList(
      filter: 'date >= "${start.toIso8601String()}" && date < "${end.toIso8601String()}"',
      sort: 'date', expand: 'patient,acte.medecin');

    final actes = await pb.collection('actes').getFullList(
      filter: 'date >= "${start.toIso8601String()}" && date < "${end.toIso8601String()}"',
      sort: 'date', expand: 'patient,medecin');

    final rows = <List<dynamic>>[
      ['Cabinet Dentaire — Rapport mensuel'],
      ['Période', DateFormat.yMMMM('fr_FR').format(start)],
      ['Généré le', _df.format(DateTime.now())],
      [],
      ['=== ACTES DU MOIS ==='],
      ['Date', 'N° dossier', 'Patient', 'Médecin', 'Type', 'Dent', 'Montant', 'Statut'],
    ];

    for (final a in actes) {
      final pe = a.expand['patient'];
      final me = a.expand['medecin'];
      final pn = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}' : '';
      final pno = (pe != null && pe.isNotEmpty)
          ? pe[0].getStringValue('numero_dossier') : '';
      final mn = (me != null && me.isNotEmpty)
          ? '${me[0].getStringValue('prenom')} ${me[0].getStringValue('nom')}' : '';
      rows.add([
        _df.format(a.getDateTimeValue('date') ?? DateTime.now()),
        pno, pn, mn, a.getStringValue('type'),
        a.getIntValue('dent') > 0 ? a.getIntValue('dent') : '',
        a.getDoubleValue('montant_total'),
        a.getStringValue('statut'),
      ]);
    }

    rows
      ..add([])
      ..add(['=== PAIEMENTS DU MOIS ==='])
      ..add(['Date', 'N° dossier', 'Patient', 'Montant', 'Méthode', 'Notes']);

    double totalPaye = 0;
    for (final p in paiements) {
      final pe = p.expand['patient'];
      final pn = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}' : '';
      final pno = (pe != null && pe.isNotEmpty)
          ? pe[0].getStringValue('numero_dossier') : '';
      final m = p.getDoubleValue('montant');
      totalPaye += m;
      rows.add([
        _df.format(p.getDateTimeValue('date') ?? DateTime.now()),
        pno, pn, m, p.getStringValue('methode'), p.getStringValue('notes'),
      ]);
    }

    rows
      ..add([])
      ..add(['=== TOTAUX ==='])
      ..add(['Total encaissé du mois', totalPaye]);

    return _saveCsv(rows, 'rapport_${year}_${month.toString().padLeft(2, '0')}');
  }

  /// تصدير تقرير يومي
  Future<String?> exportRapportJour(DateTime day) async {
    final pb = PbClient.instance.pb;
    final s = DateTime(day.year, day.month, day.day);
    final e = s.add(const Duration(days: 1));

    final paiements = await pb.collection('paiements').getFullList(
      filter: 'date >= "${s.toIso8601String()}" && date < "${e.toIso8601String()}"',
      sort: 'date', expand: 'patient,acte');

    final rows = <List<dynamic>>[
      ['Cabinet Dentaire — Rapport journalier'],
      ['Journée du', _df.format(day)],
      [],
      ['Date', 'Patient', 'N° dossier', 'Acte', 'Montant', 'Méthode'],
    ];

    double total = 0;
    for (final p in paiements) {
      final pe = p.expand['patient'];
      final ae = p.expand['acte'];
      final pn = (pe != null && pe.isNotEmpty)
          ? '${pe[0].getStringValue('prenom')} ${pe[0].getStringValue('nom')}' : '';
      final pno = (pe != null && pe.isNotEmpty)
          ? pe[0].getStringValue('numero_dossier') : '';
      final at = (ae != null && ae.isNotEmpty)
          ? ae[0].getStringValue('type') : '';
      final m = p.getDoubleValue('montant');
      total += m;
      rows.add([
        _df.format(p.getDateTimeValue('date') ?? DateTime.now()),
        pn, pno, at, m, p.getStringValue('methode'),
      ]);
    }

    rows
      ..add([])
      ..add(['Total du jour', total]);

    return _saveCsv(rows, 'rapport_jour_${day.year}_${day.month}_${day.day}');
  }

  Future<String?> _saveCsv(List<List<dynamic>> rows, String name) async {
    final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);
    try {
      final dir = await getDownloadsDirectory()
          ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$name.csv');
      // BOM UTF-8 pour Excel
      await file.writeAsString('\uFEFF$csv');
      return file.path;
    } catch (_) {
      return null;
    }
  }
}