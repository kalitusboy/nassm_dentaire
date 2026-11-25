import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/file_attente.dart';
import '../../models/patient.dart';
import '../../providers/auth_provider.dart';
import '../../services/caisse_service.dart';
import '../../services/file_attente_service.dart';
import '../../services/patient_service.dart';
import '../../services/user_service.dart';
import '../../utils/fmt.dart';
import '../patients/patient_detail_screen.dart';

/// Salle d'attente : la réception enregistre les patients à leur arrivée,
/// le dentiste les appelle dans l'ordre, puis la réception encaisse.
class FileAttenteScreen extends StatefulWidget {
  const FileAttenteScreen({super.key});
  @override
  State<FileAttenteScreen> createState() => _FileAttenteScreenState();
}

class _FileAttenteScreenState extends State<FileAttenteScreen> {
  final _svc = FileAttenteService();
  List<FileAttente> _list = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final l = await _svc.listToday();
      if (mounted) setState(() { _list = l; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; if (!silent) _error = '$e'; });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
      await _load(silent: true);
    } catch (e) {
      _snack(UserService.errorMessage(e));
    }
  }

  // ───────── Actions ─────────
  Future<String?> _pickDoctor() async {
    final users = await UserService().list();
    final docs = users.where((u) => u.getStringValue('role') != 'reception').toList();
    if (docs.isEmpty) return null;
    if (docs.length == 1) return docs.first.id;
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Quel médecin ?'),
        children: [
          for (final d in docs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, d.id),
              child: Text('Dr. ${d.getStringValue('prenom')} ${d.getStringValue('nom')}'.trim()),
            ),
        ],
      ),
    );
  }

  Future<void> _faireEntrer(FileAttente f, AuthProvider auth) async {
    String? med;
    if (auth.isDentiste || auth.isAdmin) {
      med = auth.userId;
    } else {
      med = await _pickDoctor();
      if (med == null) return;
    }
    await _run(() => _svc.setStatut(f.id, 'en_consultation', medecinId: med));
  }

  Future<void> _ouvrirDossier(FileAttente f) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: f.patientId)));
    _load(silent: true);
  }

  Future<void> _annuler(FileAttente f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Retirer de la salle d\'attente ?'),
        content: Text(f.patientNom),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
        ],
      ),
    );
    if (ok == true) await _run(() => _svc.setStatut(f.id, 'annule'));
  }

  Future<void> _encaisser(FileAttente f) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _EncaissementDialog(entry: f),
    );
    if (done == true) {
      await _run(() => _svc.setStatut(f.id, 'termine'));
    }
  }

  Future<void> _enregistrer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _RegisterDialog(),
    );
    if (ok == true) _load(silent: true);
  }

  // ───────── UI ─────────
  Color _color(String s) => switch (s) {
        'attente' => Colors.orange,
        'en_consultation' => Colors.blue,
        'a_encaisser' => Colors.green.shade700,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canRegister = auth.isReception || auth.isAdmin;
    final active = _list
        .where((f) => f.statut == 'attente' || f.statut == 'en_consultation' || f.statut == 'a_encaisser')
        .toList();
    final done = _list.where((f) => f.statut == 'termine').toList();
    final nAttente = _list.where((f) => f.statut == 'attente').length;
    final nConsult = _list.where((f) => f.statut == 'en_consultation').length;
    final nEnc = _list.where((f) => f.statut == 'a_encaisser').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salle d\'attente'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, tooltip: 'Actualiser', icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: canRegister
          ? FloatingActionButton.extended(
              onPressed: _enregistrer,
              icon: const Icon(Icons.how_to_reg),
              label: const Text('Enregistrer un patient'))
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      Chip(avatar: const Icon(Icons.hourglass_top, size: 16, color: Colors.orange),
                          label: Text('En attente : $nAttente')),
                      Chip(avatar: const Icon(Icons.medical_services, size: 16, color: Colors.blue),
                          label: Text('En consultation : $nConsult')),
                      Chip(avatar: Icon(Icons.payments, size: 16, color: Colors.green.shade700),
                          label: Text('À encaisser : $nEnc')),
                    ]),
                    const SizedBox(height: 12),
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Aucun patient en salle d\'attente')),
                      ),
                    for (final f in active) _entryCard(f, auth),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Terminés aujourd\'hui (${done.length})',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      for (final f in done)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.check_circle, color: Colors.grey),
                          title: Text(f.patientNom),
                          subtitle: Text('Arrivé à ${fmtTime(f.heureArrivee)}'
                              '${f.medecinNom.isEmpty ? '' : ' • Dr. ${f.medecinNom}'}'),
                        ),
                    ],
                  ],
                ),
    );
  }

  Widget _entryCard(FileAttente f, AuthProvider auth) {
    final ticket = _list.indexOf(f) + 1;
    final isDoc = auth.isDentiste || auth.isAdmin;
    final isRec = auth.isReception || auth.isAdmin;
    final waiting = DateTime.now().difference(f.heureArrivee);

    final actions = <Widget>[];
    if (f.statut == 'attente') {
      actions.add(ElevatedButton.icon(
        onPressed: () => _faireEntrer(f, auth),
        icon: const Icon(Icons.login),
        label: Text(isDoc ? 'Appeler' : 'Faire entrer'),
      ));
    }
    if (f.statut == 'en_consultation') {
      actions.add(OutlinedButton.icon(
        onPressed: () => _ouvrirDossier(f),
        icon: const Icon(Icons.folder_open),
        label: const Text('Dossier'),
      ));
      if (isDoc) {
        actions.add(ElevatedButton.icon(
          onPressed: () => _run(() => _svc.setStatut(f.id, 'a_encaisser')),
          icon: const Icon(Icons.done_all),
          label: const Text('Terminer → encaissement'),
        ));
        actions.add(OutlinedButton.icon(
          onPressed: f.appelReception
              ? null
              : () async {
                  await _run(() => _svc.appelReception(f.id, true));
                  _snack('La réception a été prévenue.');
                },
          icon: const Icon(Icons.notifications_active),
          label: Text(f.appelReception ? 'Réception appelée' : 'Appeler la réception'),
        ));
      }
    }
    if (f.statut == 'a_encaisser' && isRec) {
      actions.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
        onPressed: () => _encaisser(f),
        icon: const Icon(Icons.payments),
        label: const Text('Encaisser'),
      ));
    }
    if (f.statut == 'a_encaisser' && !isRec) {
      actions.add(OutlinedButton.icon(
        onPressed: () => _ouvrirDossier(f),
        icon: const Icon(Icons.folder_open),
        label: const Text('Dossier'),
      ));
    }

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: f.appelReception ? Colors.orange : Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: _color(f.statut),
              foregroundColor: Colors.white,
              child: Text('$ticket'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${f.patientNom}${f.age != null ? '  (${f.age} ans)' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Arrivé à ${fmtTime(f.heureArrivee)}'
                  '${f.statut == 'attente' ? ' • attend depuis ${fmtWaiting(waiting)}' : ''}'
                  '${f.motif.isEmpty ? '' : ' • ${f.motif}'}'
                  '${f.medecinNom.isEmpty ? '' : ' • Dr. ${f.medecinNom}'}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ]),
            ),
            Chip(
              label: Text(f.statutLibelle, style: const TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: _color(f.statut),
              visualDensity: VisualDensity.compact,
            ),
            if (f.statut == 'attente' || f.statut == 'en_consultation')
              IconButton(
                tooltip: 'Retirer de la file',
                icon: const Icon(Icons.close),
                onPressed: () => _annuler(f),
              ),
          ]),
          if (f.appelReception) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.notifications_active, color: Colors.orange, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Le médecin demande la réception au cabinet.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
              if (isRec)
                TextButton(
                  onPressed: () => _run(() => _svc.appelReception(f.id, false)),
                  child: const Text('J\'y vais'),
                ),
            ]),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ]),
      ),
    );
  }
}

// ═════════════ Enregistrement d'un patient à l'arrivée ═════════════
class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog();
  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  final _key = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _tel = TextEditingController();
  final _motif = TextEditingController();
  DateTime? _dob;
  bool _busy = false;
  String? _error;
  final _patients = PatientService();

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _tel.dispose();
    _motif.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<Patient?> _chooseExisting(List<Patient> found) {
    return showDialog<Patient?>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Ce patient existe-t-il déjà ?'),
        children: [
          for (final p in found)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, p),
              child: Text(
                '${p.fullName} — dossier ${p.numeroDossier}'
                '${p.dateNaissance != null ? ' — né(e) le ${fmtDate(p.dateNaissance!)}' : ''}',
              ),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, null),
            child: const Text('Non, c\'est un nouveau patient',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final nom = _nom.text.trim();
      final prenom = _prenom.text.trim();
      Patient? patient;
      final found = await _patients.findSimilar(nom, prenom);
      if (found.isNotEmpty && mounted) {
        patient = await _chooseExisting(found);
      }
      patient ??= await _patients.create(Patient(
        id: '',
        numeroDossier: await _patients.nextNumero(),
        nom: nom,
        prenom: prenom,
        dateNaissance: _dob,
        telephone: _tel.text.trim(),
      ));
      final svc = FileAttenteService();
      final today = await svc.listToday();
      final already = today.any((f) =>
          f.patientId == patient!.id && (f.statut == 'attente' || f.statut == 'en_consultation'));
      if (already) {
        setState(() { _busy = false; _error = 'Ce patient est déjà en salle d\'attente.'; });
        return;
      }
      await svc.register(patientId: patient.id, motif: _motif.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _busy = false; _error = UserService.errorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Patient arrivé'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _nom,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prenom,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Date de naissance', prefixIcon: Icon(Icons.cake)),
                  child: Text(_dob == null ? 'Non renseignée' : fmtDate(_dob!)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motif,
                decoration: const InputDecoration(
                    labelText: 'Motif de la visite (facultatif)',
                    prefixIcon: Icon(Icons.notes)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Mettre en salle d\'attente'),
        ),
      ],
    );
  }
}

// ═════════════ Encaissement à la sortie du cabinet ═════════════
class _EncaissementDialog extends StatefulWidget {
  final FileAttente entry;
  const _EncaissementDialog({required this.entry});
  @override
  State<_EncaissementDialog> createState() => _EncaissementDialogState();
}

class _EncaissementDialogState extends State<_EncaissementDialog> {
  final _caisse = CaisseService();
  final _montant = TextEditingController();
  List<ActeDu> _dus = [];
  String _methode = 'espece';
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await _caisse.actesDus(widget.entry.patientId);
      if (mounted) setState(() { _dus = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  double get _total => _dus.fold<double>(0, (s, d) => s + d.reste);
  double? get _saisi => double.tryParse(_montant.text.trim().replaceAll(',', '.'));

  Future<void> _valider() async {
    final m = _saisi;
    if (m == null || m <= 0) {
      setState(() => _error = 'Saisissez le montant encaissé.');
      return;
    }
    if (m > _total + 0.01) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Montant supérieur au dû'),
          content: Text('Le total dû est de ${fmtMoney(_total)}. '
              'Enregistrer ${fmtMoney(m)} quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Corriger')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await _caisse.encaisser(
          patientId: widget.entry.patientId, montant: m, methode: _methode, dus: _dus);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _busy = false; _error = UserService.errorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saisi = _saisi;
    final apres = saisi == null ? null : (_total - saisi).clamp(0, double.infinity).toDouble();
    return AlertDialog(
      title: Text('Encaissement — ${widget.entry.patientNom}'),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_dus.isEmpty)
                    const Text('Aucun montant dû pour ce patient. Le dentiste n\'a peut-être '
                        'pas encore fixé le prix des actes.')
                  else ...[
                    for (final d in _dus)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${d.acte.typeLibelle}'
                            '${d.acte.dent != null ? ' — dent ${d.acte.dent}' : ''}'),
                        subtitle: Text('${fmtDate(d.acte.date)} • déjà payé ${fmtMoney(d.paye)}'),
                        trailing: Text(fmtMoney(d.reste),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    const Divider(),
                    Row(children: [
                      const Text('Total à encaisser', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(fmtMoney(_total),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _montant,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Montant encaissé (DA)',
                        helperText: 'Le patient peut payer une partie seulement.',
                      ),
                    ),
                    if (apres != null) ...[
                      const SizedBox(height: 8),
                      Text('Reste après encaissement : ${fmtMoney(apres)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: apres > 0 ? Colors.orange.shade800 : Colors.green.shade700)),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _methode,
                      decoration: const InputDecoration(labelText: 'Mode de paiement'),
                      items: const [
                        DropdownMenuItem(value: 'espece', child: Text('Espèces')),
                        DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                        DropdownMenuItem(value: 'carte', child: Text('Carte')),
                        DropdownMenuItem(value: 'virement', child: Text('Virement')),
                      ],
                      onChanged: (v) => setState(() => _methode = v ?? 'espece'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ]),
              ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        OutlinedButton(
          onPressed: _busy ? null : () => Navigator.pop(context, true),
          child: const Text('Terminer sans encaisser'),
        ),
        if (_dus.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _busy ? null : _valider,
            icon: const Icon(Icons.check),
            label: const Text('Encaisser et terminer'),
          ),
      ],
    );
  }
}
