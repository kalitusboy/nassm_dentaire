import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rendez_vous.dart';
import '../../services/parametre_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rendez_vous_service.dart';
import '../../services/user_service.dart';
import 'rendez_vous_form_screen.dart';

enum _Vue { jour, semaine, mois, tous }

class RendezVousListScreen extends StatefulWidget {
  const RendezVousListScreen({super.key});
  @override
  State<RendezVousListScreen> createState() => _RendezVousListScreenState();
}

class _RendezVousListScreenState extends State<RendezVousListScreen> {
  final _svc = RendezVousService();
  _Vue _vue = _Vue.jour;
  DateTime _ref = DateTime.now();
  List<RendezVous> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  DateTime get _debut {
    switch (_vue) {
      case _Vue.jour:
        return DateTime(_ref.year, _ref.month, _ref.day);
      case _Vue.semaine:
        final d = DateTime(_ref.year, _ref.month, _ref.day);
        return d.subtract(Duration(days: d.weekday - 1));
      case _Vue.mois:
        return DateTime(_ref.year, _ref.month, 1);
      case _Vue.tous:
        return DateTime(2000);
    }
  }

  DateTime get _fin {
    switch (_vue) {
      case _Vue.jour:
        return DateTime(_ref.year, _ref.month, _ref.day + 1);
      case _Vue.semaine:
        return _debut.add(const Duration(days: 7));
      case _Vue.mois:
        return DateTime(_ref.year, _ref.month + 1, 1);
      case _Vue.tous:
        return DateTime(2100);
    }
  }

  String get _titre {
    final df = DateFormat('dd/MM/yyyy', 'fr_FR');
    switch (_vue) {
      case _Vue.jour:
        return DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_ref);
      case _Vue.semaine:
        return 'Semaine du ${df.format(_debut)} au ${df.format(_fin.subtract(const Duration(days: 1)))}';
      case _Vue.mois:
        return DateFormat.yMMMM('fr_FR').format(_ref);
      case _Vue.tous:
        return 'Tous les rendez-vous';
    }
  }

  void _shift(int dir) {
    setState(() {
      switch (_vue) {
        case _Vue.jour:
          _ref = DateTime(_ref.year, _ref.month, _ref.day + dir);
        case _Vue.semaine:
          _ref = DateTime(_ref.year, _ref.month, _ref.day + 7 * dir);
        case _Vue.mois:
          _ref = DateTime(_ref.year, _ref.month + dir, 1);
        case _Vue.tous:
          break;
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = _vue == _Vue.tous
          ? await _svc.listAll()
          : await _svc.listForRange(_debut, _fin);
      if (mounted) setState(() { _list = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  /// Médecin absent : confie ses rendez-vous (de la liste affichée) à un autre médecin.
  Future<void> _transfer() async {
    final users = await UserService().list();
    final docs = users.where((u) => u.getStringValue('role') != 'reception').toList();
    if (docs.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Il faut au moins deux médecins pour transférer des rendez-vous.')));
      }
      return;
    }
    String name(dynamic u) =>
        'Dr. ${u.getStringValue('prenom')} ${u.getStringValue('nom')}'.trim();
    String from = docs.first.id, to = docs[1].id;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) {
        final ids = _list
            .where((r) => r.medecinId == from &&
                (r.statut == 'planifie' || r.statut == 'confirme'))
            .length;
        return AlertDialog(
          title: const Text('Médecin absent : transférer les rendez-vous'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Période affichée : $_titre',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: from,
                decoration: const InputDecoration(labelText: 'Médecin absent'),
                items: [for (final d in docs) DropdownMenuItem(value: d.id, child: Text(name(d)))],
                onChanged: (v) => setD(() => from = v ?? from),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: to,
                decoration: const InputDecoration(labelText: 'Remplaçant'),
                items: [for (final d in docs) DropdownMenuItem(value: d.id, child: Text(name(d)))],
                onChanged: (v) => setD(() => to = v ?? to),
              ),
              const SizedBox(height: 12),
              Text(from == to
                  ? 'Choisissez deux médecins différents.'
                  : '$ids rendez-vous à venir seront transférés.',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: (from == to || ids == 0) ? null : () => Navigator.pop(c, true),
              child: const Text('Transférer'),
            ),
          ],
        );
      }),
    );
    if (ok != true) return;
    final ids = _list
        .where((r) => r.medecinId == from && (r.statut == 'planifie' || r.statut == 'confirme'))
        .map((r) => r.id)
        .toList();
    try {
      final n = await _svc.reassign(ids, to);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$n rendez-vous transféré(s).')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Widget _card(RendezVous r, {required bool avecDate}) {
    return Card(child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.teal.shade100,
        child: Text(DateFormat('HH:mm').format(r.dateHeure),
          style: const TextStyle(fontSize: 11))),
      title: Text(r.patientNom),
      subtitle: Text('${avecDate ? '${DateFormat('dd/MM/yyyy').format(r.dateHeure)} • ' : ''}'
          '${r.motif.isEmpty ? '' : '${r.motif} • '}Dr. ${r.medecinNom}'),
      trailing: Chip(label: Text(r.statut), visualDensity: VisualDensity.compact),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => RendezVousFormScreen(existing: r)));
        _load();
      },
    ));
  }

  List<Widget> _body() {
    if (_vue == _Vue.jour) {
      return [for (final r in _list) _card(r, avecDate: false)];
    }
    // regroupés par jour
    final out = <Widget>[];
    String? last;
    final f = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    for (final r in _list) {
      final k = f.format(r.dateHeure);
      if (k != last) {
        last = k;
        final n = _list.where((x) => f.format(x.dateHeure) == k).length;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text('$k  ($n)',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
        ));
      }
      out.add(_card(r, avecDate: false));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SegmentedButton<_Vue>(
            segments: const [
              ButtonSegment(value: _Vue.jour, label: Text('Jour')),
              ButtonSegment(value: _Vue.semaine, label: Text('Semaine')),
              ButtonSegment(value: _Vue.mois, label: Text('Mois')),
              ButtonSegment(value: _Vue.tous, label: Text('Tous')),
            ],
            selected: {_vue},
            onSelectionChanged: (s) {
              setState(() => _vue = s.first);
              _load();
            },
          ),
          if (_vue != _Vue.tous)
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
              InkWell(
                onTap: () { setState(() => _ref = DateTime.now()); _load(); },
                child: Text(_titre,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
            ]),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimer'),
            onPressed: _list.isEmpty ? null : () async {
              await PdfService().imprimerListeRendezVous(
                parametre: await ParametreService().get(),
                titre: _titre, rdvs: _list);
            }),
          OutlinedButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Médecin absent'),
            onPressed: _list.isEmpty ? null : _transfer,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nouveau RDV'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => RendezVousFormScreen(initialDate: _ref)));
              _load();
            }),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${_list.length} rendez-vous',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _list.isEmpty
                      ? const Center(child: Text('Aucun rendez-vous sur cette période'))
                      : ListView(children: _body()),
        ),
      ]),
    );
  }
}
