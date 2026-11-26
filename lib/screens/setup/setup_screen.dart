import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/admin_api.dart';
import '../../services/backup_service.dart';
import '../../services/db_bootstrap.dart';
import '../../services/pb_client.dart';
import '../../services/server_manager.dart';

/// Assistant de première installation.
class SetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupScreen({super.key, required this.onDone});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

enum _Step { choose, host, client }

class _SetupScreenState extends State<SetupScreen> {
  _Step _step = _Step.choose;
  bool _busy = false;
  String _status = '';
  String? _error;

  final _hostKey = GlobalKey<FormState>();
  final _clinic = TextEditingController();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  final _url = TextEditingController(text: 'http://192.168.1.10:8090');

  @override
  void dispose() {
    for (final c in [_clinic, _prenom, _nom, _user, _pass, _pass2, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  // ───────────────────────── Poste principal ─────────────────────────
  Future<void> _installHost() async {
    if (!_hostKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Démarrage de la base de données…';
    });
    try {
      await ServerManager.instance.ensureRunning();

      setState(() => _status = 'Préparation des tables…');
      final boot = DbBootstrap(AdminApi());
      try {
        await boot.ensureSchema();
      } on AdminApiException catch (e) {
        if (!e.message.contains('Authentification interne')) rethrow;
        // compte interne désynchronisé : on le régénère puis on réessaie une fois
        await ServerManager.instance.resetAdmin();
        await boot.ensureSchema();
      }

      setState(() => _status = 'Création du compte…');
      if (!await boot.hasUsers()) {
        await boot.createFirstAccount(clinicName: _clinic.text.trim());
        await AppConfig.setDefaultPasswordActive(true);
      }
      await AppConfig.setMode(AppMode.host);
      await AppConfig.setSetupDone(true);
      PbClient.reset();
      widget.onDone();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// Réinstallation : récupère toutes les données depuis une sauvegarde (.zip).
  Future<void> _restoreHost() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Choisir le fichier de sauvegarde');
    final path = r?.files.single.path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Restauration des données…';
    });
    try {
      await ServerManager.instance.ensureRunning();
      final ok = await BackupService().restoreFromFile(path);
      if (!ok) throw Exception('La base ne répond pas après la restauration.');
      await AppConfig.setMode(AppMode.host);
      await AppConfig.setSetupDone(true);
      await AppConfig.setDefaultPasswordActive(false);
      PbClient.reset();
      widget.onDone();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  // ───────────────────────── Poste secondaire ─────────────────────────
  Future<void> _connectClient() async {
    var u = _url.text.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http')) u = 'http://$u';
    if (!RegExp(r':\d+$').hasMatch(u)) u = '$u:${AppConfig.serverPort}';
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Connexion au poste principal…';
    });
    if (!await ServerManager.ping(u)) {
      setState(() {
        _busy = false;
        _error = 'Aucun poste principal trouvé à cette adresse.\n'
            'Vérifiez l\'adresse affichée dans Réglages du poste principal, '
            'et que les deux ordinateurs sont sur le même réseau.';
      });
      return;
    }
    await AppConfig.setMode(AppMode.client);
    await AppConfig.setServerUrl(u);
    await AppConfig.setSetupDone(true);
    PbClient.reset();
    widget.onDone();
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _busy ? _busyView() : _body(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _busyView() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(_status),
          const SizedBox(height: 24),
        ],
      );

  Widget _header(String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital, size: 48, color: Colors.teal),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 24),
        ],
      );

  Widget _errorBox() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SelectableText(_error!,
              style: const TextStyle(color: Colors.red)),
        );

  Widget _body() {
    switch (_step) {
      case _Step.choose:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Bienvenue', 'Quel est le rôle de cet ordinateur ?'),
            _ChoiceCard(
              icon: Icons.computer,
              title: 'Poste principal',
              subtitle:
                  'Premier ordinateur du cabinet. Il contient les données — rien d\'autre à installer.',
              enabled: ServerManager.instance.supported,
              disabledNote: 'Disponible uniquement sous Windows',
              onTap: () => setState(() => _step = _Step.host),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.lan,
              title: 'Poste secondaire',
              subtitle:
                  'Se connecte au poste principal du cabinet (autre PC, tablette, téléphone).',
              onTap: () => setState(() => _step = _Step.client),
            ),
          ],
        );

      case _Step.host:
        return Form(
          key: _hostKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header('Créer votre cabinet',
                  'Un compte administrateur est créé automatiquement.'),
              TextFormField(
                controller: _clinic,
                decoration: const InputDecoration(
                    labelText: 'Nom du cabinet', prefixIcon: Icon(Icons.business)),
                validator: (v) => v!.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compte administrateur par défaut',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    SelectableText('Identifiant : admin\nMot de passe : admin123'),
                    SizedBox(height: 6),
                    Text(
                        'Connectez-vous avec ce compte, créez vos utilisateurs '
                        '(dentistes, réceptionnistes) dans « Utilisateurs », puis '
                        'changez ce mot de passe.',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _restoreHost,
                icon: const Icon(Icons.restore),
                label: const Text('J\'ai déjà une sauvegarde : la restaurer'),
              ),
              const SizedBox(height: 8),
              _errorBox(),
              Row(children: [
                TextButton(
                    onPressed: () => setState(() {
                          _step = _Step.choose;
                          _error = null;
                        }),
                    child: const Text('Retour')),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _installHost,
                  icon: const Icon(Icons.check),
                  label: const Text('Terminer l\'installation'),
                ),
              ]),
            ],
          ),
        );

      case _Step.client:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Connexion au poste principal',
                'Saisissez l\'adresse affichée dans Réglages → Ce poste, sur le poste principal.'),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                  labelText: 'Adresse du poste principal',
                  prefixIcon: Icon(Icons.link)),
            ),
            const SizedBox(height: 20),
            _errorBox(),
            Row(children: [
              TextButton(
                  onPressed: () => setState(() {
                        _step = _Step.choose;
                        _error = null;
                      }),
                  child: const Text('Retour')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _connectClient,
                icon: const Icon(Icons.wifi),
                label: const Text('Se connecter'),
              ),
            ]),
          ],
        );
    }
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool enabled;
  final String disabledNote;
  final VoidCallback onTap;
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.disabledNote = '',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.teal.withOpacity(enabled ? 0.5 : 0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        enabled: enabled,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 36, color: enabled ? Colors.teal : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(enabled ? subtitle : '$subtitle\n$disabledNote'),
        trailing: const Icon(Icons.chevron_right),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
