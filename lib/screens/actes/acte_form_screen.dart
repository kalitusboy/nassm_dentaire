import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/acte.dart';
import '../../providers/auth_provider.dart';
import '../../services/acte_service.dart';

class ActeFormScreen extends StatefulWidget {
  final String patientId;
  const ActeFormScreen({super.key, required this.patientId});
  @override
  State<ActeFormScreen> createState() => _ActeFormScreenState();
}

class _ActeFormScreenState extends State<ActeFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = ActeService();
  String _type = 'examen';
  final _dent = TextEditingController();
  final _desc = TextEditingController();
  final _montant = TextEditingController(text: '0');
  DateTime _date = DateTime.now();
  String _statut = 'planifie';
  bool _saving = false;

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _saving = true);
    await _svc.create(Acte(
      id: '', patientId: widget.patientId, medecinId: auth.userId,
      type: _type, dent: int.tryParse(_dent.text.trim()),
      date: _date, description: _desc.text.trim(),
      montantTotal: double.tryParse(_montant.text.trim()) ?? 0,
      statut: _statut));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel acte')),
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
              decoration: const InputDecoration(labelText: 'Montant total (DA)'),
              validator: (v) => double.tryParse(v ?? '') == null ? 'Chiffre requis' : null),
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