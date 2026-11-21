import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/rapport_service.dart';
import '../services/rendez_vous_service.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final r = RapportService();
    final rdvSvc = RendezVousService();
    final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour, ${auth.fullName}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(DateFormat.yMMMMEEEEd('fr_FR').format(DateTime.now()),
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 24),
            Wrap(spacing: 16, runSpacing: 16, children: [
              FutureBuilder<double>(
                future: r.recetteJour(DateTime.now()),
                builder: (_, s) => StatCard(
                  title: 'Recette du jour', icon: Icons.today, color: Colors.teal,
                  value: s.hasData ? money.format(s.data) : '…'),
              ),
              FutureBuilder<double>(
                future: r.recetteMois(DateTime.now().year, DateTime.now().month),
                builder: (_, s) => StatCard(
                  title: 'Recette du mois', icon: Icons.calendar_month,
                  color: Colors.indigo, value: s.hasData ? money.format(s.data) : '…'),
              ),
              FutureBuilder<double>(
                future: r.totalResteAPayer(),
                builder: (_, s) => StatCard(
                  title: 'Total reste à payer', icon: Icons.warning_amber,
                  color: Colors.orange, value: s.hasData ? money.format(s.data) : '…'),
              ),
            ]),
            const SizedBox(height: 32),
            Text('Rendez-vous du jour',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            FutureBuilder(
              future: rdvSvc.listForDay(DateTime.now()),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
                }
                final rdvs = snap.data ?? [];
                if (rdvs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucun rendez-vous aujourd\'hui'));
                }
                return Card(
                  child: Column(
                    children: rdvs.map((r) => ListTile(
                      leading: const Icon(Icons.access_time, color: Colors.teal),
                      title: Text('${DateFormat('HH:mm').format(r.dateHeure)} — ${r.patientNom}'),
                      subtitle: Text('${r.motif} • Dr. ${r.medecinNom}'),
                      trailing: Chip(label: Text(r.statut),
                        visualDensity: VisualDensity.compact),
                    )).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}