import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../providers/auth_provider.dart';
import '../../services/stock_service.dart';
import '../../services/user_service.dart';
import '../../utils/fmt.dart';

/// Gestion du stock : anesthésiques, seringues, consommables, matériel…
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _svc = StockService();
  final _search = TextEditingController();
  List<Article> _all = [];
  bool _loading = true, _onlyAlerts = false;
  String _cat = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _all = await _svc.list();
    } catch (e) {
      _error = UserService.errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<Article> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((a) {
      if (_onlyAlerts && !a.enAlerte) return false;
      if (_cat.isNotEmpty && a.categorie != _cat) return false;
      if (q.isNotEmpty && !a.nom.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  Future<void> _editArticle({Article? article}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ArticleDialog(article: article, svc: _svc),
    );
    if (ok == true) _load();
  }

  Future<void> _movement(Article a, String type) async {
    final userId = context.read<AuthProvider>().userId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _MovementDialog(article: a, type: type, svc: _svc, userId: userId),
    );
    if (ok == true) _load();
  }

  Future<void> _history(Article a) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _HistoryDialog(article: a, svc: _svc),
    );
  }

  Future<void> _delete(Article a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cet article ?'),
        content: Text(a.nom),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.delete(a.id);
      _load();
    } catch (e) {
      _snack(UserService.errorMessage(e));
    }
  }

  String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final list = _filtered;
    final nAlert = _all.where((a) => a.enAlerte).length;
    final valeur = _all.fold<double>(0, (s, a) => s + a.quantite * a.prixUnitaire);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _load, tooltip: 'Actualiser', icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editArticle(),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel article'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(children: [
                    Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                              labelText: 'Rechercher un article', prefixIcon: Icon(Icons.search)),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          value: _cat,
                          decoration: const InputDecoration(labelText: 'Catégorie'),
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Toutes')),
                            for (final e in Article.categorieLibelles.entries)
                              DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) => setState(() => _cat = v ?? ''),
                        ),
                      ),
                      FilterChip(
                        label: Text('En alerte ($nAlert)'),
                        avatar: const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                        selected: _onlyAlerts,
                        onSelected: (v) => setState(() => _onlyAlerts = v),
                      ),
                      Text('${_all.length} article(s)'
                          '${auth.isAdmin || auth.isReception ? ' • valeur ${fmtMoney(valeur)}' : ''}',
                          style: TextStyle(color: Colors.grey.shade700)),
                    ]),
                    const SizedBox(height: 8),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text('Aucun article'))
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 96),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final a = list[i];
                                final color = a.enRupture
                                    ? Colors.red
                                    : a.enAlerte
                                        ? Colors.orange
                                        : Colors.teal;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Icon(
                                      a.enAlerte ? Icons.warning_amber : Icons.inventory_2,
                                      color: color,
                                    ),
                                  ),
                                  title: Text(a.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text('${a.categorieLibelle}'
                                      '${a.fournisseur.isEmpty ? '' : ' • ${a.fournisseur}'}'
                                      '${a.seuilAlerte > 0 ? ' • seuil ${_qty(a.seuilAlerte)}' : ''}'),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('${_qty(a.quantite)} ${a.unite}',
                                        style: TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                                    const SizedBox(width: 8),
                                    IconButton(
                                        tooltip: 'Entrée (réception de stock)',
                                        icon: const Icon(Icons.add_circle, color: Colors.green),
                                        onPressed: () => _movement(a, 'entree')),
                                    IconButton(
                                        tooltip: 'Sortie (utilisation)',
                                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                                        onPressed: () => _movement(a, 'sortie')),
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _editArticle(article: a);
                                        if (v == 'adjust') _movement(a, 'ajustement');
                                        if (v == 'history') _history(a);
                                        if (v == 'delete') _delete(a);
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'history', child: Text('Historique')),
                                        const PopupMenuItem(value: 'adjust', child: Text('Ajuster (inventaire)')),
                                        const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                                        if (auth.isAdmin)
                                          const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                                      ],
                                    ),
                                  ]),
                                  onTap: () => _history(a),
                                );
                              },
                            ),
                    ),
                  ]),
                ),
    );
  }
}

// ═════════════ Création / modification d'un article ═════════════
class _ArticleDialog extends StatefulWidget {
  final Article? article;
  final StockService svc;
  const _ArticleDialog({required this.article, required this.svc});
  @override
  State<_ArticleDialog> createState() => _ArticleDialogState();
}

class _ArticleDialogState extends State<_ArticleDialog> {
  final _key = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.article?.nom ?? '');
  late final _unite = TextEditingController(text: widget.article?.unite ?? '');
  late final _qte = TextEditingController(
      text: widget.article == null ? '' : widget.article!.quantite.toString());
  late final _seuil = TextEditingController(
      text: widget.article == null || widget.article!.seuilAlerte == 0
          ? ''
          : widget.article!.seuilAlerte.toString());
  late final _prix = TextEditingController(
      text: widget.article == null || widget.article!.prixUnitaire == 0
          ? ''
          : widget.article!.prixUnitaire.toString());
  late final _four = TextEditingController(text: widget.article?.fournisseur ?? '');
  late String _cat = (widget.article?.categorie ?? '').isEmpty ? 'consommable' : widget.article!.categorie;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nom, _unite, _qte, _seuil, _prix, _four]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final a = Article(
        id: widget.article?.id ?? '',
        nom: _nom.text.trim(),
        categorie: _cat,
        unite: _unite.text.trim(),
        quantite: _d(_qte),
        seuilAlerte: _d(_seuil),
        prixUnitaire: _d(_prix),
        fournisseur: _four.text.trim(),
        notes: widget.article?.notes ?? '',
      );
      if (widget.article == null) {
        await widget.svc.create(a);
      } else {
        await widget.svc.update(a.id, a);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _busy = false; _error = UserService.errorMessage(e); });
    }
  }

  String? _num(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.')) == null ? 'Nombre invalide' : null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.article == null ? 'Nouvel article' : 'Modifier l\'article'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _nom,
                decoration: const InputDecoration(
                    labelText: 'Désignation', hintText: 'ex. Articaïne 4% — boîte de 50'),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _cat,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final e in Article.categorieLibelles.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _cat = v ?? 'autre'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qte,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: widget.article == null ? 'Quantité initiale' : 'Quantité'),
                    validator: _num,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unite,
                    decoration: const InputDecoration(labelText: 'Unité', hintText: 'boîte, pièce…'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _seuil,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Seuil d\'alerte', helperText: 'Alerte si quantité ≤ seuil'),
                    validator: _num,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _prix,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prix unitaire (DA)'),
                    validator: _num,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _four,
                decoration: const InputDecoration(labelText: 'Fournisseur (facultatif)'),
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
        ElevatedButton(onPressed: _busy ? null : _save, child: const Text('Enregistrer')),
      ],
    );
  }
}

// ═════════════ Entrée / sortie / ajustement ═════════════
class _MovementDialog extends StatefulWidget {
  final Article article;
  final String type, userId;
  final StockService svc;
  const _MovementDialog(
      {required this.article, required this.type, required this.svc, required this.userId});
  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _qte = TextEditingController();
  final _motif = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qte.dispose();
    _motif.dispose();
    super.dispose();
  }

  String get _titre => switch (widget.type) {
        'entree' => 'Entrée de stock',
        'sortie' => 'Sortie de stock',
        _ => 'Ajustement (inventaire)',
      };

  Future<void> _save() async {
    final q = double.tryParse(_qte.text.trim().replaceAll(',', '.'));
    if (q == null || q < 0 || (widget.type != 'ajustement' && q == 0)) {
      setState(() => _error = 'Quantité invalide.');
      return;
    }
    if (widget.type == 'sortie' && q > widget.article.quantite) {
      setState(() => _error = 'Stock insuffisant (${widget.article.quantite} disponible).');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.svc.mouvement(
        articleId: widget.article.id,
        type: widget.type,
        quantite: q,
        userId: widget.userId,
        motif: _motif.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _busy = false; _error = UserService.errorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$_titre — ${widget.article.nom}'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Quantité actuelle : ${widget.article.quantite} ${widget.article.unite}'),
          const SizedBox(height: 12),
          TextField(
            controller: _qte,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
                labelText: widget.type == 'ajustement' ? 'Nouvelle quantité réelle' : 'Quantité'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motif,
            decoration: const InputDecoration(
                labelText: 'Motif (facultatif)', hintText: 'ex. livraison, soin patient, casse…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        ElevatedButton(onPressed: _busy ? null : _save, child: const Text('Valider')),
      ],
    );
  }
}

// ═════════════ Historique ═════════════
class _HistoryDialog extends StatelessWidget {
  final Article article;
  final StockService svc;
  const _HistoryDialog({required this.article, required this.svc});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Historique — ${article.nom}'),
      content: SizedBox(
        width: 460,
        height: 360,
        child: FutureBuilder<List<MouvementStock>>(
          future: svc.historique(article.id),
          builder: (_, s) {
            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) return Text('${s.error}');
            final l = s.data ?? [];
            if (l.isEmpty) return const Center(child: Text('Aucun mouvement'));
            return ListView.separated(
              itemCount: l.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = l[i];
                final entree = m.type == 'entree';
                final aj = m.type == 'ajustement';
                return ListTile(
                  dense: true,
                  leading: Icon(
                    aj ? Icons.tune : entree ? Icons.add_circle : Icons.remove_circle,
                    color: aj ? Colors.blueGrey : entree ? Colors.green : Colors.red,
                  ),
                  title: Text('${aj ? '=' : entree ? '+' : '−'}${m.quantite} ${article.unite}'
                      '${m.motif.isEmpty ? '' : ' — ${m.motif}'}'),
                  subtitle: Text('${fmtDateTime(m.date)}'
                      '${m.utilisateurNom.isEmpty ? '' : ' • ${m.utilisateurNom}'}'),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      ],
    );
  }
}
