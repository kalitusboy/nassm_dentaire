import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'patients/patient_list_screen.dart';
import 'rendez_vous/rendez_vous_list_screen.dart';
import 'rapports/recette_screen.dart';
import 'settings/settings_screen.dart';
import 'settings/parametrage_screen.dart';
import 'users/user_management_screen.dart';
import 'salle_attente/salle_attente_screen.dart';
import 'encaissements/encaissements_screen.dart';
import 'stock/stock_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isResp = auth.isReception || auth.isAdmin;
    final items = <_Nav>[
      _Nav(Icons.dashboard, 'Accueil', const DashboardScreen()),
      _Nav(Icons.people, 'Patients', const PatientListScreen()),
      _Nav(Icons.calendar_month, 'Rendez-vous', const RendezVousListScreen()),
      _Nav(Icons.chair, 'Salle d\'attente', const SalleAttenteScreen()),
      if (isResp) _Nav(Icons.notifications_active, 'Encaissements', const EncaissementsScreen()),
      if (isResp) _Nav(Icons.euro, 'Recettes', const RecetteScreen()),
      if (isResp) _Nav(Icons.inventory_2, 'Stock', const StockScreen()),
      _Nav(Icons.tune, 'Paramétrage', const ParametrageScreen()),
      if (auth.isAdmin)
        _Nav(Icons.manage_accounts, 'Utilisateurs', const UserManagementScreen()),
      _Nav(Icons.settings, 'Réglages', const SettingsScreen()),
    ];
    if (_i >= items.length) _i = 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _i,
            onDestinationSelected: (v) => setState(() => _i = v),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/logo.png', width: 36, height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_hospital, color: Colors.teal, size: 32))),
                  const SizedBox(height: 8),
                  SizedBox(width: 80,
                    child: Text(auth.fullName, style: const TextStyle(fontSize: 11),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center)),
                ],
              ),
            ),
            trailing: IconButton(icon: const Icon(Icons.logout),
              tooltip: 'Déconnexion', onPressed: () => auth.logout()),
            destinations: items.map((it) => NavigationRailDestination(
              icon: Icon(it.icon), label: Text(it.label))).toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: items[_i].screen),
        ],
      ),
    );
  }
}

class _Nav {
  final IconData icon;
  final String label;
  final Widget screen;
  _Nav(this.icon, this.label, this.screen);
}