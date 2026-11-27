import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/radiographie.dart';
import '../../services/radiographie_service.dart';

class RadiographieScreen extends StatefulWidget {
  final String patientId;
  const RadiographieScreen({super.key, required this.patientId});
  @override
  State<RadiographieScreen> createState() => _RadiographieScreenState();
}

class _RadiographieScreenState extends State<RadiographieScreen> {
  final _svc = RadiographieService();
  List<Radiographie> _list = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.listForPatient(widget.patientId);
    if (mounted) setState(() { _list = r; _loading = false; });
  }

  Future<void> _upload() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null || res.files.single.path == null) return;
    final file = File(res.files.single.path!);
    if (!mounted) return;
    final type = await showDialog<String>(context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Type de radiographie'),
        children: [
          for (final t in ['panoramique', 'periapicale', 'cbct', 'autre'])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, t), child: Text(t)),
        ]));
    if (type == null) return;
    await _svc.upload(patientId: widget.patientId, file: file, type: type);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radiographies')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('Aucune radiographie'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  itemCount: _list.length,
                  itemBuilder: (_, i) {
                    final r = _list[i];
                    return Card(child: InkWell(
                      onLongPress: () async {
                        final ok = await showDialog<bool>(context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Supprimer cette image ?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false),
                                child: const Text('Annuler')),
                              ElevatedButton(onPressed: () => Navigator.pop(c, true),
                                child: const Text('Supprimer')),
                            ]));
                        if (ok == true) { await _svc.delete(r.id); _load(); }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: Image.network(r.fileUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
                          Padding(padding: const EdgeInsets.all(4),
                            child: Text('${r.type}\n${DateFormat('dd/MM/yyyy').format(r.date)}',
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center)),
                        ])));
                  }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload, icon: const Icon(Icons.upload_file),
        label: const Text('Ajouter')),
    );
  }
}