import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/caisse_service.dart';
import '../../services/parametre_service.dart';
import '../../widgets/encaissement_dialog.dart';
import '../../services/pdf_service.dart';
import '../../services/rapport_service.dart';
import '../../services/report_service.dart';
import '../../utils/fmt.dart';
import '../../widgets/mini_bar_chart.dart';
import '../../widgets/period_bar.dart';

/// Fenêtre « Recettes » : journal de caisse jour / mois / année.
class RecetteScreen extends StatefulWidget {
  const RecetteScreen({super.key});
  @override
  State<RecetteScreen> createState() => _RecetteScreenState();
}

class _RecetteScreenState extends State<RecetteScreen> {
  final _svc = ReportService();
  Granularite _gran = Granularite.jour;
  DateTime _ref = DateTime.now();
  ReportData? _data;
  double _resteGlobal = 0;
  List<Debiteur> _debiteurs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _svc.build(_gran, _ref);
      double reste = 0;
      List<Debiteur> deb = [];
      try {
        reste = await RapportService().totalResteAPayer();
        deb = await CaisseService().debiteurs();
      } catch (_) {}
      if (mounted) {
        setState(() { _data = d; _resteGlobal = reste; _debiteurs = deb; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 6)));
  }

  Future<void> _export() async {
    final d = _data;
    if (d == null) return;
    final p = await ParametreService().get();
    final path = await _svc.exportCsv(d, clinic: p?.nomClinique ?? 'DentaGest');
    _snack(path != null ? 'Exporté : $path' : 'Erreur d\'export');
  }

  Future<void> _encaisser(Debiteur d) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => EncaissementDialog(patientId: d.patientId, patientNom: d.nom),
    );
    _load();
  }

  Future<void> _annulerPaiement(PaiementLigne l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Annuler ce paiement ?'),
        content: Text('${l.patient} — ${fmtMoney(l.montant)} (${fmtDateTime(l.date)})\n\n'
            'Le montant sera de nouveau dû par le patient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Annuler le paiement')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CaisseService().deletePaiement(l.id);
      _load();
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _print() async {
    final d = _data;
    if (d == null) return;
    await PdfService().imprimerRapport(
        parametre: await ParametreService().get(), data: d, detail: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recettes'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, tooltip: 'Actualiser', icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: d == null ? null : _export,
              tooltip: 'Exporter en CSV (Excel)',
              icon: const Icon(Icons.file_download)),
          IconButton(
              onPressed: d == null ? null : _print,
              tooltip: 'Imprimer le rapport',
              icon: const Icon(Icons.print)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PeriodBar(
            gran: _gran,
            ref: _ref,
            onChanged: (g, r) {
              setState(() { _gran = g; _ref = r; });
              _load();
            },
          ),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (!_loading && d != null) ...[
            Wrap(spacing: 12, runSpacing: 12, children: [
              _kpi('Recette encaissée', fmtMoney(d.totalRecette), Icons.payments, Colors.teal),
              _kpi('Encaissements', '${d.nbPaiements}', Icons.receipt_long, Colors.indigo),
              _kpi('Montant facturé', fmtMoney(d.totalFacture), Icons.request_quote, Colors.blueGrey),
              _kpi('Reste à payer (global)', fmtMoney(_resteGlobal), Icons.warning_amber, Colors.orange),
            ]),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_gran == Granularite.jour
                      ? 'Recette par heure'
                      : _gran == Granularite.mois ? 'Recette par jour' : 'Recette par mois',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  MiniBarChart(data: d.serie),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, children: [
              _breakdown('Par mode de paiement', d.parMethode),
              _breakdown('Par médecin', d.parMedecin),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Restes à payer (${_debiteurs.length} patient(s))',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_debiteurs.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('Aucun reste à payer')),
                  for (final dbt in _debiteurs.take(30))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text(dbt.nom),
                      subtitle: Text('Reste : ${fmtMoney(dbt.reste)}'),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _encaisser(dbt),
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Encaisser'),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('Détail des encaissements (${d.lignes.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (d.lignes.isEmpty)
                    const Padding(padding: EdgeInsets.all(16), child: Text('Aucun encaissement sur cette période')),
                  for (final l in d.lignes.reversed.take(200))
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.receipt, color: Colors.green),
                      title: Text(l.patient),
                      subtitle: Text('${fmtDateTime(l.date)} • ${l.acte.isEmpty ? '—' : l.acte} • ${l.methode}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(fmtMoney(l.montant),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (context.read<AuthProvider>().isAdmin)
                          IconButton(
                            tooltip: 'Annuler ce paiement (saisi par erreur)',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _annulerPaiement(l),
                          ),
                      ]),
                    ),
                  if (d.lignes.length > 200)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Seuls les 200 derniers sont affichés — l\'export contient tout.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpi(String t, String v, IconData i, Color c) => SizedBox(
        width: 250,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(i, color: c, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _breakdown(String title, Map<String, double> m) => SizedBox(
        width: 380,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (m.isEmpty) const Text('—'),
              for (final e in m.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(e.key)),
                    Text(fmtMoney(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ),
      );
}
