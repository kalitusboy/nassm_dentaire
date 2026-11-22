import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../setup/setup_screen.dart' show validateUsername;

/// Gestion des utilisateurs (administrateur uniquement).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _svc = UserService();
  List<RecordModel> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await _svc.list();
    } catch (e) {
      _error = UserService.errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Future<void> _openDialog({RecordModel? user}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UserDialog(user: user, svc: _svc),
    );
    if (saved == true) {
      _snack(user == null ? 'Utilisateur créé' : 'Utilisateur modifié');
      _load();
    }
  }

  Future<void> _delete(RecordModel u) async {
    final me = context.read<AuthProvider>().userId;
    if (u.id == me) {
      _snack('Vous ne pouvez pas supprimer votre propre compte.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text(
            '${u.getStringValue('prenom')} ${u.getStringValue('nom')} ne pourra plus se connecter.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.delete(u.id);
      _load();
    } catch (e) {
      _snack(UserService.errorMessage(e));
    }
  }

  IconData _icon(String role) => switch (role) {
        'admin' => Icons.admin_panel_settings,
        'dentiste' => Icons.medical_services,
        _ => Icons.support_agent,
      };

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().userId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              onPressed: _load,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nouvel utilisateur'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final role = u.getStringValue('role');
                    final full =
                        '${u.getStringValue('prenom')} ${u.getStringValue('nom')}'
                            .trim();
                    return ListTile(
                      leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(_icon(role), color: Colors.teal)),
                      title: Text(full.isEmpty ? u.getStringValue('username') : full,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${UserService.roleLabels[role] ?? role} • ${u.getStringValue('username')}'
                          '${u.id == me ? '  (vous)' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Modifier',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _openDialog(user: u)),
                        IconButton(
                            tooltip: 'Supprimer',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: u.id == me ? null : () => _delete(u)),
                      ]),
                    );
                  },
                ),
    );
  }
}

class _UserDialog extends StatefulWidget {
  final RecordModel? user;
  final UserService svc;
  const _UserDialog({required this.user, required this.svc});
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _key = GlobalKey<FormState>();
  late final _prenom =
      TextEditingController(text: widget.user?.getStringValue('prenom') ?? '');
  late final _nom =
      TextEditingController(text: widget.user?.getStringValue('nom') ?? '');
  late final _username = TextEditingController(
      text: widget.user?.getStringValue('username') ?? '');
  final _pass = TextEditingController();
  late String _role = widget.user?.getStringValue('role') ?? 'reception';
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.user == null;
  bool get _isAdminUser => widget.user?.getStringValue('role') == 'admin';

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isNew) {
        await widget.svc.create(
          username: _username.text.trim().toLowerCase(),
          password: _pass.text,
          nom: _nom.text.trim(),
          prenom: _prenom.text.trim(),
          role: _role,
        );
      } else {
        await widget.svc.update(
          widget.user!.id,
          nom: _nom.text.trim(),
          prenom: _prenom.text.trim(),
          role: _role,
          newPassword: _pass.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = UserService.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Nouvel utilisateur' : 'Modifier l\'utilisateur'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _prenom,
                    decoration: const InputDecoration(labelText: 'Prénom'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nom,
                    decoration: const InputDecoration(labelText: 'Nom'),
                    validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                enabled: _isNew,
                decoration: const InputDecoration(
                    labelText: 'Identifiant de connexion',
                    prefixIcon: Icon(Icons.person)),
                validator: _isNew ? validateUsername : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: _isNew
                        ? 'Mot de passe'
                        : 'Nouveau mot de passe (facultatif)',
                    prefixIcon: const Icon(Icons.lock)),
                validator: (v) {
                  final s = v ?? '';
                  if (_isNew && s.length < 6) return '6 caractères minimum';
                  if (!_isNew && s.isNotEmpty && s.length < 6) {
                    return '6 caractères minimum';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_isAdminUser)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Type : Administrateur (non modifiable)'),
                )
              else
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'dentiste',
                        icon: Icon(Icons.medical_services),
                        label: Text('Dentiste')),
                    ButtonSegment(
                        value: 'reception',
                        icon: Icon(Icons.support_agent),
                        label: Text('Réceptionniste')),
                  ],
                  selected: {_role == 'dentiste' ? 'dentiste' : 'reception'},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
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
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer')),
      ],
    );
  }
}
