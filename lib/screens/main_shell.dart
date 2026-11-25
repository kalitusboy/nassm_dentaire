import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../config/app_info.dart';
import '../providers/auth_provider.dart';
import '../services/file_attente_service.dart';
import '../services/stock_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/change_password_dialog.dart';
import 'attente/file_attente_screen.dart';
import 'dashboard_screen.dart';
import 'patients/patient_list_screen.dart';
import 'rapports/recette_screen.dart';
import 'rendez_vous/rendez_vous_list_screen.dart';
import 'settings/parametrage_screen.dart';
import 'settings/settings_screen.dart';
import 'statistiques/statistiques_screen.dart';
import 'stock/stock_screen.dart';
import 'users/user_management_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _NavItem {
  final String id;
  final IconData icon;
  final String label;
  final Widget Function() build;
  _NavItem(this.id, this.icon, this.label, this.build);
}

class _MainShellState extends State<MainShell> {
  String _current = 'accueil';
  Timer? _timer;
  int _tick = 0;
  bool _firstPoll = true;
  final Set<String> _seen = {};
  int _badgeAttente = 0, _badgeStock = 0;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go(String id) => setState(() => _current = id);

  void _notify(String message) {
    if (!mounted) return;
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: 'Ouvrir', onPressed: () => _go('attente')),
    ));
  }

  /// Interroge la salle d'attente : badges + alertes pour la réception / le médecin.
  Future<void> _poll() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    final isDoc = auth.isDentiste || auth.isAdmin;
    final isRec = auth.isReception || auth.isAdmin;
    try {
      final list = await FileAttenteService().listActiveToday();
      var badge = 0;
      for (final f in list) {
        if (isRec && f.statut == 'a_encaisser') {
          badge++;
          if (_seen.add('enc:${f.id}') && !_firstPoll) {
            _notify('💰 ${f.patientNom} : consultation terminée — à encaisser');
          }
        }
        if (isRec && f.appelReception) {
          badge++;
          if (_seen.add('appel:${f.id}') && !_firstPoll) {
            _notify('🔔 ${f.medecinNom.isEmpty ? 'Le médecin' : 'Dr. ${f.medecinNom}'} '
                'demande la réception (${f.patientNom})');
          }
        }
        if (isDoc && f.statut == 'attente') {
          badge++;
          if (_seen.add('att:${f.id}') && !_firstPoll) {
            _notify('🧍 Nouveau patient en salle d\'attente : ${f.patientNom}');
          }
        }
      }
      _firstPoll = false;
      if (mounted) setState(() => _badgeAttente = badge);
    } catch (_) {}
    if (_tick++ % 8 == 0) {
      try {
        final n = await StockService().countAlertes();
        if (mounted) setState(() => _badgeStock = n);
      } catch (_) {}
    }
  }

  List<_NavItem> _items(AuthProvider auth) {
    final isResp = auth.isReception || auth.isAdmin;
    return [
      _NavItem('accueil', Icons.dashboard, 'Accueil', () => DashboardScreen(onOpen: _go)),
      _NavItem('attente', Icons.groups, 'Salle d\'attente', () => const FileAttenteScreen()),
      _NavItem('patients', Icons.people, 'Patients', () => const PatientListScreen()),
      _NavItem('rdv', Icons.calendar_month, 'Rendez-vous', () => const RendezVousListScreen()),
      if (isResp) _NavItem('recettes', Icons.payments, 'Recettes', () => const RecetteScreen()),
      if (auth.isAdmin || auth.isDentiste)
        _NavItem('stats', Icons.bar_chart, 'Statistiques', () => const StatistiquesScreen()),
      _NavItem('stock', Icons.inventory_2, 'Stock', () => const StockScreen()),
      _NavItem('param', Icons.tune, 'Paramétrage', () => const ParametrageScreen()),
      if (auth.isAdmin)
        _NavItem('users', Icons.manage_accounts, 'Utilisateurs', () => const UserManagementScreen()),
      _NavItem('reglages', Icons.settings, 'Réglages', () => const SettingsScreen()),
    ];
  }

  int _badgeFor(String id) =>
      id == 'attente' ? _badgeAttente : id == 'stock' ? _badgeStock : 0;

  Widget _sidebar(List<_NavItem> items, AuthProvider auth, {bool inDrawer = false}) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const ClinicLogo(size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppInfo.appName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(auth.fullName.isEmpty ? auth.username : auth.fullName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ]),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final it in items)
                  _tile(it, selected: it.id == _current, inDrawer: inDrawer),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () => auth.logout(),
          ),
        ]),
      ),
    );
  }

  Widget _tile(_NavItem it, {required bool selected, required bool inDrawer}) {
    final b = _badgeFor(it.id);
    final color = selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade800;
    return Material(
      color: selected ? Colors.teal.withOpacity(0.10) : Colors.transparent,
      child: InkWell(
        onTap: () {
          _go(it.id);
          if (inDrawer) Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            Icon(it.icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(it.label,
                  style: TextStyle(
                      color: color, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ),
            if (b > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: it.id == 'stock' ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(10)),
                child: Text('$b',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _defaultPasswordBanner(AuthProvider auth) {
    if (!AppConfig.defaultPasswordActive ||
        !auth.isAdmin ||
        auth.username != AppConfig.defaultAdminUser) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: Colors.deepOrange),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Le mot de passe par défaut (admin123) est encore utilisé. '
              'Changez-le pour protéger les données du cabinet.'),
        ),
        TextButton(
          onPressed: () => showChangePasswordDialog(context),
          child: const Text('Changer maintenant'),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final items = _items(auth);
    final item = items.firstWhere((i) => i.id == _current, orElse: () => items.first);
    final body = Column(children: [
      _defaultPasswordBanner(auth),
      Expanded(child: KeyedSubtree(key: ValueKey(item.id), child: item.build())),
    ]);

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 800) {
        return Scaffold(
          body: Row(children: [
            SizedBox(width: 230, child: _sidebar(items, auth)),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ]),
        );
      }
      // Téléphone / petite fenêtre : menu en tiroir
      return Scaffold(
        appBar: AppBar(
          title: Text(item.label),
          actions: [
            if (_badgeAttente > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: GestureDetector(
                    onTap: () => _go('attente'),
                    child: Badge(label: Text('$_badgeAttente'), child: const Icon(Icons.groups)),
                  ),
                ),
              ),
          ],
        ),
        drawer: Drawer(child: _sidebar(items, auth, inDrawer: true)),
        body: body,
      );
    });
  }
}
