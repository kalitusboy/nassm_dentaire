import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/acte.dart';
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
  List<Acte> _actes = [];
  String? _selected;
  double _reste = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _selected = widget.acteId; _load(); }

  Future<void> _load() async {
    _actes = await _acteSvc.listForPatient(widget.patientId);
    if (_selected != null) {
      final a = _findActe(_selected);
      if (a != null) {
        final p = await _acteSvc.totalPaye(a.id);
        _reste = a.montantTotal - p;
      }
    }
    setState(() => _loading = false);
  }

  Acte? _findActe(String? id) {
    if (id == null) return null;
    for (final a in _actes) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void dispose() {
    _montant.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _busy = false;

  Future<void> _save() async {
    if (_busy) return;
    if (!_f.currentState!.validate() || _selected == null) return;
    final montant =
        double.tryParse(_montant.text.trim().replaceAll(',', '.')) ?? 0;
    // Le paiement est libre (acompte, paiement partiel…). On prévient seulement
    // si le montant dépasse ce qui reste dû.
    if (montant > _reste + 0.01) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Montant supérieur au reste à payer'),
          content: Text(_reste > 0
              ? 'Le reste à payer est de ${_reste.toStringAsFixed(0)} DA. '
                  'Enregistrer ${montant.toStringAsFixed(0)} DA quand même ?'
              : 'Aucun montant restant n\'est dû pour cet acte (le dentiste n\'a '
                  'peut-être pas encore fixé son prix). Enregistrer '
                  '${montant.toStringAsFixed(0)} DA quand même ?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Corriger')),
            ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Enregistrer')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      await _svc.create(Paiement(
        id: '', acteId: _selected!, patientId: widget.patientId,
        montant: montant,
        date: DateTime.now(), methode: _methode, notes: _notes.text.trim()));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paiement non enregistré : $e')));
      }
    }
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
                final a = _findActe(v);
                if (a == null || v == null) return;
                final p = await _acteSvc.totalPaye(v);
                if (!mounted) return;
                setState(() {
                  _reste = a.montantTotal - p;
                  _montant.clear();
                });
              },
              validator: (v) => v == null ? 'Requis' : null),
            if (_reste > 0) ...[
              const SizedBox(height: 8),
              Text('Reste à payer : ${_reste.toStringAsFixed(0)} DA',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ],
            if (_selected != null &&
                double.tryParse(_montant.text.trim().replaceAll(',', '.')) != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reste après ce paiement : '
                '${(_reste - double.parse(_montant.text.trim().replaceAll(',', '.'))).clamp(0, double.infinity).toStringAsFixed(0)} DA',
                style: TextStyle(
                    color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _montant, keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Montant encaissé aujourd\'hui (DA)',
                helperText: 'Le patient peut ne payer qu\'une partie : le reste est calculé automatiquement.'),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (n == null) return 'Chiffre requis';
                if (n <= 0) return 'Le montant doit être positif';
                return null;
              }),
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