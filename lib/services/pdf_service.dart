import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/acte.dart';
import '../models/ordonnance.dart';
import '../models/paiement.dart';
import '../models/parametre.dart';
import '../models/patient.dart';
import '../models/rendez_vous.dart';

class PdfService {
  final _df = DateFormat('dd/MM/yyyy', 'fr_FR');
  final _hf = DateFormat('HH:mm', 'fr_FR');
  final _money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  pw.Widget _entete(Parametre? p) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(p?.nomClinique ?? 'Cabinet Dentaire',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(p?.titrePraticien ?? 'Chirurgien Dentiste',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (p != null && p.numeroOrdre.isNotEmpty)
                    pw.Text('N° Ordre : ${p.numeroOrdre}',
                        style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(p?.adresse ?? '', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('Tél : ${p?.telephone ?? ""}',
                      style: const pw.TextStyle(fontSize: 9)),
                  if (p != null && p.email.isNotEmpty)
                    pw.Text(p.email, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1.5, color: PdfColors.teal),
        ],
      );

  pw.Widget _footer() => pw.Column(
        children: [
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        ],
      );

  // ═══════ ORDONNANCE (A5 par défaut) ═══════
  Future<void> imprimerOrdonnance({
    required Parametre? parametre,
    required Patient patient,
    required Ordonnance ordonnance,
    PdfPageFormat format = PdfPageFormat.a5,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.all(format.width * 0.06),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _entete(parametre),
          pw.SizedBox(height: 12),
          pw.Center(child: pw.Text('ORDONNANCE MÉDICALE',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Patient : ${patient.fullName}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Date : ${_df.format(ordonnance.date)}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          if (patient.age != null)
            pw.Text('Âge : ${patient.age} ans',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 14),
          pw.Divider(thickness: 0.5, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text('Prescription :',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ...ordonnance.medicaments.asMap().entries.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${e.key + 1}. ${e.value.nom.toUpperCase()}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('   ${e.value.posologie} — Durée : ${e.value.duree}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              )),
          if (ordonnance.instructions.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('Instructions : ${ordonnance.instructions}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
          pw.Spacer(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Signature et cachet',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 40),
                pw.Container(width: 120, height: 0.8, color: PdfColors.grey600),
              ],
            ),
          ),
          _footer(),
        ],
      ),
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Ordonnance_${patient.fullName}_${_df.format(ordonnance.date)}',
      format: format,
      formats: const [PdfPageFormat.a4, PdfPageFormat.a5],
    );
  }

  // ═══════ RENDEZ-VOUS (A4) ═══════
  Future<void> imprimerRendezVousDuJour({
    required Parametre? parametre,
    required DateTime jour,
    required List<RendezVous> rdvs,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _entete(parametre),
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text('LISTE DES RENDEZ-VOUS',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text('Journée du ${_df.format(jour)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Heure', 'Patient', 'Médecin', 'Motif', 'Statut'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
          data: rdvs.map((r) => [
                _hf.format(r.dateHeure), r.patientNom,
                'Dr. ${r.medecinNom}', r.motif, r.statut,
              ]).toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Text('Total : ${rdvs.length} rendez-vous',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'RDV_${_df.format(jour)}',
      format: format,
    );
  }

  // ═══════ FACTURE (A5) ═══════
  Future<void> imprimerFacture({
    required Parametre? parametre,
    required Patient patient,
    required List<Acte> actes,
    required double totalPaye,
    PdfPageFormat format = PdfPageFormat.a5,
  }) async {
    final doc = pw.Document();
    final total = actes.fold<double>(0, (s, a) => s + a.montantTotal);
    final reste = total - totalPaye;

    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.all(format.width * 0.06),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _entete(parametre),
          pw.SizedBox(height: 10),
          pw.Center(child: pw.Text('FACTURE',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Patient : ${patient.fullName}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('N° ${patient.numeroDossier}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.Text('Date : ${_df.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Acte', 'Dent', 'Montant'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
            data: actes.map((a) => [
                  _df.format(a.date), a.typeLibelle,
                  a.dent?.toString() ?? '-', _money.format(a.montantTotal),
                ]).toList(),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Total : ${_money.format(total)}',
                    style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Payé : ${_money.format(totalPaye)}',
                    style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Reste : ${_money.format(reste)}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Signature et cachet',
                style: const pw.TextStyle(fontSize: 9)),
          ),
          _footer(),
        ],
      ),
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Facture_${patient.fullName}',
      format: format,
      formats: const [PdfPageFormat.a4, PdfPageFormat.a5],
    );
  }

  // ═══════ RELEVÉ DE COMPTE (A4) ═══════
  Future<void> imprimerReleveCompte({
    required Parametre? parametre,
    required Patient patient,
    required List<Acte> actes,
    required List<Paiement> paiements,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final tx = <_Tx>[];
    for (final a in actes) {
      tx.add(_Tx(a.date, 'Acte',
          '${a.typeLibelle}${a.dent != null ? " — Dent ${a.dent}" : ""}',
          a.montantTotal, 0));
    }
    for (final p in paiements) {
      tx.add(_Tx(p.date, 'Paiement', 'Règlement (${p.methode})', 0, p.montant));
    }
    tx.sort((a, b) => a.date.compareTo(b.date));

    double solde = 0;
    final rows = tx.map((t) {
      solde += t.debit - t.credit;
      return [
        _df.format(t.date), t.type, t.desc,
        t.debit > 0 ? _money.format(t.debit) : '',
        t.credit > 0 ? _money.format(t.credit) : '',
        _money.format(solde),
      ];
    }).toList();

    final totalD = tx.fold<double>(0, (s, t) => s + t.debit);
    final totalC = tx.fold<double>(0, (s, t) => s + t.credit);
    final reste = totalD - totalC;

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _entete(parametre),
        pw.SizedBox(height: 10),
        pw.Center(child: pw.Text('RELEVÉ DE COMPTE PATIENT',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient : ${patient.fullName}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text('N° dossier : ${patient.numeroDossier}',
                    style: const pw.TextStyle(fontSize: 10)),
                if (patient.telephone.isNotEmpty)
                  pw.Text('Tél : ${patient.telephone}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Text('Date : ${_df.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 12),
        if (rows.isEmpty)
          pw.Padding(padding: const pw.EdgeInsets.all(20),
            child: pw.Center(child: pw.Text('Aucune transaction enregistrée')))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Description', 'Débit', 'Crédit', 'Solde'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
            cellAlignments: {
              0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight,
            },
            data: rows,
          ),
        pw.SizedBox(height: 16),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total débit : ${_money.format(totalD)}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Total crédit : ${_money.format(totalC)}',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(thickness: 1),
              pw.Text(
                reste >= 0
                    ? 'Reste à payer : ${_money.format(reste)}'
                    : 'Crédit patient : ${_money.format(-reste)}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,
                    color: reste > 0 ? PdfColors.red800 : PdfColors.green800),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 30),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Signature du praticien',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text('Signature du patient',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
        ),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Releve_${patient.fullName}',
      format: format,
    );
  }
}

class _Tx {
  final DateTime date;
  final String type, desc;
  final double debit, credit;
  _Tx(this.date, this.type, this.desc, this.debit, this.credit);
}