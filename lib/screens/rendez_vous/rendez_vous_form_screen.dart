import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../providers/auth_provider.dart';
import '../../services/patient_service.dart';
import '../../services/rendez_vous_service.dart';

class RendezVousFormScreen extends StatefulWidget {
  final RendezVous? existing;
  final DateTime? initialDate;
  const RendezVousFormScreen({super.key, this.existing, this.initialDate});
  @override
  State<RendezVousFormScreen> createState() => _RendezVousFormScreenState();
}

class _RendezVousFormScreenState extends State<RendezVousFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = RendezVousService();
  final _patientSvc = PatientService();
  final _motif = TextEditingController();
  Patient? _patient;
  DateTime _date = DateTime.now();
  int _duree = 30;
  String _statut = 'planifie';
  List<Patient> _patients = [];

  @override
  void initState() {
    super.initState();
    _date = widget.existing?.dateHeure ?? widget.initialDate ?? DateTime.now();
    _duree = widget.existing?.dureeMinutes ?? 30;
    _statut = widget.existing?.statut ?? 'planifie';
    _motif.text = widget.existing?.motif ?? '';
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    _patients = await _patientSvc.search('');
    if (widget.existing != null) {
      _patient = _patients.firstWhere((p) => p.id == widget.existing!.patientId,
        orElse: () => _patients.first);
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate() || _patient == null) return;
    final auth = context.read<AuthProvider>();
    final r = RendezVous(
      id: widget.existing?.id ?? '', patientId: _patient!.id,
      medecinId: auth.userId, dateHeure: _date, dureeMinutes: _duree,
      motif: _motif.text.trim(), statut: _statut);
    if (r.id.isEmpty) { await _svc.create(r); } else { await _svc.update(r.id, r); }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null
        ? 'Nouveau rendez-vous' : 'Modifier rendez-vous')),
      body: Form(
        key: _f,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<Patient>(
              value: _patient,
              decoration: const InputDecoration(labelText: 'Patient'),
              items: _patients.map((p) => DropdownMenuItem(
                value: p, child: Text('${p.fullName} — ${p.numeroDossier}'))).toList(),
              onChanged: (p) => setState(() => _patient = p),
              validator: (v) => v == null ? 'Requis' : null),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date & heure : '
                '${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(_date)}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d == null || !mounted) return;
                final t = await showTimePicker(context: context,
                  initialTime: TimeOfDay.fromDateTime(_date));
                if (t != null) {
                  setState(() => _date = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                }
              }),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _duree,
              decoration: const InputDecoration(labelText: 'Durée (minutes)'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 min')),
                DropdownMenuItem(value: 30, child: Text('30 min')),
                DropdownMenuItem(value: 45, child: Text('45 min')),
                DropdownMenuItem(value: 60, child: Text('1 heure')),
                DropdownMenuItem(value: 90, child: Text('1h30')),
              ],
              onChanged: (v) => setState(() => _duree = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _motif,
              decoration: const InputDecoration(labelText: 'Motif')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statut,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'planifie', child: Text('Planifié')),
                DropdownMenuItem(value: 'confirme', child: Text('Confirmé')),
                DropdownMenuItem(value: 'termine', child: Text('Terminé')),
                DropdownMenuItem(value: 'annule', child: Text('Annulé')),
              ],
              onChanged: (v) => setState(() => _statut = v!)),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save),
              label: const Text('Enregistrer')),
          ],
        ),
      ),
    );
  }
}