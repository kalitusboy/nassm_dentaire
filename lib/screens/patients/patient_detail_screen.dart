import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/acte.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../services/acte_service.dart';
import '../../services/paiement_service.dart';
import '../../services/parametre_service.dart';
import '../../services/patient_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rendez_vous_service.dart';
import '../actes/acte_form_screen.dart';
import '../odontogrammes/odontogramme_widget.dart';
import '../ordonnances/ordonnance_form_screen.dart';
import '../paiements/paiement_form_screen.dart';
import '../radiographies/radiographie_screen.dart';
import 'patient_form_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});
  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with SingleTickerProviderStateMixin {
  final _patientSvc = PatientService();
  final _acteSvc = ActeService();
  final _paiSvc = PaiementService();
  final _rdvSvc = RendezVousService();
  late TabController _tabs;
  Patient? _patient;
  List<Acte> _actes = [];
  List<RendezVous> _rdvs = [];
  double _totalPaye = 0;
  Map<String, double> _paidByActe = {};
  DateTime? _lastVisit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // requêtes en parallèle ; une seule pour tous les paiements
      final (p, a, r, l, paiements) = await (
        _patientSvc.getById(widget.patientId),
        _patientSvc.actesForPatient(widget.patientId),
        _rdvSvc.listForPatient(widget.patientId),
        _patientSvc.lastVisit(widget.patientId),
        _paiSvc.listForPatient(widget.patientId),
      ).wait;
      final tp = paiements.fold<double>(0, (s, x) => s + x.montant);
      final byActe = <String, double>{};
      for (final x in paiements) {
        byActe[x.acteId] = (byActe[x.acteId] ?? 0) + x.montant;
      }
      if (!mounted) return;
      setState(() {
        _patient = p; _actes = a; _rdvs = r;
        _lastVisit = l; _totalPaye = tp; _paidByActe = byActe; _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  Future<void> _imprimerFacture() async {
    if (_patient == null) return;
    await PdfService().imprimerFacture(
      parametre: await ParametreService().get(),
      patient: _patient!, actes: _actes, totalPaye: _totalPaye);
  }

  /// Tous les rendez-vous à venir du patient sur UNE seule carte.
  Future<void> _imprimerCarteRdv() async {
    if (_patient == null) return;
    final now = DateTime.now().subtract(const Duration(hours: 1));
    final futurs = _rdvs
        .where((r) => r.statut != 'annule' && r.dateHeure.isAfter(now))
        .toList();
    if (futurs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun rendez-vous à venir pour ce patient.')));
      return;
    }
    await PdfService().imprimerCarteRendezVous(
        parametre: await ParametreService().get(), patient: _patient!, rdvs: futurs);
  }

  Future<void> _imprimerReleve() async {
    if (_patient == null) return;
    final paiements = await _paiSvc.listForPatient(_patient!.id);
    await PdfService().imprimerReleveCompte(
      parametre: await ParametreService().get(),
      patient: _patient!, actes: _actes, paiements: paiements);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _patient!;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.fullName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PatientFormScreen(patient: p)));
                _load();
              } else if (v == 'facture') { await _imprimerFacture(); }
              else if (v == 'releve') { await _imprimerReleve(); }
              else if (v == 'carte') { await _imprimerCarteRdv(); }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'facture', child: Text('Imprimer facture')),
              PopupMenuItem(value: 'releve', child: Text('Relevé de compte')),
              PopupMenuItem(value: 'carte', child: Text('Imprimer la carte de RDV')),
            ]),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Infos'),
            Tab(icon: Icon(Icons.medical_services), text: 'Actes'),
            Tab(icon: Icon(Icons.calendar_month), text: 'RDV'),
            Tab(icon: Icon(Icons.grid_on), text: 'Schéma dentaire'),
          ]),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildInfo(p),
          _buildActes(p),
          _buildRdv(),
          OdontogrammeWidget(patientId: p.id),
        ],
      ),
      floatingActionButton: _canActe(context)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ActeFormScreen(patientId: p.id)));
                _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Nouvel acte'))
          : null,
    );
  }

  // Le dentiste (et l'administrateur) saisit les actes et leur prix ;
  // la réception (et l'administrateur) enregistre les sommes encaissées.
  bool _canActe(BuildContext c) {
    final a = c.read<AuthProvider>();
    return a.isDentiste || a.isAdmin;
  }

  bool _canPay(BuildContext c) {
    final a = c.read<AuthProvider>();
    return a.isReception || a.isAdmin;
  }

  Widget _buildInfo(Patient p) {
    final df = DateFormat('dd/MM/yyyy', 'fr_FR');
    final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
    final total = _actes.fold<double>(0, (s, a) => s + a.montantTotal);
    final reste = total - _totalPaye;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _row('N° dossier', p.numeroDossier),
            _row('Nom complet', p.fullName),
            if (p.age != null) _row('Âge', '${p.age} ans'),
            if (p.dateNaissance != null) _row('Naissance', df.format(p.dateNaissance!)),
            _row('Téléphone', p.telephone),
            _row('Adresse', p.adresse),
            if (p.allergies.isNotEmpty) _row('Allergies', p.allergies, color: Colors.red),
            if (p.notesMedicales.isNotEmpty) _row('Notes', p.notesMedicales),
            _row('Dernière visite', _lastVisit != null ? df.format(_lastVisit!) : 'Aucune'),
          ]))),
        const SizedBox(height: 12),
        Card(
          color: Colors.teal.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Situation financière',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
              const SizedBox(height: 8),
              _row('Total facturé', money.format(total)),
              _row('Total payé', money.format(_totalPaye), color: Colors.green.shade700),
              _row('Reste à payer', money.format(reste),
                color: reste > 0 ? Colors.red : Colors.green),
            ]))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => OrdonnanceFormScreen(patientId: p.id)));
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ordonnance'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => RadiographieScreen(patientId: p.id)));
            },
            icon: const Icon(Icons.image),
            label: const Text('Radiographies'))),
        ]),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 130, child: Text('$label :',
        style: TextStyle(color: Colors.grey.shade700))),
      Expanded(child: Text(value, style: TextStyle(color: color))),
    ]));

  Widget _buildActes(Patient p) {
    final df = DateFormat('dd/MM/yyyy', 'fr_FR');
    final money = NumberFormat.currency(locale: 'fr_FR', symbol: 'DA', decimalDigits: 0);
    if (_actes.isEmpty) return const Center(child: Text('Aucun acte enregistré'));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _actes.map((a) {
        final paye = _paidByActe[a.id] ?? 0;
        final reste = a.montantTotal - paye;
        final fixe = a.montantTotal > 0;
        return Card(
          child: ListTile(
            onTap: _canActe(context)
                ? () async {
                    await Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                        ActeFormScreen(patientId: p.id, existing: a)));
                    _load();
                  }
                : null,
            title: Text('${a.typeLibelle}${a.dent != null ? " — Dent ${a.dent}" : ""}'),
            subtitle: Text('${df.format(a.date)} • Dr. ${a.medecinNom}\n'
              '${a.description.isEmpty ? "" : "${a.description}\n"}'
              'Statut : ${a.statut}\n'
              '${fixe ? "Payé : ${money.format(paye)}  •  Reste : ${money.format(reste < 0 ? 0 : reste)}" : "Prix non encore fixé par le dentiste"}'
              '${paye > 0 && !fixe ? "  •  Encaissé : ${money.format(paye)}" : ""}'),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fixe ? money.format(a.montantTotal) : '—',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                if (_canPay(context))
                  IconButton(
                    icon: const Icon(Icons.payments, color: Colors.green),
                    tooltip: 'Enregistrer un paiement',
                    onPressed: () async {
                      await Navigator.push(context,
                        MaterialPageRoute(builder: (_) =>
                          PaiementFormScreen(patientId: p.id, acteId: a.id)));
                      _load();
                    }),
              ]),
          ));
      }).toList(),
    );
  }

  Widget _buildRdv() {
    if (_rdvs.isEmpty) return const Center(child: Text('Aucun rendez-vous'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rdvs.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _imprimerCarteRdv,
                icon: const Icon(Icons.print),
                label: const Text('Imprimer la carte de RDV'),
              ),
            ),
          );
        }
        final r = _rdvs[i - 1];
        return Card(child: ListTile(
          leading: const Icon(Icons.event, color: Colors.teal),
          title: Text(DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(r.dateHeure)),
          subtitle: Text('${r.motif} • Dr. ${r.medecinNom}'),
          trailing: Chip(label: Text(r.statut), visualDensity: VisualDensity.compact),
        ));
      },
    );
  }
}