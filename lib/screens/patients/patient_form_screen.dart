import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';

class PatientFormScreen extends StatefulWidget {
  final Patient? patient;
  final String? prefillNom, prefillPrenom;
  final DateTime? prefillDateNaissance;
  const PatientFormScreen({super.key, this.patient,
    this.prefillNom, this.prefillPrenom, this.prefillDateNaissance});
  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = PatientService();
  final _numero = TextEditingController();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _tel = TextEditingController();
  final _adresse = TextEditingController();
  final _allergies = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _dn;
  bool _saving = false;

  @override
  void dispose() {
    _numero.dispose();
    _nom.dispose();
    _prenom.dispose();
    _tel.dispose();
    _adresse.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      final p = widget.patient!;
      _numero.text = p.numeroDossier;
      _nom.text = p.nom; _prenom.text = p.prenom;
      _tel.text = p.telephone; _adresse.text = p.adresse;
      _allergies.text = p.allergies; _notes.text = p.notesMedicales;
      _dn = p.dateNaissance;
    } else {
      if ((widget.prefillNom ?? '').isNotEmpty ||
          (widget.prefillPrenom ?? '').isNotEmpty) {
        _nom.text = widget.prefillNom ?? '';
        _prenom.text = widget.prefillPrenom ?? '';
        _dn = widget.prefillDateNaissance;
      } else {
        _svc.nextNumero().then((n) {
          if (mounted && _numero.text.isEmpty) _numero.text = n;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    setState(() => _saving = true);
    final p = Patient(
      id: widget.patient?.id ?? '',
      numeroDossier: _numero.text.trim(),
      nom: _nom.text.trim(), prenom: _prenom.text.trim(),
      dateNaissance: _dn,
      telephone: _tel.text.trim(), adresse: _adresse.text.trim(),
      allergies: _allergies.text.trim(), notesMedicales: _notes.text.trim(),
    );
    if (p.id.isEmpty) { await _svc.create(p); }
    else { await _svc.update(p.id, p); }
    if (mounted) Navigator.pop(context, widget.patient == null ? p : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient == null
        ? 'Nouveau patient' : 'Modifier patient')),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(controller: _numero,
              decoration: const InputDecoration(labelText: 'N° dossier'),
              readOnly: widget.patient != null,
              validator: (v) => v!.isEmpty ? 'Requis' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _nom,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (v) => v!.isEmpty ? 'Requis' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _prenom,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: (v) => v!.isEmpty ? 'Requis' : null)),
            ]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_dn != null
                ? 'Naissance : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(_dn!)}'
                : 'Date de naissance (optionnel)'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dn ?? DateTime(1990),
                  firstDate: DateTime(1900), lastDate: DateTime.now());
                if (d != null) setState(() => _dn = d);
              }),
            const SizedBox(height: 12),
            TextFormField(controller: _tel,
              decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 12),
            TextFormField(controller: _adresse,
              decoration: const InputDecoration(labelText: 'Adresse'), maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _allergies,
              decoration: const InputDecoration(labelText: 'Allergies connues')),
            const SizedBox(height: 12),
            TextFormField(controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes médicales'),
              maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
          ],
        ),
      ),
    );
  }
}