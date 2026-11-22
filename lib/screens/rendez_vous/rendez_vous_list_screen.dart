import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rendez_vous.dart';
import '../../services/parametre_service.dart';
import '../../services/pdf_service.dart';
import '../../services/rendez_vous_service.dart';
import 'rendez_vous_form_screen.dart';

class RendezVousListScreen extends StatefulWidget {
  const RendezVousListScreen({super.key});
  @override
  State<RendezVousListScreen> createState() => _RendezVousListScreenState();
}

class _RendezVousListScreenState extends State<RendezVousListScreen> {
  final _svc = RendezVousService();
  DateTime _day = DateTime.now();
  List<RendezVous> _list = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.listForDay(_day);
    if (mounted) setState(() { _list = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy', 'fr_FR');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _day = _day.subtract(const Duration(days: 1)));
              _load();
            }),
          Text(df.format(_day),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _day = _day.add(const Duration(days: 1)));
              _load();
            }),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('Imprimer'),
            onPressed: _list.isEmpty ? null : () async {
              await PdfService().imprimerRendezVousDuJour(
                parametre: await ParametreService().get(),
                jour: _day, rdvs: _list);
            }),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nouveau RDV'),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => RendezVousFormScreen(initialDate: _day)));
              _load();
            }),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _list.isEmpty
                  ? const Center(child: Text('Aucun rendez-vous ce jour'))
                  : ListView.builder(
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final r = _list[i];
                        return Card(child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Text(DateFormat('HH:mm').format(r.dateHeure),
                              style: const TextStyle(fontSize: 11))),
                          title: Text(r.patientNom),
                          subtitle: Text('${r.motif} • Dr. ${r.medecinNom}'),
                          trailing: Chip(label: Text(r.statut),
                            visualDensity: VisualDensity.compact),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => RendezVousFormScreen(existing: r)));
                            _load();
                          },
                        ));
                      },
                    ),
        ),
      ]),
    );
  }
}