import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RoleGuard extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  const RoleGuard({super.key, required this.allowedRoles, required this.child});
  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    if (!allowedRoles.contains(role) && role != 'admin') {
      return const Center(child: Text('Accès non autorisé'));
    }
    return child;
  }
}