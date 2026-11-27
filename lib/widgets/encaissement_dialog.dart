import 'package:flutter/material.dart';

import '../services/caisse_service.dart';
import '../services/user_service.dart';
import '../utils/fmt.dart';

/// Encaissement d'un patient (sortie du cabinet, ou plus tard, un autre jour).
/// Retourne true si l'opération est terminée (encaissé, ou « terminer sans encaisser »).
class EncaissementDialog extends StatefulWidget {
  final String patientId, patientNom;
  /// true : ouvert depuis la salle d'attente (propose « Terminer sans encaisser »).
  final bool fromQueue;
  const EncaissementDialog(
      {super.key, required this.patientId, required this.patientNom, this.fromQueue = false});
  @override
  State<EncaissementDialog> createState() => _EncaissementDialogState();
}

class _EncaissementDialogState extends State<EncaissementDialog> {
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
      final d = await _caisse.actesDus(widget.patientId);
      if (mounted) setState(() { _dus = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  double get _total => _dus.fold<double>(0, (s, d) => s + d.reste);
  double? get _saisi => double.tryParse(_montant.text.trim().replaceAll(',', '.'));

  Future<void> _terminerSansEncaisser() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Terminer sans encaisser ?'),
        content: Text(_total > 0
            ? 'Aucun paiement ne sera enregistré. Le reste dû (${fmtMoney(_total)}) '
                'est conservé : vous pourrez encaisser plus tard depuis le dossier du '
                'patient ou la liste « Restes à payer » (Recettes).'
            : 'Aucun paiement ne sera enregistré.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Retour')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Terminer')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

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
      // Un autre poste a peut-être encaissé entre-temps : on revérifie le dû.
      final frais = await _caisse.actesDus(widget.patientId);
      final nouveauTotal = frais.fold<double>(0, (s, d) => s + d.reste);
      if ((nouveauTotal - _total).abs() > 0.01) {
        setState(() {
          _dus = frais;
          _busy = false;
          _error = 'Les montants dus ont changé (un autre poste a enregistré un '
              'paiement ou modifié un prix). Vérifiez puis validez à nouveau.';
        });
        return;
      }
      await _caisse.encaisser(
          patientId: widget.patientId, montant: m, methode: _methode, dus: _dus);
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
      title: Text('Encaissement — ${widget.patientNom}'),
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
        if (widget.fromQueue)
          OutlinedButton(
            onPressed: _busy ? null : _terminerSansEncaisser,
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
