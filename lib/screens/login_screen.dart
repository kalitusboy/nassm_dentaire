import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../config/app_info.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _e = TextEditingController(), _p = TextEditingController();
  @override
  void dispose() {
    _e.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 96),
                  const SizedBox(height: 8),
                  Text(AppInfo.appName,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(
                    AppConfig.isHost ? 'Poste principal' : 'Poste secondaire : ${AppConfig.serverUrl}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  TextField(controller: _e, decoration: const InputDecoration(
                    labelText: 'Identifiant', prefixIcon: Icon(Icons.person)),
                    onSubmitted: (_) => a.login(_e.text.trim(), _p.text)),
                  const SizedBox(height: 16),
                  TextField(controller: _p, obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock)),
                      onSubmitted: (_) => a.login(_e.text.trim(), _p.text)),
                  if (AppConfig.defaultPasswordActive) ...[
                    const SizedBox(height: 12),
                    Text('Première connexion : admin / admin123',
                        style: TextStyle(color: Colors.teal.shade700, fontSize: 12)),
                  ],
                  if (a.error != null) ...[
                    const SizedBox(height: 12),
                    Text(a.error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: a.loading ? null : () => a.login(_e.text.trim(), _p.text),
                      child: a.loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}