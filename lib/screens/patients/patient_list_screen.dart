import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});
  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _svc = PatientService();
  final _search = TextEditingController();
  List<Patient> _list = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.search(_search.text.trim());
    if (mounted) setState(() { _list = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Rechercher (nom, prénom, n° dossier)',
                prefixIcon: Icon(Icons.search)),
              onChanged: (_) => _load())),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PatientFormScreen()));
                _load();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Nouveau patient')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = _list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(p.prenom.isNotEmpty ? p.prenom[0].toUpperCase() : '?')),
                        title: Text(p.fullName),
                        subtitle: Text('N° ${p.numeroDossier} • ${p.telephone}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(context,
                            MaterialPageRoute(builder: (_) =>
                              PatientDetailScreen(patientId: p.id)));
                          _load();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}