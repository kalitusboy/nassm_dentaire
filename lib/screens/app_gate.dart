import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../services/admin_api.dart';
import '../services/backup_service.dart';
import '../services/db_bootstrap.dart';
import '../services/notification_service.dart';
import '../services/pb_client.dart';
import '../services/server_manager.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'setup/setup_screen.dart';

/// Porte d'entrée : première installation → assistant ; sinon démarre la base
/// de données (poste principal) ou vérifie la connexion (poste secondaire).
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  /// Incrémenter pour relancer le démarrage (ex. après reconfiguration).
  static final ValueNotifier<int> reboot = ValueNotifier<int>(0);

  @override
  State<AppGate> createState() => _AppGateState();
}

enum _Phase { starting, setup, error, ready }

class _AppGateState extends State<AppGate> {
  _Phase _phase = _Phase.starting;
  String _error = '';

  @override
  void initState() {
    super.initState();
    AppGate.reboot.addListener(_boot);
    _boot();
  }

  @override
  void dispose() {
    AppGate.reboot.removeListener(_boot);
    super.dispose();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() => _phase = _Phase.starting);

    if (!AppConfig.setupDone) {
      setState(() => _phase = _Phase.setup);
      return;
    }

    try {
      if (AppConfig.isHost) {
        final sm = ServerManager.instance;
        await sm.ensureRunning();
        try {
          await DbBootstrap(AdminApi()).ensureSchema();
        } on AdminApiException catch (e) {
          // Base restaurée d'un autre poste : le compte interne a changé.
          if (e.message.contains('Authentification interne')) {
            await sm.resetAdmin();
            await DbBootstrap(AdminApi()).ensureSchema();
          } else {
            rethrow;
          }
        }
        BackupService().autoDaily(); // en arrière-plan
      } else {
        if (!await ServerManager.ping(AppConfig.serverUrl)) {
          throw Exception(
              'Impossible de joindre le poste principal à l\'adresse :\n'
              '${AppConfig.serverUrl}\n\n'
              'Vérifiez que le poste principal est allumé, que l\'application '
              'y est ouverte et que les deux ordinateurs sont sur le même réseau.');
        }
      }
      PbClient.reset();
      PbClient.instance;
      if (mounted) setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _phase = _Phase.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.starting:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/logo.png', width: 64, height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_hospital, size: 64, color: Colors.teal))),
                SizedBox(height: 24),
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Démarrage de l\'application…'),
              ],
            ),
          ),
        );
      case _Phase.setup:
        return SetupScreen(onDone: _boot);
      case _Phase.error:
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.error_outline, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Démarrage impossible',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                            child: SelectableText(_error)),
                      ),
                      const SizedBox(height: 24),
                      Wrap(spacing: 12, children: [
                        ElevatedButton.icon(
                            onPressed: _boot,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer')),
                        OutlinedButton.icon(
                            onPressed: () async {
                              await AppConfig.setSetupDone(false);
                              _boot();
                            },
                            icon: const Icon(Icons.settings_backup_restore),
                            label: const Text('Reconfigurer ce poste')),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case _Phase.ready:
        return Consumer<AuthProvider>(
          builder: (_, auth, __) {
            if (auth.isLoggedIn) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationService.afficherRappelRdvDuJour();
              });
              return const MainShell();
            }
            return const LoginScreen();
          },
        );
    }
  }
}
