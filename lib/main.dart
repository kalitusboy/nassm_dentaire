import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/notification_service.dart';
import 'services/pb_client.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await AppConfig.load();
  PbClient.instance;
  await NotificationService.initialize();
  runApp(const DentalClinicApp());
}

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'Cabinet Dentaire',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Consumer<AuthProvider>(
          builder: (_, auth, __) {
            if (auth.isLoggedIn) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                NotificationService.afficherRappelRdvDuJour();
              });
              return const MainShell();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}