import 'package:pocketbase/pocketbase.dart';
import '../config/app_config.dart';
import '../models/radiographie.dart';

class PbClient {
  static PbClient? _i;
  late final PocketBase pb;

  PbClient._() {
    pb = PocketBase(AppConfig.serverUrl);
    PbClientHolder.baseUrl = AppConfig.serverUrl;
  }

  static PbClient get instance => _i ??= PbClient._();
  static void reset() => _i = null;
}