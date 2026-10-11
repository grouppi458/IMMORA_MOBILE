import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'package:immora_mobile/core/utils/constants.dart';
import 'package:immora_mobile/core/utils/formatters.dart';
import 'package:immora_mobile/module_gestion_annonces/models/visit_details.dart';

/// Rappels locaux des visites : une notification « 24 h avant » programmée
/// sur l'appareil (flutter_local_notifications + zonedSchedule).
///
/// Silencieux sur le web et tant que [init] n'a pas abouti : les tests et les
/// clés de démonstration web ne déclenchent jamais de notification.
class VisitReminderService {
  VisitReminderService._();

  static final VisitReminderService instance = VisitReminderService._();

  static const _channelId = 'visits';

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Rappels de visite',
      channelDescription: 'Rappel envoyé 24 h avant chaque visite',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Initialise le plugin, le fuseau horaire local et demande l'autorisation
  /// (Android 13+ / iOS). Appelé une fois depuis `main()`.
  Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      timezone_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        timezone.setLocalLocation(timezone.getLocation(info.identifier));
      } catch (e) {
        // Fuseau introuvable : on garde celui par défaut (UTC).
        debugPrint('VisitReminderService: fuseau local indisponible ($e)');
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);

      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'Rappels de visite',
        description: 'Rappel envoyé 24 h avant chaque visite',
        importance: Importance.high,
      ));
      // Android 13+ : POST_NOTIFICATIONS ; sans réponse, on reste silencieux.
      await android?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);

      _ready = true;
    } catch (e) {
      debugPrint('VisitReminderService.init: $e');
    }
  }

  /// Programme (ou reprogramme) le rappel de la visite à [visitReminderHours]
  /// heures avant son créneau. Rien à programmer si le créneau est trop
  /// proche : on nettoie alors une éventuelle programmation précédente.
  Future<void> schedule(VisitDetails details) async {
    final id = details.visit.id;
    if (!_ready || id == null) return;
    final at = DateTime.fromMillisecondsSinceEpoch(details.visit.scheduledAt)
        .subtract(const Duration(hours: visitReminderHours));
    if (!at.isAfter(DateTime.now())) {
      await cancel(id);
      return;
    }
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: 'Rappel de visite',
        body: '${details.shortTitle} · demain à ${formatTime(details.visit.scheduledAt)}',
        scheduledDate: timezone.TZDateTime.from(at, timezone.local),
        notificationDetails: _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('VisitReminderService.schedule: $e');
    }
  }

  /// Retire le rappel de la visite [visitId] (annulée, effectuée, absente).
  Future<void> cancel(int visitId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: visitId);
    } catch (e) {
      debugPrint('VisitReminderService.cancel: $e');
    }
  }
}
