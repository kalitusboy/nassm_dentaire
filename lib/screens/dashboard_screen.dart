import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/stock.dart';
import '../providers/auth_provider.dart';
import '../services/encaissement_service.dart';
import '../services/rapport_service.dart';
import '../services/rendez_vous_service.dart';
import '../services/salle_attente_service.dart';
import '../services/stock_service.dart';
import '../widgets/stat_card.dart';
import 'salle_attente/salle_attente_screen.dart';
import 'encaissements/encaissements_screen.dart';
import 'stock/stock_screen.dart';

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
                future: r.recetteAnnee(DateTime.now().year),
                builder: (_, s) => StatCard(
                  title: 'Recette de l\u2019année ${DateTime.now().year}',
                  icon: Icons.trending_up,
                  color: Colors.blue, value: s.hasData ? money.format(s.data) : '…'),
              ),
              FutureBuilder<double>(
                future: r.totalResteAPayer(),
                builder: (_, s) => StatCard(
                  title: 'Total reste à payer', icon: Icons.warning_amber,
                  color: Colors.orange, value: s.hasData ? money.format(s.data) : '…'),
              ),
            ]),
            const SizedBox(height: 24),
            // ── Raccourcis selon le rôle ──
            Wrap(spacing: 12, children: [
              if (auth.isReception || auth.isAdmin)
                OutlinedButton.icon(
                  icon: const Icon(Icons.chair, color: Colors.teal),
                  label: const Text('Salle d\u2019attente'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _Page(const SalleAttenteScreen())))),
              if (auth.isReception || auth.isAdmin)
                OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_active, color: Colors.orange),
                  label: const Text('Encaissements à valider'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _Page(const EncaissementsScreen())))),
            ]),
            const SizedBox(height: 24),
            // ── Alertes stock (admin / réception) ──
            if (auth.isAdmin || auth.isReception)
              FutureBuilder<List<StockItem>>(
                future: StockService().alertes(),
                builder: (_, s) {
                  if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
                  return Card(
                    color: Colors.red.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2, color: Colors.red),
                      title: Text('${s.data!.length} article(s) en alerte de stock',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(s.data!.take(3)
                        .map((a) => a.nom).join(', ') +
                        (s.data!.length > 3 ? '…' : '')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const _Page(StockScreen())))),
                  );
                }),
            const SizedBox(height: 24),
            // ── Encaissements en attente (réception) ──
            if (auth.isReception || auth.isAdmin)
              FutureBuilder(
                future: EncaissementService().enAttente(),
                builder: (_, s) {
                  if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
                  return Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active, color: Colors.orange),
                      title: Text('${s.data!.length} montant(s) à encaisser',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(s.data!.take(3)
                        .map((e) => '${e.patientNom} (${money.format(e.montant)})')
                        .join(', ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const _Page(const EncaissementsScreen())))),
                  );
                }),
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

// Pages simples pour l'ouverture depuis le tableau de bord.
class _Page extends StatelessWidget {
  final Widget child;
  const _Page(this.child);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(), body: child);
}