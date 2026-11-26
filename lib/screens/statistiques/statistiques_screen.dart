import 'package:flutter/material.dart';

import '../../services/parametre_service.dart';
import '../../services/pdf_service.dart';
import '../../services/report_service.dart';
import '../../utils/fmt.dart';
import '../../widgets/mini_bar_chart.dart';
import '../../widgets/period_bar.dart';

/// Statistiques générales du cabinet (activité + chiffre d'affaires).
class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});
  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  final _svc = ReportService();
  Granularite _gran = Granularite.mois;
  DateTime _ref = DateTime.now();
  ReportData? _data;
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
      if (mounted) setState(() { _data = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _export() async {
    final d = _data;
    if (d == null) return;
    final p = await ParametreService().get();
    final path = await _svc.exportCsv(d, clinic: p?.nomClinique ?? 'DentaGest');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? 'Exporté : $path' : 'Erreur d\'export'),
        duration: const Duration(seconds: 6)));
  }

  Future<void> _print() async {
    final d = _data;
    if (d == null) return;
    await PdfService().imprimerRapport(
        parametre: await ParametreService().get(), data: d, detail: false);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
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
              _kpi('Montant facturé', fmtMoney(d.totalFacture), Icons.request_quote, Colors.blueGrey),
              _kpi('Patients vus', '${d.nbPatientsVus}', Icons.people, Colors.indigo),
              _kpi('Nouveaux patients', '${d.nbNouveauxPatients}', Icons.person_add, Colors.purple),
              _kpi('Actes réalisés', '${d.nbActes}', Icons.medical_services, Colors.blue),
              _kpi('Rendez-vous', '${d.nbRdv}', Icons.calendar_month, Colors.orange),
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
                  MiniBarChart(data: d.serie, color: Colors.indigo),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Actes par type', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (d.nbParType.isEmpty) const Text('Aucun acte sur cette période'),
                  for (final e in (d.nbParType.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value))))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(e.key)),
                        Expanded(
                          flex: 4,
                          child: LinearProgressIndicator(
                            value: d.nbActes == 0 ? 0 : e.value / d.nbActes,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                        SizedBox(width: 40, child: Text('${e.value}', textAlign: TextAlign.right)),
                        SizedBox(
                          width: 110,
                          child: Text(fmtMoney(d.factureParType[e.key] ?? 0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, children: [
              _breakdown('Recette par mode de paiement', d.parMethode),
              _breakdown('Recette par médecin', d.parMedecin),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _kpi(String t, String v, IconData i, Color c) => SizedBox(
        width: 240,
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
