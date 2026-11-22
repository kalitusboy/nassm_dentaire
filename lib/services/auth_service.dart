import 'package:pocketbase/pocketbase.dart';
import 'pb_client.dart';

class AuthService {
  PocketBase get _pb => PbClient.instance.pb;
  bool get isLoggedIn => _pb.authStore.isValid;
  RecordModel? get currentUser => _pb.authStore.model;
  String get role => currentUser?.getStringValue('role') ?? '';
  String get userId => currentUser?.id ?? '';
  String get fullName {
    final u = currentUser;
    return u == null ? '' : '${u.getStringValue('prenom')} ${u.getStringValue('nom')}'.trim();
  }
  Future<void> login(String email, String pass) =>
      _pb.collection('users').authWithPassword(email, pass);
  void logout() => _pb.authStore.clear();
}