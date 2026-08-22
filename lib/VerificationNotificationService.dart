import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'AnalyticsService.dart';

/// IDs de las acciones que aparecen en la notificación de verificación.
/// Se usan tanto en la UI de la notificación como al procesar la respuesta.
class VerificationAction {
  static const starting = 'start_now';
  static const alreadyStarted = 'already_started';
  static const notYet = 'not_yet';
}

/// Callback que la app registra para reaccionar cuando el usuario toca
/// una acción de la notificación (incluso si la app estaba cerrada).
typedef OnVerificationAction = void Function(
    String responsibilityId,
    String action,
    );

/// Servicio mínimo: UNA sola notificación por responsabilidad, la de
/// verificación de predicción ("Dijiste que empezarías ahora. ¿Qué
/// ocurrió?"). No incluye recordatorios post-clase ni recuperación
/// 24h antes — eso queda prohibido para esta fase, según el plan.
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
    debugPrint('Zona horaria configurada: $deviceTimeZone');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      // Necesario para procesar el toque de una acción cuando la app
      // está completamente cerrada (no solo en background).
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      debugPrint('App lanzada por notificación (arranque en frío)');
      _handleResponse(launchDetails.notificationResponse!);
    }

    await _requestPermissions();
  }

  /// Pide POST_NOTIFICATIONS (Android 13+) y la alarma exacta (Android 12+).
  /// Analytics temporalmente eliminado para no contaminar métricas en cada init().
  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // 1. Permiso de notificaciones
    final notifGranted = await androidPlugin.requestNotificationsPermission();
    debugPrint('Permiso de notificaciones concedido: $notifGranted');

    // 2. Permiso de alarma exacta
    final alarmGranted = await androidPlugin.requestExactAlarmsPermission();
    debugPrint('Permiso de alarma exacta concedido: $alarmGranted');
  }

  /// Programa la notificación de verificación para el momento exacto
  /// declarado como predictedStartAt.
  Future<void> scheduleVerification({
    required String responsibilityId,
    required String subjectLabel,
    required DateTime predictedStartAt,
  }) async {
    // No programar si la fecha ya pasó.
    if (predictedStartAt.isBefore(DateTime.now())) return;

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
    debugPrint('Hora actual (tz): $now');
    debugPrint('Hora programada (tz): $scheduledTime');
    debugPrint(
        'Diferencia: ${scheduledTime.difference(now).inSeconds} segundos');

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await androidPlugin?.canScheduleExactNotifications();
    debugPrint('¿Puede programar alarmas exactas?: $canExact');

    await _plugin.zonedSchedule(
      responsibilityId.hashCode,
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

    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('Notificaciones pendientes: ${pending.length}');
  }

  Future<void> cancelVerification(String responsibilityId) async {
    await _plugin.cancel(responsibilityId.hashCode);
    await _analytics.logEvent(
      AnalyticsEvents.notificationCancelled,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
      },
    );
  }

  void _handleResponse(NotificationResponse response) {
    final id = response.payload;
    final action = response.actionId;
    if (id == null) return;

    // Si actionId viene vacío o nulo, significa que el usuario tocó el cuerpo
    // de la notificación. De lo contrario, tocó una acción específica.
    // Son mutuamente excluyentes desde el punto de vista analítico.
    if (action == null || action.isEmpty) {
      _analytics.logEvent(
        AnalyticsEvents.notificationOpened,
        parameters: {AnalyticsParams.responsibilityId: id},
      );
    } else {
      _analytics.logEvent(
        AnalyticsEvents.notificationActionSelected,
        parameters: {
          AnalyticsParams.responsibilityId: id,
          AnalyticsParams.actionId: action,
        },
      );
      onAction?.call(id, action);
    }
  }
}

/// Debe ser una función de nivel superior (top-level), no un método de
/// instancia: Android la ejecuta en un isolate separado cuando la app
/// está cerrada.
@pragma('vm:entry-point')
void _backgroundHandler(NotificationResponse response) {
  // Aquí NO hay acceso directo al estado de la app ni a Firebase
  // inicializado. Para el MVP, lo más simple y confiable es reabrir la
  // app con showsUserInterface: true (ya configurado arriba en cada
  // acción) y dejar que _handleResponse procese la acción una vez que
  // la app esté en primer plano.
}