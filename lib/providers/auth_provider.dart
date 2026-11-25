import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _s = AuthService();
  bool _loading = false;
  String? _error;

  bool get isLoggedIn => _s.isLoggedIn;
  String get role => _s.role;
  String get userId => _s.userId;
  String get fullName => _s.fullName;
  bool get isDentiste => _s.role == 'dentiste';
  bool get isReception => _s.role == 'reception';
  bool get isAdmin => _s.role == 'admin';
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> login(String e, String p) async {
    _loading = true; _error = null; notifyListeners();
    try {
      await _s.login(e, p);
      _loading = false; notifyListeners(); return true;
    } on ClientException catch (e) {
      _error = (e.statusCode == 400 || e.statusCode == 401 || e.statusCode == 403)
          ? 'Identifiant ou mot de passe incorrect'
          : e.statusCode == 0
              ? 'Serveur injoignable. Vérifiez le réseau et que le poste principal est allumé.'
              : 'Erreur du serveur (${e.statusCode})';
      _loading = false; notifyListeners(); return false;
    } catch (_) {
      _error = 'Erreur de connexion';
      _loading = false; notifyListeners(); return false;
    }
  }
  void logout() { _s.logout(); notifyListeners(); }
}