import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/encaissement.dart';
import '../../services/encaissement_service.dart';
import '../paiements/paiement_form_screen.dart';

/// Notifications d'encaissement : la réception voit ici les actes terminés
/// dont le montant a été fixé par le médecin, et encaisse en un clic.
class EncaissementsScreen extends StatefulWidget {
  const EncaissementsScreen({super.key});
  @override
  State<EncaissementsScreen> createState() => _EncaissementsScreenState();
}

class _EncaissementsScreenState extends State<EncaissementsScreen> {
  final _svc = EncaissementService();
  List<Encaissement> _attente = [], _jour = [];
  bool _loading = true;
  final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final a = await _svc.enAttente();
    final j = await _svc.listForDay(DateTime.now());
    if (mounted) setState(() { _attente = a; _jour = j; _loading = false; });
  }

  Future<void> _encaisser(Encaissement e) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaiementFormScreen(patientId: e.patientId, acteId: e.acteId)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hf = DateFormat('HH:mm', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DefaultTabController(length: 2, child: Column(children: [
        const TabBar(tabs: [
          Tab(text: 'À encaisser'),
          Tab(text: 'Encaissements du jour'),
        ]),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(children: [
              _attente.isEmpty
                ? const Center(child: Text('Aucun montant en attente'))
                : ListView(children: _attente.map((e) => Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active,
                          color: Colors.orange),
                      title: Text('${e.patientNom} — ${money.format(e.montant)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${e.acteType} • Dr. ${e.medecinNom} • ${hf.format(e.cree)}'),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.payments),
                        label: const Text('Encaisser'),
                        onPressed: () => _encaisser(e)),
                    ))).toList()),
              _jour.isEmpty
                ? const Center(child: Text('Aucun encaissement aujourd\u2019hui'))
                : ListView(children: _jour.map((e) => Card(child: ListTile(
                    leading: Icon(e.estEncaisse ? Icons.check_circle : Icons.schedule,
                      color: e.estEncaisse ? Colors.green : Colors.orange),
                    title: Text('${e.patientNom} — ${money.format(e.montant)}'),
                    subtitle: Text('${e.acteType} • Dr. ${e.medecinNom} • ${hf.format(e.cree)}'),
                    trailing: Chip(label: Text(e.estEncaisse ? 'Encaissé' : 'En attente'),
                      visualDensity: VisualDensity.compact),
                  ))).toList()),
            ])),
      ])),
    );
  }
}
