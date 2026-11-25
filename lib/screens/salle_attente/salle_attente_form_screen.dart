import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/salle_attente.dart';
import '../../services/salle_attente_service.dart';

class SalleAttenteFormScreen extends StatefulWidget {
  const SalleAttenteFormScreen({super.key});
  @override
  State<SalleAttenteFormScreen> createState() => _SalleAttenteFormScreenState();
}

class _SalleAttenteFormScreenState extends State<SalleAttenteFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = SalleAttenteService();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _dn;
  bool _saving = false;

  @override
  void dispose() { _nom.dispose(); _prenom.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.create(SalleAttente(
        id: '', nom: _nom.text.trim(), prenom: _prenom.text.trim(),
        dateNaissance: _dn, notes: _notes.text.trim(),
        arrivee: DateTime.now()));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel arrivant')),
      body: Form(
        key: _f,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          TextFormField(controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom'),
            validator: (v) => v!.isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _prenom,
            decoration: const InputDecoration(labelText: 'Prénom'),
            validator: (v) => v!.isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero,
            title: Text(_dn != null
              ? 'Naissance : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(_dn!)}'
              : 'Date de naissance (optionnel)'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(context: context,
                initialDate: _dn ?? DateTime(1990),
                firstDate: DateTime(1900), lastDate: DateTime.now());
              if (d != null) setState(() => _dn = d);
            }),
          const SizedBox(height: 12),
          TextFormField(controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
            maxLines: 2),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Ajouter à la file')),
        ])));
  }
}
