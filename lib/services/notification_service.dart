import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/rendez_vous.dart';
import 'rendez_vous_service.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _init = false;

  static Future<void> initialize() async {
    if (_init) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _init = true;
  }

  /// يظهر إشعاراً بمواعيد اليوم عند بدء التطبيق
  static Future<void> afficherRappelRdvDuJour() async {
    await initialize();
    final rdvs = await RendezVousService().listForDay(DateTime.now());
    if (rdvs.isEmpty) return;

    final h = DateTime.now().hour;
    String body;
    if (h < 12) {
      body = 'Vous avez ${rdvs.length} rendez-vous aujourd\'hui. '
          'Premier à ${_hhmm(rdvs.first.dateHeure)} — ${rdvs.first.patientNom}.';
    } else {
      final restants = rdvs.where((r) => r.dateHeure.isAfter(DateTime.now())).length;
      body = restants > 0
          ? 'Il reste $restants rendez-vous à venir aujourd\'hui.'
          : 'Tous les rendez-vous du jour sont passés (${rdvs.length} au total).';
    }

    await _plugin.show(
      100,
      'Rappel : rendez-vous du jour',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rdv_quotidien', 'Rendez-vous quotidiens',
          channelDescription: 'Rappel des rendez-vous du jour',
          importance: Importance.high, priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// يظهر تفاصيل كل موعد (متعددة)
  static Future<void> afficherDetailsRdv(List<RendezVous> rdvs) async {
    await initialize();
    for (var i = 0; i < rdvs.length; i++) {
      final r = rdvs[i];
      await _plugin.show(
        200 + i,
        '${_hhmm(r.dateHeure)} — ${r.patientNom}',
        '${r.motif} • Dr. ${r.medecinNom}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rdv_details', 'Détails rendez-vous',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  /// جدولة تذكير يومي في الساعة المحددة
  static Future<void> programmerRappelQuotidien({int hour = 8, int minute = 0}) async {
    await initialize();
    await _plugin.cancel(300);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      300,
      'Rappel : vos rendez-vous',
      'Consultez la liste des rendez-vous du jour.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rdv_planifie', 'Rappels programmés',
          channelDescription: 'Rappel automatique quotidien',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}