import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/file_attente.dart';
import '../models/rendez_vous.dart';
import '../providers/auth_provider.dart';
import '../services/caisse_service.dart';
import '../services/file_attente_service.dart';
import '../services/patient_service.dart';
import '../services/rapport_service.dart';
import '../services/rendez_vous_service.dart';
import '../services/stock_service.dart';
import '../utils/fmt.dart';
import '../widgets/app_logo.dart';
import '../widgets/stat_card.dart';

/// Tableau de bord : indicateurs du jour selon le rôle, chaque carte ouvre sa fenêtre.
class DashboardScreen extends StatefulWidget {
  /// Ouvre une fenêtre du menu : 'attente', 'rdv', 'recettes', 'stock', 'patients'.
  final void Function(String id) onOpen;
  const DashboardScreen({super.key, required this.onOpen});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  bool _loading = true;
  List<FileAttente> _file = [];
  List<RendezVous> _rdvs = [];
  double _recetteJour = 0, _resteTotal = 0, _aEncaisserMontant = 0;
  int _alertesStock = 0, _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final auth = context.read<AuthProvider>();
    final finance = auth.isReception || auth.isAdmin;
    if (!silent) setState(() => _loading = true);
    try {
      final file = await FileAttenteService().listToday();
      final rdvs = await RendezVousService().listForDay(DateTime.now());
      double rec = 0, reste = 0, enc = 0;
      if (finance) {
        final r = RapportService();
        rec = await r.recetteJour(DateTime.now());
        reste = await r.totalResteAPayer();
      }
      final caisse = CaisseService();
      for (final f in file.where((f) => f.statut == 'a_encaisser')) {
        final dus = await caisse.actesDus(f.patientId);
        enc += dus.fold<double>(0, (s, d) => s + d.reste);
      }
      int alertes = 0, total = 0;
      try { alertes = await StockService().countAlertes(); } catch (_) {}
      try { total = (await PatientService().searchPage('', perPage: 1)).totalItems; } catch (_) {}
      if (!mounted) return;
      setState(() {
        _file = file;
        _rdvs = rdvs;
        _recetteJour = rec;
        _resteTotal = reste;
        _aEncaisserMontant = enc;
        _alertesStock = alertes;
        _totalPatients = total;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _tap(String id, Widget child) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onOpen(id),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finance = auth.isReception || auth.isAdmin;
    final attente = _file.where((f) => f.statut == 'attente').length;
    final consult = _file.where((f) => f.statut == 'en_consultation').length;
    final enc = _file.where((f) => f.statut == 'a_encaisser').length;
    final termines = _file.where((f) => f.statut == 'termine').length;
    final actifs = _file
        .where((f) => f.statut == 'attente' || f.statut == 'en_consultation' || f.statut == 'a_encaisser')
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: [
                Row(children: [
                  const ClinicLogo(size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bonjour, ${auth.fullName.isEmpty ? 'Administrateur' : auth.fullName}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(DateFormat.yMMMMEEEEd('fr_FR').format(DateTime.now()),
                          style: TextStyle(color: Colors.grey.shade700)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                Wrap(spacing: 16, runSpacing: 16, children: [
                  _tap('attente', StatCard(
                      title: 'En salle d\'attente', icon: Icons.hourglass_top,
                      color: Colors.orange, value: '$attente')),
                  _tap('attente', StatCard(
                      title: 'En consultation', icon: Icons.work,
                      color: Colors.blue, value: '$consult')),
                  _tap('attente', StatCard(
                        title: 'À encaisser ($enc)', icon: Icons.payments,
                        color: Colors.green.shade700,
                        value: enc == 0 ? '—' : fmtMoney(_aEncaisserMontant))),
                  _tap('attente', StatCard(
                      title: 'Patients reçus', icon: Icons.check_circle,
                      color: Colors.teal, value: '$termines')),
                  _tap('rdv', StatCard(
                      title: 'Rendez-vous du jour', icon: Icons.calendar_month,
                      color: Colors.indigo, value: '${_rdvs.length}')),
                  if (finance)
                    _tap('recettes', StatCard(
                        title: 'Recette du jour', icon: Icons.today,
                        color: Colors.teal, value: fmtMoney(_recetteJour))),
                  if (finance)
                    _tap('recettes', StatCard(
                        title: 'Total reste à payer', icon: Icons.warning_amber,
                        color: Colors.deepOrange, value: fmtMoney(_resteTotal))),
                  _tap('stock', StatCard(
                      title: 'Articles en alerte', icon: Icons.inventory_2,
                      color: _alertesStock > 0 ? Colors.red : Colors.blueGrey,
                      value: '$_alertesStock')),
                  _tap('patients', StatCard(
                      title: 'Patients (total)', icon: Icons.people,
                      color: Colors.purple, value: '$_totalPatients')),
                ]),
                const SizedBox(height: 28),
                Row(children: [
                  Text('Salle d\'attente',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const Spacer(),
                  TextButton(onPressed: () => widget.onOpen('attente'), child: const Text('Ouvrir')),
                ]),
                if (actifs.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('Personne en salle d\'attente'))
                else
                  Card(
                    child: Column(children: [
                      for (final f in actifs.take(6))
                        ListTile(
                          dense: true,
                          leading: Icon(
                            f.statut == 'attente' ? Icons.hourglass_top
                                : f.statut == 'en_consultation' ? Icons.work : Icons.payments,
                            color: f.statut == 'attente' ? Colors.orange
                                : f.statut == 'en_consultation' ? Colors.blue : Colors.green.shade700,
                          ),
                          title: Text(f.patientNom),
                          subtitle: Text('Arrivé à ${fmtTime(f.heureArrivee)}'
                              '${f.medecinNom.isEmpty ? '' : ' • Dr. ${f.medecinNom}'}'),
                          trailing: Text(f.statutLibelle),
                        ),
                    ]),
                  ),
                const SizedBox(height: 20),
                Text('Rendez-vous du jour',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                const SizedBox(height: 8),
                if (_rdvs.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('Aucun rendez-vous aujourd\'hui'))
                else
                  Card(
                    child: Column(children: _rdvs.map((r) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.access_time, color: Colors.teal),
                          title: Text('${DateFormat('HH:mm').format(r.dateHeure)} — ${r.patientNom}'),
                          subtitle: Text('${r.motif} • Dr. ${r.medecinNom}'),
                          trailing: Chip(label: Text(r.statut), visualDensity: VisualDensity.compact),
                        )).toList()),
                  ),
              ]),
            ),
    );
  }
}
