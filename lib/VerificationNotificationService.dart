import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'AnalyticsService.dart';

/// IDs de las acciones que aparecen en la notificación de verificación.
class VerificationAction {
  static const starting = 'start_now';
  static const alreadyStarted = 'already_started';
  static const notYet = 'not_yet';
}

typedef OnVerificationAction = void Function(
    String responsibilityId,
    String action,
    );

/// Genera un identificador entero positivo de 31 bits a partir de un
/// `responsibilityId` de Firestore.
///
/// No utiliza `String.hashCode` porque no está garantizado como estable entre
/// ejecuciones. Esta función sí es determinista para un mismo texto.
int notificationIdFor(String responsibilityId) {
  var hash = 0x811C9DC5;
  for (final codeUnit in responsibilityId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

class VerificationNotificationService {
  static final VerificationNotificationService _instance =
  VerificationNotificationService._internal();
  factory VerificationNotificationService() => _instance;
  VerificationNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  final AnalyticsService _analytics = AnalyticsService();

  OnVerificationAction? onAction;

  Future<void> init({required OnVerificationAction onAction}) async {
    this.onAction = onAction;
    tz_data.initializeTimeZones();
    final String deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimeZone));
    if (kDebugMode) {
      debugPrint('Zona horaria configurada: $deviceTimeZone');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      if (kDebugMode) {
        debugPrint('App lanzada por notificación (arranque en frío)');
      }
      _handleResponse(launchDetails.notificationResponse!);
    }

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final notifGranted = await androidPlugin.requestNotificationsPermission();
    if (kDebugMode) {
      debugPrint('Permiso de notificaciones concedido: $notifGranted');
    }

    final alarmGranted = await androidPlugin.requestExactAlarmsPermission();
    if (kDebugMode) {
      debugPrint('Permiso de alarma exacta concedido: $alarmGranted');
    }
  }

  Future<void> scheduleVerification({
    required String responsibilityId,
    required String subjectLabel,
    required DateTime predictedStartAt,
  }) async {
    if (predictedStartAt.isBefore(DateTime.now())) return;

    final notificationId = notificationIdFor(responsibilityId);

    final androidDetails = AndroidNotificationDetails(
      'verification_channel',
      'Verificación de predicción',
      channelDescription:
      'Pregunta si comenzaste una responsabilidad en el momento previsto',
      importance: Importance.high,
      priority: Priority.high,
      actions: const [
        AndroidNotificationAction(
          VerificationAction.starting,
          'Estoy empezando',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          VerificationAction.alreadyStarted,
          'Ya había empezado',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          VerificationAction.notYet,
          'Todavía no',
          showsUserInterface: true,
        ),
      ],
    );

    final scheduledTime = tz.TZDateTime.from(predictedStartAt, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    if (kDebugMode) {
      debugPrint('Hora actual (tz): $now');
      debugPrint('Hora programada (tz): $scheduledTime');
      debugPrint(
          'Diferencia: ${scheduledTime.difference(now).inSeconds} segundos');
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidPlugin?.canScheduleExactNotifications();
    if (kDebugMode) {
      debugPrint('¿Puede programar alarmas exactas?: $canExact');
    }

    await _plugin.zonedSchedule(
      notificationId,
      'Dijiste que empezarías ahora',
      '¿Qué ocurrió con "$subjectLabel"?',
      scheduledTime,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: responsibilityId,
    );

    await _analytics.logEvent(
      AnalyticsEvents.notificationScheduled,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
      },
    );

    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('Notificaciones pendientes: ${pending.length}');
      debugPrint('Programada => responsibilityId: $responsibilityId, '
          'notificationId: $notificationId');
      for (final p in pending) {
        debugPrint('Pendiente => id: ${p.id}, payload: ${p.payload}');
      }
    }
  }

  Future<void> cancelVerification(String responsibilityId) async {
    final notificationId = notificationIdFor(responsibilityId);
    await _plugin.cancel(notificationId);

    await _analytics.logEvent(
      AnalyticsEvents.notificationCancelled,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
      },
    );

    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('Cancelada => responsibilityId: $responsibilityId, '
          'notificationId: $notificationId');
      debugPrint('Notificaciones pendientes tras cancelar: ${pending.length}');
      for (final p in pending) {
        debugPrint('Pendiente => id: ${p.id}, payload: ${p.payload}');
      }
    }
  }

  void _handleResponse(NotificationResponse response) {
    final responsibilityId = response.payload;
    final actionId = response.actionId;

    if (responsibilityId == null || responsibilityId.isEmpty) {
      return;
    }

    if (actionId == null || actionId.isEmpty) {
      _analytics.logEvent(
        AnalyticsEvents.notificationOpened,
        parameters: {
          AnalyticsParams.responsibilityId: responsibilityId,
        },
      );
      return;
    }

    const supportedActions = {
      VerificationAction.starting,
      VerificationAction.alreadyStarted,
      VerificationAction.notYet,
    };

    if (!supportedActions.contains(actionId)) {
      if (kDebugMode) {
        debugPrint('Acción de notificación desconocida: $actionId');
      }
      return;
    }

    onAction?.call(responsibilityId, actionId);
  }
}

@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse response) {
  // Android ejecuta esta función en un isolate separado cuando la app
  // está cerrada. Para el MVP, la app se reabre mediante
  // showsUserInterface: true y _handleResponse procesa la acción.
}