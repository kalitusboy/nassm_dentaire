import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _e = TextEditingController(), _p = TextEditingController();
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
                  const Icon(Icons.local_hospital, size: 64, color: Colors.teal),
                  const SizedBox(height: 8),
                  const Text('Cabinet Dentaire',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(
                    AppConfig.isHost ? 'Mode : Serveur (Hôte)' : 'Client : ${AppConfig.serverUrl}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 24),
                  TextField(controller: _e, decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 16),
                  TextField(controller: _p, obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe', prefixIcon: Icon(Icons.lock))),
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