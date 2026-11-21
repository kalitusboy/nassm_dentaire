import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/paiement.dart';
import '../../services/acte_service.dart';
import '../../services/paiement_service.dart';

class PaiementFormScreen extends StatefulWidget {
  final String patientId;
  final String? acteId;
  const PaiementFormScreen({super.key, required this.patientId, this.acteId});
  @override
  State<PaiementFormScreen> createState() => _PaiementFormScreenState();
}

class _PaiementFormScreenState extends State<PaiementFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = PaiementService();
  final _acteSvc = ActeService();
  final _montant = TextEditingController();
  String _methode = 'espece';
  final _notes = TextEditingController();
  List<dynamic> _actes = [];
  String? _selected;
  double _reste = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _selected = widget.acteId; _load(); }

  Future<void> _load() async {
    _actes = await _acteSvc.listForPatient(widget.patientId);
    if (_selected != null) {
      final a = _actes.firstWhere((e) => e.id == _selected, orElse: () => null);
      if (a != null) {
        final p = await _acteSvc.totalPaye(a.id);
        _reste = a.montantTotal - p;
        _montant.text = _reste.toStringAsFixed(0);
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate() || _selected == null) return;
    await _svc.create(Paiement(
      id: '', acteId: _selected!, patientId: widget.patientId,
      montant: double.tryParse(_montant.text.trim()) ?? 0,
      date: DateTime.now(), methode: _methode, notes: _notes.text.trim()));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer paiement')),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              value: _selected,
              decoration: const InputDecoration(labelText: 'Acte concerné'),
              items: _actes.map<DropdownMenuItem<String>>((a) =>
                DropdownMenuItem(value: a.id as String,
                  child: Text('${a.typeLibelle} — '
                    '${DateFormat('dd/MM/yyyy').format(a.date)} — ${a.montantTotal} DA'))
              ).toList(),
              onChanged: (v) async {
                setState(() => _selected = v);
                final a = _actes.firstWhere((e) => e.id == v);
                final p = await _acteSvc.totalPaye(v!);
                setState(() {
                  _reste = a.montantTotal - p;
                  _montant.text = _reste.toStringAsFixed(0);
                });
              },
              validator: (v) => v == null ? 'Requis' : null),
            if (_reste > 0) ...[
              const SizedBox(height: 8),
              Text('Reste à payer : ${_reste.toStringAsFixed(0)} DA',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _montant, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant versé (DA)'),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Chiffre requis' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _methode,
              decoration: const InputDecoration(labelText: 'Méthode'),
              items: const [
                DropdownMenuItem(value: 'espece', child: Text('Espèces')),
                DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                DropdownMenuItem(value: 'carte', child: Text('Carte bancaire')),
                DropdownMenuItem(value: 'virement', child: Text('Virement')),
              ],
              onChanged: (v) => setState(() => _methode = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save, icon: const Icon(Icons.check),
              label: const Text('Valider le paiement')),
          ],
        ),
      ),
    );
  }
}