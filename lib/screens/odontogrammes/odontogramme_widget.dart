import 'package:flutter/material.dart';
import '../../models/odontogramme.dart';
import '../../services/odontogramme_service.dart';

class OdontogrammeWidget extends StatefulWidget {
  final String patientId;
  const OdontogrammeWidget({super.key, required this.patientId});
  @override
  State<OdontogrammeWidget> createState() => _OdontogrammeWidgetState();
}

class _OdontogrammeWidgetState extends State<OdontogrammeWidget> {
  final _svc = OdontogrammeService();
  Odontogramme? _o;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final o = await _svc.getForPatient(widget.patientId);
    if (!mounted) return;
    setState(() {
      _o = o ?? Odontogramme(id: '', patientId: widget.patientId);
      _loading = false;
    });
  }

  Future<void> _onTapTooth(String d) async {
    final res = await showDialog<ToothStatus>(context: context,
      builder: (c) => _ToothDialog(dent: d, initial: _o!.statusOf(d)));
    if (res == null) return;
    final u = await _svc.updateTooth(
      patientId: widget.patientId, dent: d,
      status: res.status, notes: res.notes);
    if (mounted) setState(() => _o = u);
  }

  Future<void> _changeDentition(TypeDentition t) async {
    if (t == _o!.typeDentition) return;
    setState(() => _o = _o!.copyWith(type: t));
    final u = await _svc.changeDentition(widget.patientId, t);
    if (mounted) setState(() => _o = u);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _o == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Sélecteur de type de dentition
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<TypeDentition>(
            segments: const [
              ButtonSegment(value: TypeDentition.permanent,
                label: Text('Adulte'), icon: Icon(Icons.person)),
              ButtonSegment(value: TypeDentition.temporaire,
                label: Text('Enfant'), icon: Icon(Icons.child_care)),
              ButtonSegment(value: TypeDentition.mixte,
                label: Text('Mixte'), icon: Icon(Icons.people)),
            ],
            selected: {_o!.typeDentition},
            onSelectionChanged: (s) => _changeDentition(s.first)))),
        const SizedBox(height: 8),
        // Légende
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 8, children:
            Odontogramme.statuts.entries.map((e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: Odontogramme.couleurs[e.key],
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Text(e.value, style: const TextStyle(fontSize: 11)),
              ])).toList()))),
        const SizedBox(height: 16),
        // Arcade supérieure
        Center(child: Text(
          _o!.typeDentition == TypeDentition.temporaire
            ? 'Dents temporaires — Arcade supérieure (55–65)'
            : 'Arcade supérieure',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        const SizedBox(height: 6),
        _row(_o!.sup),
        const SizedBox(height: 24),
        const Divider(thickness: 2),
        const SizedBox(height: 24),
        Center(child: Text(
          _o!.typeDentition == TypeDentition.temporaire
            ? 'Dents temporaires — Arcade inférieure (85–75)'
            : 'Arcade inférieure',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        const SizedBox(height: 6),
        _row(_o!.inf),
        const SizedBox(height: 24),
        if (_o!.typeDentition == TypeDentition.mixte)
          const Card(
            color: Color(0xFFFFF8E1),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Mode mixte : utilisez les dents permanentes pour les adultes '
                'et le mode Enfant pour les dents temporaires (51–85).',
                style: TextStyle(fontSize: 11)))),
      ]),
    );
  }

  Widget _row(List<String> dents) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dents.map((d) {
        final st = _o!.statusOf(d);
        final color = Odontogramme.couleurs[st.status] ?? Colors.white;
        // séparation centrale : après 11 / 51 (haut) et 41 / 81 (bas)
        final needsGap = d == '11' || d == '51' || d == '41' || d == '81';
        return Row(children: [
          _tooth(d, color),
          if (needsGap) const SizedBox(width: 10),
        ]);
      }).toList(),
    );
  }

  Widget _tooth(String d, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: InkWell(
        onTap: () => _onTapTooth(d),
        child: Column(children: [
          Container(width: 26, height: 34,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 2),
          Text(d, style: const TextStyle(fontSize: 9)),
        ]),
      ),
    );
  }
}

class _ToothDialog extends StatefulWidget {
  final String dent;
  final ToothStatus initial;
  const _ToothDialog({required this.dent, required this.initial});
  @override
  State<_ToothDialog> createState() => _ToothDialogState();
}

class _ToothDialogState extends State<_ToothDialog> {
  late String _status = widget.initial.status;
  late final _notes = TextEditingController(text: widget.initial.notes);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dent ${widget.dent}'),
      content: SizedBox(width: 320, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: Odontogramme.statuts.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
            onChanged: (v) => setState(() => _status = v!)),
          const SizedBox(height: 12),
          TextField(controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
            maxLines: 2),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context,
            ToothStatus(status: _status, notes: _notes.text.trim())),
          child: const Text('Enregistrer')),
      ],
    );
  }
}