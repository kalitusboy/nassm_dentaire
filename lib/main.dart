import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'config/app_config.dart';
import 'config/app_info.dart';
import 'providers/auth_provider.dart';
import 'screens/app_gate.dart';
import 'services/notification_service.dart';
import 'services/server_manager.dart';
import 'theme/app_theme.dart';

class _CloseHandler with WindowListener {
  @override
  void onWindowClose() async {
    // Arrête proprement la base de données embarquée avant de quitter.
    if (AppConfig.isHost) await ServerManager.instance.stop();
    await windowManager.destroy();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await AppConfig.load();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setTitle(AppInfo.appName);
    windowManager.addListener(_CloseHandler());
  }

  try {
    await NotificationService.initialize();
  } catch (_) {
    // notifications non disponibles sur cette plateforme : sans gravité
  }
  runApp(const DentalClinicApp());
}

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: AppInfo.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppGate(),
      ),
    );
  }
}
