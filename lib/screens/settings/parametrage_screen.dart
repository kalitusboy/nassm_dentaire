import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/parametre.dart';
import '../../services/parametre_service.dart';

class ParametrageScreen extends StatefulWidget {
  const ParametrageScreen({super.key});
  @override
  State<ParametrageScreen> createState() => _ParametrageScreenState();
}

class _ParametrageScreenState extends State<ParametrageScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = ParametreService();
  final _nom = TextEditingController();
  final _titre = TextEditingController();
  final _adresse = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  final _ordre = TextEditingController();
  String? _id;
  bool _loading = true;

  @override
  void dispose() {
    _nom.dispose();
    _titre.dispose();
    _adresse.dispose();
    _tel.dispose();
    _email.dispose();
    _ordre.dispose();
    super.dispose();
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final p = await _svc.get(refresh: true);
    if (p != null) {
      _id = p.id;
      _nom.text = p.nomClinique; _titre.text = p.titrePraticien;
      _adresse.text = p.adresse; _tel.text = p.telephone;
      _email.text = p.email; _ordre.text = p.numeroOrdre;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    await _svc.save(Parametre(
      id: _id ?? '', nomClinique: _nom.text.trim(),
      titrePraticien: _titre.text.trim(), adresse: _adresse.text.trim(),
      telephone: _tel.text.trim(), email: _email.text.trim(),
      numeroOrdre: _ordre.text.trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: _f,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Informations du cabinet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Ces informations apparaissent sur les ordonnances et factures.',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 24),
          TextFormField(controller: _nom,
            decoration: const InputDecoration(
              labelText: 'Nom de la clinique', hintText: 'MOSSAB MOHAMMED'),
            validator: (v) => v!.isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _titre,
            decoration: const InputDecoration(
              labelText: 'Titre du praticien', hintText: 'CHIRURGIEN DENTISTE')),
          const SizedBox(height: 12),
          TextFormField(controller: _ordre,
            decoration: const InputDecoration(labelText: 'N° d\'ordre (optionnel)')),
          const SizedBox(height: 12),
          TextFormField(controller: _adresse,
            decoration: const InputDecoration(labelText: 'Adresse'), maxLines: 2),
          const SizedBox(height: 12),
          TextFormField(controller: _tel,
            decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 12),
          TextFormField(controller: _email,
            decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 24),
          Card(child: ListTile(
            leading: const Icon(Icons.image, color: Colors.teal),
            title: const Text('Logo de la clinique'),
            subtitle: const Text('Sélectionner une image (PNG/JPG) à imprimer '
                'sur les ordonnances et factures.'),
            trailing: OutlinedButton(
              child: const Text('Téléverser'),
              onPressed: () async {
                final res = await FilePicker.platform.pickFiles(
                  type: FileType.image);
                if (res == null || res.files.single.path == null) return;
                final ok = await _svc.uploadLogo(res.files.single.path!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                      ? 'Logo enregistré avec succès'
                      : 'Erreur : enregistrez d\'abord les informations du cabinet')));
                }
              }))),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save),
            label: const Text('Enregistrer')),
        ],
      ),
    );
  }
}