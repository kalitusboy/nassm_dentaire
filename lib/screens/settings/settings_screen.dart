import 'package:flutter/material.dart';
import '../../config/app_config.dart';
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

        // ═════ Mode de l'application ═════
        const Text('Mode de l\'application',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        RadioListTile<AppMode>(
          title: const Text('Serveur (Hôte) — ce poste héberge les données'),
          value: AppMode.host,
          groupValue: AppConfig.mode,
          onChanged: (v) async {
            await AppConfig.setMode(v!);
            PbClient.reset();
            setState(() {});
          },
        ),
        RadioListTile<AppMode>(
          title: const Text('Client — se connecte au serveur'),
          value: AppMode.client,
          groupValue: AppConfig.mode,
          onChanged: (v) async {
            await AppConfig.setMode(v!);
            PbClient.reset();
            setState(() {});
          },
        ),
        const Divider(height: 32),

        // ═════ Adresse du serveur ═════
        const Text('Adresse du serveur',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:8090',
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            await AppConfig.setServerUrl(_url.text.trim());
            PbClient.reset();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Adresse enregistrée. Reconnectez-vous.')),
              );
            }
          },
          child: const Text('Enregistrer l\'adresse'),
        ),
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
        const Text('Sauvegarde de la base',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
            'Sauvegarde automatique côté serveur chaque jour à 03h00. '
            'Vous pouvez aussi sauvegarder manuellement :'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Sauvegarder maintenant'),
          onPressed: () async {
            final key = await _backup.createBackup();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    key != null ? 'Sauvegarde créée : $key' : 'Erreur'),
              ));
            }
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder(
          future: _backup.listBackups(),
          builder: (_, s) {
            if (!s.hasData) return const SizedBox.shrink();
            return Column(
              children: s.data!.map((b) {
                return ListTile(
                  leading: const Icon(Icons.archive),
                  title: Text(b.key),
                  subtitle: Text(
                      '${(b.size / 1024 / 1024).toStringAsFixed(1)} Mo'),
                  trailing: TextButton(
                    onPressed: () => _restore(b.key),
                    child: const Text('Restaurer'),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Future<void> _restore(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
            'Le serveur redémarrera. Les données actuelles seront remplacées.'),
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
    if (ok == true) {
      await _backup.restoreBackup(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restauration en cours…')),
        );
      }
    }
  }
}