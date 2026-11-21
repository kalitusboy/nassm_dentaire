import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/excel_service.dart';
import '../../services/rapport_service.dart';

class RecetteScreen extends StatefulWidget {
  const RecetteScreen({super.key});
  @override
  State<RecetteScreen> createState() => _RecetteScreenState();
}

class _RecetteScreenState extends State<RecetteScreen> {
  final _svc = RapportService();
  final _excel = ExcelService();
  DateTime _date = DateTime.now();
  final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  Future<void> _exportMois() async {
    final path = await _excel.exportRapportMensuel(_date.year, _date.month);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null
          ? 'Exporté : $path'
          : 'Erreur d\'export'),
        duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _exportJour() async {
    final path = await _excel.exportRapportJour(DateTime.now());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? 'Exporté : $path' : 'Erreur d\'export'),
        duration: const Duration(seconds: 5)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat.yMMMM('fr_FR').format(_date);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rapports de recettes',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() =>
                _date = DateTime(_date.year, _date.month - 1, 1))),
            Text(monthName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
                _date = DateTime(_date.year, _date.month + 1, 1))),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('Export jour CSV'),
              onPressed: _exportJour),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download),
              label: const Text('Export mois CSV'),
              onPressed: _exportMois),
          ]),
          const SizedBox(height: 16),
          _card('Recette du jour', Icons.today, Colors.teal,
            _svc.recetteJour(DateTime.now())),
          const SizedBox(height: 8),
          _card('Recette de $monthName', Icons.calendar_month, Colors.indigo,
            _svc.recetteMois(_date.year, _date.month)),
          const SizedBox(height: 8),
          _card('Total reste à payer (global)', Icons.warning_amber, Colors.orange,
            _svc.totalResteAPayer()),
          const SizedBox(height: 24),
          const Text('Recette du jour par médecin',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, double>>(
            future: _svc.recetteParMedecin(DateTime.now()),
            builder: (_, s) {
              if (!s.hasData || s.data!.isEmpty) return const Text('Aucune donnée');
              return Column(children: s.data!.entries.map((e) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text('Dr. ${e.key}'),
                  trailing: Text(money.format(e.value),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                ))).toList());
            }),
          const SizedBox(height: 24),
          const Text('Détail des encaissements du jour',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _svc.detailRecetteJour(DateTime.now()),
            builder: (_, s) {
              if (!s.hasData || s.data!.isEmpty) {
                return const Card(child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Aucun encaissement aujourd\'hui')));
              }
              return Card(child: Column(children: s.data!.map((t) => ListTile(
                dense: true,
                leading: const Icon(Icons.receipt, color: Colors.green),
                title: Text(t['patient'] ?? '—'),
                subtitle: Text('${t['acte']} • ${t['methode']}'),
                trailing: Text(money.format(t['montant']),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              )).toList()));
            }),
        ]),
      ),
    );
  }

  Widget _card(String t, IconData i, Color c, Future<double> f) {
    return Card(child: ListTile(
      leading: Icon(i, color: c),
      title: Text(t),
      trailing: FutureBuilder<double>(
        future: f,
        builder: (_, s) => Text(
          s.hasData ? money.format(s.data) : '…',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))));
  }
}