import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/patient.dart';
import '../../models/rendez_vous.dart';
import '../../providers/auth_provider.dart';
import '../../services/patient_service.dart';
import '../../services/rendez_vous_service.dart';
import '../../services/user_service.dart';

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
  List<Map<String, String>> _doctors = [];
  String? _medecinId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _date = widget.existing?.dateHeure ?? widget.initialDate ?? DateTime.now();
    _duree = widget.existing?.dureeMinutes ?? 30;
    _statut = widget.existing?.statut ?? 'planifie';
    _motif.text = widget.existing?.motif ?? '';
    _loadPatients();
  }

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final auth = context.read<AuthProvider>();
      if (widget.existing != null) {
        _patient = await _patientSvc.getById(widget.existing!.patientId);
      }
      // médecins : dentistes + administrateur (pas les réceptionnistes)
      final users = await UserService().list();
      _doctors = [
        for (final u in users)
          if (u.getStringValue('role') != 'reception')
            {
              'id': u.id,
              'nom': 'Dr. ${u.getStringValue('prenom')} ${u.getStringValue('nom')}'.trim(),
            }
      ];
      _medecinId = widget.existing?.medecinId;
      _medecinId ??= _doctors.any((d) => d['id'] == auth.userId)
          ? auth.userId
          : (_doctors.isNotEmpty ? _doctors.first['id'] : auth.userId);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate() || _patient == null) return;
    final auth = context.read<AuthProvider>();
    final r = RendezVous(
      id: widget.existing?.id ?? '', patientId: _patient!.id,
      medecinId: _medecinId ?? auth.userId, dateHeure: _date, dureeMinutes: _duree,
      motif: _motif.text.trim(), statut: _statut);
    // Avertit (sans bloquer) si le médecin a déjà un rendez-vous sur ce créneau
    if (r.statut != 'annule') {
      try {
        final c = await _svc.findConflict(
            medecinId: r.medecinId, start: r.dateHeure,
            minutes: r.dureeMinutes, excludeId: r.id.isEmpty ? null : r.id);
        if (c != null && mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Créneau déjà occupé'),
              content: Text(
                  'Ce médecin a déjà un rendez-vous à '
                  '${DateFormat('HH:mm', 'fr_FR').format(c.dateHeure)} '
                  '(${c.patientNom}). Enregistrer quand même ?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('Changer l\'heure')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('Enregistrer')),
              ],
            ),
          );
          if (ok != true) return;
        }
      } catch (_) {}
    }
    // Avertit si le patient a déjà un rendez-vous ce jour-là
    if (r.statut != 'annule') {
      try {
        final d = await _svc.findPatientSameDay(
            patientId: r.patientId, date: r.dateHeure,
            excludeId: r.id.isEmpty ? null : r.id);
        if (d != null && mounted) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Le patient a déjà un rendez-vous ce jour'),
              content: Text(
                  '${DateFormat('HH:mm', 'fr_FR').format(d.dateHeure)} avec '
                  'Dr. ${d.medecinNom}. Enregistrer quand même ce second rendez-vous ?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Annuler')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Enregistrer')),
              ],
            ),
          );
          if (ok != true) return;
        }
      } catch (_) {}
    }
    try {
      if (r.id.isEmpty) { await _svc.create(r); } else { await _svc.update(r.id, r); }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rendez-vous non enregistré : $e')));
      }
    }
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
            if (!_ready) const LinearProgressIndicator(),
            if (_ready) ...[
              Autocomplete<Patient>(
                initialValue: TextEditingValue(
                    text: _patient == null
                        ? ''
                        : '${_patient!.fullName} — ${_patient!.numeroDossier}'),
                displayStringForOption: (p) =>
                    '${p.fullName} — ${p.numeroDossier}',
                optionsBuilder: (v) async {
                  final q = v.text.trim();
                  if (q.length < 2) return const <Patient>[];
                  return _patientSvc.search(q);
                },
                onSelected: (p) => setState(() => _patient = p),
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) => TextFormField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: InputDecoration(
                    labelText: 'Patient (2 lettres du nom ou n° de dossier)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _patient != null
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                  onChanged: (t) {
                    if (_patient != null &&
                        t != '${_patient!.fullName} — ${_patient!.numeroDossier}') {
                      setState(() => _patient = null);
                    }
                  },
                  validator: (_) =>
                      _patient == null ? 'Choisissez un patient dans la liste' : null,
                ),
              ),
              if (_doctors.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _doctors.any((d) => d['id'] == _medecinId) ? _medecinId : null,
                  decoration: const InputDecoration(labelText: 'Médecin'),
                  items: _doctors
                      .map((d) => DropdownMenuItem(
                          value: d['id'], child: Text(d['nom']!)))
                      .toList(),
                  onChanged: (v) => setState(() => _medecinId = v),
                ),
              ],
            ],
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