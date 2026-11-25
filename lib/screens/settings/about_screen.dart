import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_info.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ═════ En-tête de l'application ═════
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_hospital,
                    size: 60,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppInfo.appName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version ${AppInfo.appVersion} (build ${AppInfo.buildNumber})',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${AppInfo.releaseYear} — Tous droits réservés',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ═════ Informations du développeur (LECTURE SEULE) ═════
          Card(
            color: Theme.of(context).primaryColor.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.code,
                          color: Theme.of(context).primaryColor, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Développé par',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nom
                  Row(
                    children: [
                      Icon(Icons.person,
                          color: Theme.of(context).primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Développeur',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            SelectableText(
                              AppInfo.developerName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Email
                  _contactTile(
                    context,
                    icon: Icons.email,
                    label: 'Email',
                    value: AppInfo.developerEmail,
                    onTap: () => _launch(
                      context,
                      Uri(scheme: 'mailto', path: AppInfo.developerEmail),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Téléphone
                  _contactTile(
                    context,
                    icon: Icons.phone,
                    label: 'Téléphone',
                    value: AppInfo.developerPhone,
                    onTap: () => _launch(
                      context,
                      Uri(scheme: 'tel', path: AppInfo.developerPhone),
                    ),
                  ),

                  if (AppInfo.developerNote.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppInfo.developerNote,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ═════ Description ═════
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description,
                          color: Theme.of(context).primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Logiciel de gestion de cabinet dentaire conçu pour '
                    'fonctionner hors ligne sur un réseau local (Wi-Fi ou '
                    'Ethernet). Il permet la gestion complète des patients, '
                    'des actes médicaux, des rendez-vous, des ordonnances, '
                    'des radiographies, des paiements et des rapports '
                    'financiers.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ═════ Fonctionnalités ═════
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist,
                          color: Theme.of(context).primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Fonctionnalités',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _feature('Gestion des patients et dossiers médicaux'),
                  _feature('Actes dentaires (soins, extractions, prothèses…)'),
                  _feature('Odontogramme adulte et enfant (FDI 11–48 / 51–85)'),
                  _feature('Rendez-vous avec impression de la journée'),
                  _feature('Ordonnances et factures PDF (A4 / A5)'),
                  _feature('Radiographies et documents joints'),
                  _feature('Paiements et relevé de compte patient'),
                  _feature('Rapports journaliers et mensuels (CSV / Excel)'),
                  _feature('Sauvegarde automatique quotidienne'),
                  _feature('Mode réseau : Serveur (Hôte) ou Client'),
                  _feature('Fonctionnement 100 % hors ligne'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ═════ Technique ═════
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.computer,
                          color: Theme.of(context).primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Informations techniques',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _techRow('Plateforme', 'Flutter (Windows, Android, iOS)'),
                  _techRow('Backend', 'PocketBase (local)'),
                  _techRow('Base de données', 'SQLite (via PocketBase)'),
                  _techRow('Réseau', 'Wi-Fi / Ethernet (LAN)'),
                  _techRow('Mode', 'Hors ligne — sans internet'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ═════ Mentions légales ═════
          Center(
            child: Text(
              'Ce logiciel est destiné à un usage professionnel.\n'
              'Aucune donnée n\'est transmise sur internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _feature(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _techRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                '$label :',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}