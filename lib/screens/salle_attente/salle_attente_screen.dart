import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/salle_attente.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import '../../services/salle_attente_service.dart';
import '../patients/patient_form_screen.dart';
import 'salle_attente_form_screen.dart';

/// Salle d'attente : la réception enregistre les patients à leur arrivée.
/// Ils sont appelés dans l'ordre d'arrivée ; le médecin ouvre ensuite
/// la fiche du patient à partir de la file.
class SalleAttenteScreen extends StatefulWidget {
  const SalleAttenteScreen({super.key});
  @override
  State<SalleAttenteScreen> createState() => _SalleAttenteScreenState();
}

class _SalleAttenteScreenState extends State<SalleAttenteScreen> {
  final _svc = SalleAttenteService();
  List<SalleAttente> _list = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.listForDay(DateTime.now());
    if (mounted) setState(() { _list = r; _loading = false; });
  }

  Future<void> _openPatient(SalleAttente w) async {
    Patient? p;
    if (w.patientId.isNotEmpty) {
      try { p = await PatientService().getById(w.patientId); } catch (_) {}
    }
    p ??= await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _RecherchePatientPage(attente: w)));
    if (p == null || !mounted) return;
    if (w.patientId.isEmpty) await _svc.lierPatient(w.id, p.id);
    await _svc.update(w.id, SalleAttente(
      id: w.id, patientId: p.id, nom: w.nom, prenom: w.prenom,
      dateNaissance: w.dateNaissance, statut: 'appele',
      notes: w.notes, arrivee: w.arrivee, appel: DateTime.now()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final hf = DateFormat('HH:mm', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          const Text('Salle d\u2019attente — ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(DateFormat('dd/MM/yyyy', 'fr_FR').format(DateTime.now()),
            style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Nouvel arrivant'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SalleAttenteFormScreen()));
              _load();
            }),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _list.isEmpty
              ? const Center(child: Text('Aucun patient dans la salle d\u2019attente'))
              : ListView.builder(
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final w = _list[i];
                    final enAttente = w.statut == 'en_attente';
                    return Card(
                      color: enAttente ? null : Colors.grey.shade100,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: enAttente
                              ? Colors.teal.shade100 : Colors.grey.shade300,
                          child: Text('${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                        title: Text(w.fullName,
                          style: enAttente ? null : TextStyle(
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough)),
                        subtitle: Text(
                          '${hf.format(w.arrivee)}'
                          '${w.dateNaissance != null ? " • Né(e) : ${DateFormat('dd/MM/yyyy','fr_FR').format(w.dateNaissance!)}" : ""}'
                          '${w.patientId.isNotEmpty ? " • Fiche liée ✓" : " • Fiche non liée"}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (enAttente)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.campaign),
                              label: const Text('Appeler'),
                              onPressed: () => _openPatient(w))
                          else
                            Chip(label: const Text('Appelé'),
                              visualDensity: VisualDensity.compact),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Retirer',
                            onPressed: () async { await _svc.delete(w.id); _load(); }),
                        ]),
                      ));
                  }),
        ),
      ]),
    );
  }
}

/// Recherche d'un patient existant ou création rapide d'une nouvelle fiche,
/// puis liaison à l'entrée de la salle d'attente.
class _RecherchePatientPage extends StatefulWidget {
  final SalleAttente attente;
  const _RecherchePatientPage({required this.attente});
  @override
  State<_RecherchePatientPage> createState() => _RecherchePatientPageState();
}

class _RecherchePatientPageState extends State<_RecherchePatientPage> {
  final _svc = PatientService();
  final _q = TextEditingController();
  List<Patient> _results = [];

  Future<void> _search() async {
    final r = await _svc.search(_q.text.trim());
    if (mounted) setState(() => _results = r);
  }

  Future<void> _creerNouveau() async {
    final w = widget.attente;
    final p = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PatientFormScreen(
        prefillNom: w.nom, prefillPrenom: w.prenom,
        prefillDateNaissance: w.dateNaissance)));
    if (p is Patient && mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lier une fiche patient')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _q,
            decoration: InputDecoration(
              labelText: 'Nom, prénom ou n° de dossier',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.search),
                onPressed: _search)),
            onSubmitted: (_) => _search()),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Créer une nouvelle fiche pour ce patient'),
            onPressed: _creerNouveau),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: _results.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(p.fullName),
                  subtitle: Text('${p.numeroDossier}'
                    '${p.telephone.isNotEmpty ? " • ${p.telephone}" : ""}'),
                  trailing: const Icon(Icons.check, color: Colors.green),
                  onTap: () => Navigator.pop(context, p),
                ))).toList(),
            ),
          ),
        ])),
    );
  }
}
