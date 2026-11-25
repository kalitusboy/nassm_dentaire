import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stock.dart';
import '../../services/stock_service.dart';

/// Gestion de stock : consommables, anesthésiques, instruments, équipements…
/// Alertes automatiques pour les quantités basses et les péremptions.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _svc = StockService();
  List<StockItem> _list = [];
  String _cat = '';
  bool _loading = true;

  static const cats = {
    '': 'Tous',
    'consommable': 'Consommables',
    'anesthesie': 'Anesthésie',
    'instrument': 'Instruments',
    'equipement': 'Équipements',
    'autre': 'Autre',
  };

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _svc.list(categorie: _cat);
    if (mounted) setState(() { _list = r; _loading = false; });
  }

  Future<void> _form({StockItem? item}) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _StockFormScreen(existing: item)));
    _load();
  }

  Future<void> _ajuster(StockItem i, double d) async {
    await _svc.ajuster(i.id, d);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _list.where((a) => a.estBas || a.estExpire).length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          const Text('Gestion de stock',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (alerts > 0)
            Chip(label: Text('$alerts alerte(s)'),
              backgroundColor: Colors.red.shade100,
              visualDensity: VisualDensity.compact),
          const Spacer(),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nouvel article'),
            onPressed: () => _form()),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: cats.entries.map((e) => ChoiceChip(
          label: Text(e.value),
          selected: _cat == e.key,
          onSelected: (_) { setState(() => _cat = e.key); _load(); })).toList()),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
            ? const Center(child: Text('Aucun article'))
            : ListView.builder(
                itemCount: _list.length,
                itemBuilder: (_, i) {
                  final a = _list[i];
                  final df = DateFormat('dd/MM/yyyy', 'fr_FR');
                  return Card(
                    color: a.estBas || a.estExpire ? Colors.red.shade50 : null,
                    child: ListTile(
                      leading: Icon(a.estExpire
                        ? Icons.timer_off : a.estBas
                        ? Icons.warning_amber : Icons.inventory_2,
                        color: a.estBas || a.estExpire ? Colors.red : Colors.teal),
                      title: Text(a.nom,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${cats[a.categorie] ?? a.categorie}'
                        '${a.estExpire ? " • PÉRIMÉ (le ${df.format(a.expireLe!)})" : a.expireLe != null ? " • Expire le ${df.format(a.expireLe!)}" : ""}'
                        '${a.prixUnitaire > 0 ? " • ${a.prixUnitaire.toStringAsFixed(0)} DA/${a.unite}" : ""}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${a.quantite.toStringAsFixed(a.quantite.truncateToDouble() == a.quantite ? 0 : 1)} ${a.unite}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: a.estBas ? Colors.red : Colors.black)),
                          if (a.seuilAlerte > 0)
                            Text('seuil : ${a.seuilAlerte.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 11,
                                  color: Colors.grey.shade600)),
                        ]),
                        IconButton(icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Sortie',
                          onPressed: () => _ajuster(a, -1)),
                        IconButton(icon: const Icon(Icons.add_circle_outline),
                          tooltip: 'Entrée',
                          onPressed: () => _ajuster(a, 1)),
                        IconButton(icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _form(item: a)),
                      ]),
                    ));
                })),
      ]),
    );
  }
}

class _StockFormScreen extends StatefulWidget {
  final StockItem? existing;
  const _StockFormScreen({this.existing});
  @override
  State<_StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<_StockFormScreen> {
  final _f = GlobalKey<FormState>();
  final _svc = StockService();
  final _nom = TextEditingController();
  final _unite = TextEditingController();
  final _qte = TextEditingController();
  final _seuil = TextEditingController();
  final _prix = TextEditingController();
  final _notes = TextEditingController();
  String _cat = 'consommable';
  DateTime? _exp;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nom.text = e.nom; _cat = e.categorie;
      _unite.text = e.unite;
      _qte.text = e.quantite.toStringAsFixed(0);
      _seuil.text = e.seuilAlerte.toStringAsFixed(0);
      _prix.text = e.prixUnitaire.toStringAsFixed(0);
      _notes.text = e.notes; _exp = e.expireLe;
    } else {
      _unite.text = 'u';
    }
  }

  @override
  void dispose() {
    _nom.dispose(); _unite.dispose(); _qte.dispose();
    _seuil.dispose(); _prix.dispose(); _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_f.currentState!.validate()) return;
    setState(() => _saving = true);
    final item = StockItem(
      id: widget.existing?.id ?? '', nom: _nom.text.trim(), categorie: _cat,
      unite: _unite.text.trim().isEmpty ? 'u' : _unite.text.trim(),
      quantite: double.tryParse(_qte.text.trim()) ?? 0,
      seuilAlerte: double.tryParse(_seuil.text.trim()) ?? 0,
      prixUnitaire: double.tryParse(_prix.text.trim()) ?? 0,
      notes: _notes.text.trim(), expireLe: _exp);
    try {
      if (widget.existing == null) { await _svc.create(item); }
      else { await _svc.update(item.id, item); }
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null
        ? 'Nouvel article' : 'Modifier l\u2019article')),
      body: Form(key: _f,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          TextFormField(controller: _nom,
            decoration: const InputDecoration(labelText: 'Désignation'),
            validator: (v) => v!.isEmpty ? 'Requis' : null),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _cat,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: const [
              DropdownMenuItem(value: 'consommable', child: Text('Consommables')),
              DropdownMenuItem(value: 'anesthesie', child: Text('Anesthésie')),
              DropdownMenuItem(value: 'instrument', child: Text('Instruments')),
              DropdownMenuItem(value: 'equipement', child: Text('Équipements')),
              DropdownMenuItem(value: 'autre', child: Text('Autre')),
            ],
            onChanged: (v) => setState(() => _cat = v!)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _qte, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantité'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _unite,
              decoration: const InputDecoration(labelText: 'Unité (u, boîte, ml…)'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _seuil, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seuil d\u2019alerte',
                helperText: 'Alerte quand la quantité passe sous ce seuil'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _prix, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix unitaire (DA)'))),
          ]),
          const SizedBox(height: 12),
          ListTile(contentPadding: EdgeInsets.zero,
            title: Text(_exp != null
              ? 'Péremption : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(_exp!)}'
              : 'Date de péremption (optionnel)'),
            trailing: const Icon(Icons.event),
            onTap: () async {
              final d = await showDatePicker(context: context,
                initialDate: _exp ?? DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now(), lastDate: DateTime(2100));
              if (d != null) setState(() => _exp = d);
            }),
          TextFormField(controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save), label: const Text('Enregistrer')),
        ])));
  }
}
