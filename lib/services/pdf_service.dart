import 'dart:typed_data';
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
import 'parametre_service.dart';
import 'report_service.dart';

class PdfService {
  final _df = DateFormat('dd/MM/yyyy', 'fr_FR');
  final _hf = DateFormat('HH:mm', 'fr_FR');
  final _money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  /// Logo du cabinet pour les en-têtes (null si aucun).
  Future<pw.MemoryImage?> _logo() async {
    final Uint8List? b = await ParametreService().logoBytes();
    return b == null ? null : pw.MemoryImage(b);
  }

  pw.Widget _entete(Parametre? p, [pw.MemoryImage? logo]) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                if (logo != null) ...[
                  pw.Container(
                      width: 46, height: 46,
                      child: pw.Image(logo, fit: pw.BoxFit.contain)),
                  pw.SizedBox(width: 8),
                ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(p?.nomClinique ?? 'DentaGest',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(p?.titrePraticien ?? 'Chirurgien Dentiste',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (p != null && p.numeroOrdre.isNotEmpty)
                    pw.Text('N° Ordre : ${p.numeroOrdre}',
                        style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              ]),
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
    final logo = await _logo();
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.all(format.width * 0.06),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _entete(parametre, logo),
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
    final logo = await _logo();
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _entete(parametre, logo),
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

  // ═══════ FACTURE (A5) — complète : patient, actes, règlements ═══════
  Future<void> imprimerFacture({
    required Parametre? parametre,
    required Patient patient,
    required List<Acte> actes,
    required double totalPaye,
    List<Paiement> paiements = const [],
    PdfPageFormat format = PdfPageFormat.a5,
  }) async {
    final doc = pw.Document();
    final logo = await _logo();
    final total = actes.fold<double>(0, (s, a) => s + a.montantTotal);
    final reste = total - totalPaye;
    final now = DateTime.now();
    final numero = 'F-${patient.numeroDossier}-${DateFormat('yyyyMMdd').format(now)}';
    const modes = {'espece': 'Espèces', 'cheque': 'Chèque', 'carte': 'Carte', 'virement': 'Virement'};

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: pw.EdgeInsets.all(format.width * 0.06),
      build: (_) => [
        _entete(parametre, logo),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('FACTURE',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('N° $numero', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Text('Date : ${_df.format(now)}', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Patient : ${patient.fullName}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text('Dossier N° ${patient.numeroDossier}',
                style: const pw.TextStyle(fontSize: 9)),
            if (patient.dateNaissance != null)
              pw.Text('Né(e) le ${_df.format(patient.dateNaissance!)}',
                  style: const pw.TextStyle(fontSize: 9)),
            if (patient.telephone.isNotEmpty)
              pw.Text('Tél. : ${patient.telephone}', style: const pw.TextStyle(fontSize: 9)),
            if (patient.adresse.isNotEmpty)
              pw.Text('Adresse : ${patient.adresse}', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.SizedBox(height: 10),
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
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total : ${_money.format(total)}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Payé : ${_money.format(totalPaye)}', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Reste à payer : ${_money.format(reste < 0 ? 0 : reste)}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        if (paiements.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Règlements reçus',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Mode', 'Montant'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            data: paiements.map((p) => [
                  _df.format(p.date), modes[p.methode] ?? p.methode, _money.format(p.montant),
                ]).toList(),
          ),
        ],
        pw.SizedBox(height: 22),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Signature et cachet', style: const pw.TextStyle(fontSize: 9)),
        ),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Facture_${patient.fullName}',
      format: format,
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
    final logo = await _logo();
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
        _entete(parametre, logo),
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
  // ═══════ LISTE DES RENDEZ-VOUS (période choisie) ═══════
  Future<void> imprimerListeRendezVous({
    required Parametre? parametre,
    required String titre,
    required List<RendezVous> rdvs,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final logo = await _logo();
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _entete(parametre, logo),
        pw.SizedBox(height: 12),
        pw.Center(child: pw.Text('LISTE DES RENDEZ-VOUS',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text(titre,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Heure', 'Patient', 'Médecin', 'Motif', 'Statut'],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
          data: rdvs.map((r) => [
                _df.format(r.dateHeure), _hf.format(r.dateHeure), r.patientNom,
                r.medecinNom.isEmpty ? '' : 'Dr. ${r.medecinNom}', r.motif, r.statut,
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
      name: 'Liste_RDV',
      format: format,
    );
  }

  // ═══════ CARTE DE RENDEZ-VOUS DU PATIENT (une seule carte) ═══════
  Future<void> imprimerCarteRendezVous({
    required Parametre? parametre,
    required Patient patient,
    required List<RendezVous> rdvs,
    bool tous = false, // true : tous les rendez-vous du patient sur une feuille A4
    PdfPageFormat format = PdfPageFormat.a6,
  }) async {
    final doc = pw.Document();
    final logo = await _logo();
    final dfl = DateFormat('EEE dd/MM/yyyy', 'fr_FR');
    final sorted = [...rdvs]..sort((a, b) => a.dateHeure.compareTo(b.dateHeure));
    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(18),
      build: (_) => [
        _entete(parametre, logo),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text(tous ? 'LISTE DES RENDEZ-VOUS' : 'CARTE DE RENDEZ-VOUS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Text(patient.fullName,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text('Dossier N° ${patient.numeroDossier}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        if (sorted.isEmpty)
          pw.Text('Aucun rendez-vous à venir.', style: const pw.TextStyle(fontSize: 10))
        else
          pw.TableHelper.fromTextArray(
            headers: tous
                ? ['Date', 'Heure', 'Médecin', 'Motif', 'Statut']
                : ['Date', 'Heure', 'Médecin', 'Motif'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            data: sorted.map((r) => [
                  dfl.format(r.dateHeure),
                  _hf.format(r.dateHeure),
                  r.medecinNom.isEmpty ? '' : 'Dr. ${r.medecinNom}',
                  r.motif,
                  if (tous) r.statut,
                ]).toList(),
          ),
        pw.SizedBox(height: 10),
        pw.Text(
            'Merci de vous présenter quelques minutes avant l\'heure. '
            'En cas d\'empêchement, prévenez-nous'
            '${parametre != null && parametre.telephone.isNotEmpty ? ' au ${parametre.telephone}' : ''}.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: '${tous ? 'Liste_RDV' : 'Carte_RDV'}_${patient.fullName}',
      format: format,
    );
  }

  // ═══════ RAPPORT (jour / mois / année) ═══════
  Future<void> imprimerRapport({
    required Parametre? parametre,
    required ReportData data,
    bool detail = true,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final doc = pw.Document();
    final logo = await _logo();
    pw.Widget section(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        );
    pw.Widget tableOf(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
          headers: headers,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.teal100),
          data: rows,
        );

    doc.addPage(pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(30),
      build: (_) => [
        _entete(parametre, logo),
        pw.SizedBox(height: 10),
        pw.Center(child: pw.Text(data.titre.toUpperCase(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text(data.libellePeriode,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
        section('Résumé'),
        tableOf(['Indicateur', 'Valeur'], [
          ['Recette encaissée', _money.format(data.totalRecette)],
          ['Montant facturé (actes)', _money.format(data.totalFacture)],
          ['Nombre d\'encaissements', '${data.nbPaiements}'],
          ['Actes réalisés', '${data.nbActes}'],
          ['Patients vus', '${data.nbPatientsVus}'],
          ['Nouveaux patients', '${data.nbNouveauxPatients}'],
          ['Rendez-vous', '${data.nbRdv}'],
        ]),
        section('Recette par mode de paiement'),
        tableOf(['Mode', 'Montant'],
            data.parMethode.entries.map((e) => [e.key, _money.format(e.value)]).toList()),
        section('Recette par médecin'),
        tableOf(['Médecin', 'Montant'],
            data.parMedecin.entries.map((e) => [e.key, _money.format(e.value)]).toList()),
        section('Actes par type'),
        tableOf(['Type', 'Nombre', 'Montant facturé'],
            data.nbParType.entries
                .map((e) => [e.key, '${e.value}', _money.format(data.factureParType[e.key] ?? 0)])
                .toList()),
        if (detail) ...[
          section('Détail des encaissements'),
          tableOf(['Date', 'Patient', 'Acte', 'Mode', 'Montant'],
              data.lignes.map((l) => [
                    '${_df.format(l.date)} ${_hf.format(l.date)}',
                    l.patient, l.acte, l.methode, _money.format(l.montant),
                  ]).toList()),
        ],
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('TOTAL ENCAISSÉ : ${_money.format(data.totalRecette)}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Rapport_${data.gran.name}_${_df.format(data.from)}',
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