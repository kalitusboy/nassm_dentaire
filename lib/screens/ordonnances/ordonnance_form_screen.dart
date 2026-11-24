import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ordonnance.dart';
import '../../providers/auth_provider.dart';
import '../../services/ordonnance_service.dart';
import '../../services/parametre_service.dart';
import '../../services/patient_service.dart';
import '../../services/pdf_service.dart';

class OrdonnanceFormScreen extends StatefulWidget {
  final String patientId;
  const OrdonnanceFormScreen({super.key, required this.patientId});
  @override
  State<OrdonnanceFormScreen> createState() => _OrdonnanceFormScreenState();
}

class _OrdonnanceFormScreenState extends State<OrdonnanceFormScreen> {
  final _svc = OrdonnanceService();
  final List<Medicament> _meds = [];
  final _instr = TextEditingController();
  final _nom = TextEditingController();
  final _pos = TextEditingController();
  final _duree = TextEditingController();

  static const suggestions = [
    {'nom': 'Amoxicilline 500mg', 'posologie': '1 gélule x 3/jour', 'duree': '7 jours'},
    {'nom': 'Amoxicilline + Ac. clavulanique 1g', 'posologie': '1 cp x 2/jour', 'duree': '7 jours'},
    {'nom': 'Paracétamol 500mg', 'posologie': '1 cp x 3/jour', 'duree': '5 jours'},
    {'nom': 'Ibuprofène 400mg', 'posologie': '1 cp x 3/jour (après repas)', 'duree': '3 jours'},
    {'nom': 'Métronidazole 500mg', 'posologie': '1 cp x 3/jour', 'duree': '5 jours'},
    {'nom': 'Chlorhexidine 0.12% bain de bouche', 'posologie': 'Rincer 2x/jour', 'duree': '7 jours'},
  ];

  void _add() {
    if (_nom.text.isEmpty) return;
    setState(() {
      _meds.add(Medicament(
        nom: _nom.text.trim(), posologie: _pos.text.trim(), duree: _duree.text.trim()));
      _nom.clear(); _pos.clear(); _duree.clear();
    });
  }

  Future<void> _save() async {
    if (_meds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un médicament')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ord = Ordonnance(
      id: '', patientId: widget.patientId, medecinId: auth.userId,
      date: DateTime.now(), medicaments: _meds, instructions: _instr.text.trim());
    // 1) enregistrement : si cela échoue, on reste sur l'écran
    try {
      await _svc.create(ord);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ordonnance non enregistrée : $e')));
      }
      return;
    }
    // 2) impression : l'ordonnance est déjà enregistrée, une erreur ici
    //    ne doit ni bloquer l'écran ni provoquer un doublon
    try {
      final patient = await PatientService().getById(widget.patientId);
      final params = await ParametreService().get();
      if (!mounted) return;
      await PdfService().imprimerOrdonnance(
        parametre: params, patient: patient!, ordonnance: ord);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ordonnance enregistrée, mais l\'impression a échoué : $e')));
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _instr.dispose();
    _nom.dispose();
    _pos.dispose();
    _duree.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle ordonnance')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Médicaments prescrits',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ..._meds.asMap().entries.map((e) => Card(
            child: ListTile(
              title: Text(e.value.nom),
              subtitle: Text('${e.value.posologie} — ${e.value.duree}'),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _meds.removeAt(e.key))),
            ))),
          const SizedBox(height: 12),
          const Text('Ajouter un médicament :',
            style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, children: suggestions.map((s) => ActionChip(
            label: Text(s['nom']!, style: const TextStyle(fontSize: 11)),
            onPressed: () {
              setState(() {
                _meds.add(Medicament(
                  nom: s['nom']!, posologie: s['posologie']!, duree: s['duree']!));
              });
            })).toList()),
          const SizedBox(height: 12),
          TextField(controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom du médicament')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _pos,
              decoration: const InputDecoration(labelText: 'Posologie'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _duree,
              decoration: const InputDecoration(labelText: 'Durée'))),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add),
            label: const Text('Ajouter à la liste')),
          const SizedBox(height: 16),
          TextField(controller: _instr,
            decoration: const InputDecoration(labelText: 'Instructions supplémentaires'),
            maxLines: 2),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.print),
            label: const Text('Enregistrer et imprimer')),
        ],
      ),
    );
  }
}