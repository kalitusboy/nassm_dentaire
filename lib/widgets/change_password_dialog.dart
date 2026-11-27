import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

/// Boîte de dialogue « Changer mon mot de passe ». Déconnecte après succès.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final userId = auth.userId;
  final isDefaultAdmin = auth.username == AppConfig.defaultAdminUser;
  final old = TextEditingController();
  final nw = TextEditingController();
  final nw2 = TextEditingController();
  final key = GlobalKey<FormState>();
  String? err;
  bool busy = false;

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: const Text('Changer mon mot de passe'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: old,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                  validator: (v) => (v ?? '').isEmpty ? 'Requis' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: nw,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Nouveau mot de passe (6 caractères min.)'),
                  validator: (v) => (v ?? '').length < 6 ? '6 caractères minimum' : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: nw2,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmer'),
                  validator: (v) => v != nw.text ? 'Les mots de passe diffèrent' : null),
              if (err != null) ...[
                const SizedBox(height: 12),
                Text(err!, style: const TextStyle(color: Colors.red)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    if (!key.currentState!.validate()) return;
                    setD(() { busy = true; err = null; });
                    try {
                      await UserService().changeOwnPassword(userId, old.text, nw.text);
                      if (c.mounted) Navigator.pop(c, true);
                    } catch (e) {
                      setD(() { busy = false; err = UserService.errorMessage(e); });
                    }
                  },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
  // Controllers non libérés ici : l'animation de fermeture du dialog les utilise encore.
  if (ok == true && context.mounted) {
    if (isDefaultAdmin) await AppConfig.setDefaultPasswordActive(false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe modifié. Reconnectez-vous.')));
    context.read<AuthProvider>().logout();
  }
}
