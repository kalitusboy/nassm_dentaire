import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/acte.dart';
import '../../providers/auth_provider.dart';
import '../../services/acte_service.dart';
import '../../services/encaissement_service.dart';

class ActeFormScreen extends StatefulWidget {
  final String patientId;
  final Acte? existing;
  const ActeFormScreen({super.key, required this.patientId, this.existing});
  @override
  State<ActeFormScreen> createState() => _ActeFormScreenState();
}

class _ActeFormScreenState extends State<ActeFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = ActeService();
  String _type = 'examen';
  final _dent = TextEditingController();
  final _desc = TextEditingController();
  final _montant = TextEditingController();
  DateTime _date = DateTime.now();
  String _statut = 'planifie';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _type = e.type;
      _dent.text = e.dent?.toString() ?? '';
      _desc.text = e.description;
      _montant.text = e.montantTotal == 0 ? '' : e.montantTotal.toStringAsFixed(0);
      _date = e.date;
      _statut = e.statut;
    }
  }

  @override
  void dispose() {
    _dent.dispose();
    _desc.dispose();
    _montant.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    try {
      final a = Acte(
        id: widget.existing?.id ?? '', patientId: widget.patientId,
        medecinId: widget.existing?.medecinId ?? auth.userId,
        type: _type, dent: int.tryParse(_dent.text.trim()),
        date: _date, description: _desc.text.trim(),
        montantTotal: double.tryParse(_montant.text.trim().replaceAll(',', '.')) ?? 0,
        statut: _statut);
      Acte saved;
      if (widget.existing == null) {
        saved = await _svc.create(a);
      } else {
        saved = await _svc.update(a.id, a);
      }
      // Acte terminé avec un montant fixé → notification d'encaissement
      // pour la réception (le patient passera à l'accueil en sortant).
      if (saved.statut == 'termine' && saved.montantTotal > 0) {
        try {
          await EncaissementService().create(
            patientId: saved.patientId, acteId: saved.id,
            medecinId: saved.medecinId, montant: saved.montantTotal);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Acte non enregistré : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'Nouvel acte' : 'Modifier l\'acte')),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type d\'acte'),
              items: Acte.typesLibelles.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
              onChanged: (v) => setState(() => _type = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _dent, keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Numéro de dent (FDI, optionnel)')),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(_date)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _date = d);
              }),
            TextFormField(controller: _desc,
              decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _montant, keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Montant de l\'acte (DA)',
                helperText: 'Fixé par le dentiste. Peut être laissé vide et complété plus tard.'),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                final n = double.tryParse(t.replaceAll(',', '.'));
                if (n == null) return 'Chiffre requis';
                if (n < 0) return 'Montant invalide';
                return null;
              }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'planifie', child: Text('Planifié')),
                DropdownMenuItem(value: 'en_cours', child: Text('En cours')),
                DropdownMenuItem(value: 'termine', child: Text('Terminé')),
                DropdownMenuItem(value: 'annule', child: Text('Annulé')),
              ],
              onChanged: (v) => setState(() => _statut = v!)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}