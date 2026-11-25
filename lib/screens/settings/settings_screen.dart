import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../app_gate.dart';
import '../../services/server_manager.dart';
import '../../services/user_service.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';
import '../../services/pb_client.dart';
import 'about_screen.dart';
import 'aide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _url = TextEditingController(text: AppConfig.serverUrl);
  final _backup = BackupService();

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ═════ Aide + À propos ═════
        Row(
          children: [
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.help_outline,
                      color: Colors.blue, size: 32),
                  title: const Text('Aide',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Guide d\'utilisation'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AideScreen()),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: Colors.purple, size: 32),
                  title: const Text('À propos',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Version et développeur'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 32),

        // ═════ Mon compte ═════
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.teal, size: 32),
            title: const Text('Changer mon mot de passe',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Modifier le mot de passe de mon compte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePassword,
          ),
        ),
        const Divider(height: 32),

        // ═════ Ce poste ═════
        const Text('Ce poste',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (AppConfig.isHost) _hostCard() else _clientCard(),
        const Divider(height: 32),

        // ═════ Notifications ═════
        const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_active,
                    color: Colors.teal),
                title: const Text('Tester le rappel RDV du jour'),
                subtitle:
                    const Text('Affiche immédiatement une notification de test'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await NotificationService.afficherRappelRdvDuJour();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification envoyée')),
                    );
                  }
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.schedule, color: Colors.indigo),
                title: const Text('Programmer rappel quotidien (08:00)'),
                subtitle:
                    const Text('Notification automatique chaque matin'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await NotificationService.programmerRappelQuotidien(
                      hour: 8, minute: 0);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Rappel programmé à 08:00')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 32),

        // ═════ Sauvegarde ═════
        if (AppConfig.isHost) ..._backupSection(),
      ],
    );
  }

  // ───────────────────────── Poste principal ─────────────────────────
  Widget _hostCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.computer, color: Colors.teal),
              title: Text('Poste principal'),
              subtitle: Text(
                  'Les données du cabinet sont enregistrées sur cet ordinateur.'),
            ),
            const Text('Pour connecter un autre ordinateur ou une tablette, '
                'saisissez l\'une de ces adresses :'),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: ServerManager.instance.localAddresses(),
              builder: (_, snap) {
                final l = snap.data ?? const <String>[];
                if (l.isEmpty) {
                  return const Text('Aucune connexion réseau détectée.',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: [
                    for (final a in l)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link),
                        title: SelectableText(a,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        trailing: IconButton(
                          tooltip: 'Copier',
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: a));
                            _snack('Adresse copiée');
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Redémarrer la base de données'),
                onPressed: () async {
                  _snack('Redémarrage…');
                  try {
                    await ServerManager.instance.restart();
                    _snack('Base de données redémarrée');
                  } catch (e) {
                    _snack('Erreur : $e');
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Reconfigurer ce poste'),
                onPressed: _reconfigure,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Poste secondaire ─────────────────────────
  Widget _clientCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lan, color: Colors.teal),
              title: Text('Poste secondaire'),
              subtitle: Text('Connecté au poste principal du cabinet.'),
            ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                  labelText: 'Adresse du poste principal',
                  hintText: 'http://192.168.1.10:8190'),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 8, children: [
              ElevatedButton(
                onPressed: () async {
                  final u = _url.text.trim();
                  if (!await ServerManager.ping(u)) {
                    _snack('Aucun poste principal à cette adresse.');
                    return;
                  }
                  await AppConfig.setServerUrl(u);
                  PbClient.reset();
                  _snack('Adresse enregistrée. Reconnectez-vous.');
                  if (mounted) context.read<AuthProvider>().logout();
                },
                child: const Text('Tester et enregistrer'),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Reconfigurer ce poste'),
                onPressed: _reconfigure,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final old = TextEditingController();
    final nw = TextEditingController();
    final nw2 = TextEditingController();
    final key = GlobalKey<FormState>();
    String? err;
    bool busy = false;
    final userId = context.read<AuthProvider>().userId;
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
                    decoration:
                        const InputDecoration(labelText: 'Mot de passe actuel'),
                    validator: (v) => (v ?? '').isEmpty ? 'Requis' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: nw,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe (6 caractères min.)'),
                    validator: (v) =>
                        (v ?? '').length < 6 ? '6 caractères minimum' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: nw2,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirmer'),
                    validator: (v) =>
                        v != nw.text ? 'Les mots de passe diffèrent' : null),
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
                      setD(() {
                        busy = true;
                        err = null;
                      });
                      try {
                        await UserService()
                            .changeOwnPassword(userId, old.text, nw.text);
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        setD(() {
                          busy = false;
                          err = UserService.errorMessage(e);
                        });
                      }
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    // Les controllers ne sont volontairement pas libérés ici : l'animation de
    // fermeture du dialog les utilise encore (fuite négligeable).
    if (ok == true && mounted) {
      _snack('Mot de passe modifié. Reconnectez-vous.');
      context.read<AuthProvider>().logout();
    }
  }

  Future<void> _reconfigure() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reconfigurer ce poste ?'),
        content: const Text(
            'L\'assistant de configuration va se relancer. '
            'Aucune donnée n\'est supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continuer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    context.read<AuthProvider>().logout();
    if (AppConfig.isHost) await ServerManager.instance.stop();
    await AppConfig.setSetupDone(false);
    AppGate.reboot.value++;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ───────────────────────── Sauvegardes ─────────────────────────
  List<Widget> _backupSection() => [
        const Text('Sauvegarde de la base',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Une sauvegarde automatique est faite chaque jour à l\'ouverture '
            'de l\'application (30 conservées). Pensez à en copier une '
            'régulièrement sur une clé USB ou un disque externe.'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Sauvegarder maintenant'),
          onPressed: () async {
            final key = await _backup.createBackup();
            _snack(key != null ? 'Sauvegarde créée : $key' : 'Erreur');
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _backup.listBackups(),
          builder: (_, s) {
            if (!s.hasData) return const SizedBox.shrink();
            return Column(
              children: s.data!.map((b) {
                final key = b['key'].toString();
                final size = (b['size'] is num) ? (b['size'] as num) : 0;
                return ListTile(
                  leading: const Icon(Icons.archive),
                  title: Text(key),
                  subtitle:
                      Text('${(size / 1024 / 1024).toStringAsFixed(1)} Mo'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Copier vers une clé USB / un dossier',
                      icon: const Icon(Icons.drive_file_move_outline),
                      onPressed: () => _copy(key),
                    ),
                    TextButton(
                      onPressed: () => _restore(key),
                      child: const Text('Restaurer'),
                    ),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ];

  Future<void> _copy(String key) async {
    final dir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choisir le dossier de destination');
    if (dir == null) return;
    try {
      final dst = await _backup.copyTo(key, dir);
      _snack('Copié : $dst');
    } catch (e) {
      _snack('Erreur : $e');
    }
  }

  Future<void> _restore(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
            'Les données actuelles seront remplacées par celles de la '
            'sauvegarde. La base redémarrera.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Restaurer')),
        ],
      ),
    );
    if (ok != true) return;
    _snack('Restauration en cours…');
    try {
      final up = await _backup.restoreBackup(key);
      if (!mounted) return;
      _snack(up ? 'Restauration terminée. Reconnectez-vous.' : 'La base ne répond pas : relancez l\'application.');
      if (up) {
        context.read<AuthProvider>().logout();
        AppGate.reboot.value++;
      }
    } catch (e) {
      _snack('Erreur : $e');
    }
  }
}
