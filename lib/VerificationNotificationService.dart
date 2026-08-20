import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// IDs de las acciones que aparecen en la notificación de verificación.
/// Se usan tanto en la UI de la notificación como al procesar la respuesta.
class VerificationAction {
  static const starting = 'starting'; // "Estoy empezando"
  static const alreadyStarted = 'already_started'; // "Ya había empezado"
  static const notYet = 'not_yet'; // "Todavía no"
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

  OnVerificationAction? onAction;

  Future<void> init({required OnVerificationAction onAction}) async {
    this.onAction = onAction;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName == 'UTC'
        ? 'UTC'
        : tz.local.name));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      // Necesario para procesar el toque de una acción cuando la app
      // está completamente cerrada (no solo en background).
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    await _requestPermissions();
  }

  /// Pide POST_NOTIFICATIONS (Android 13+) y la alarma exacta (Android 12+).
  /// Sin esto, la notificación puede no dispararse en el momento exacto,
  /// y eso contaminaría la métrica de "tasa de respuesta" del sprint.
  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) return;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
  }

  /// Programa la notificación de verificación para el momento exacto
  /// declarado como predictedStartAt.
  Future<void> scheduleVerification({
    required String responsibilityId,
    required String subjectLabel, // ej. "Laboratorio de Física"
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

    await _plugin.zonedSchedule(
      responsibilityId.hashCode, // ID único por responsabilidad.
      'Dijiste que empezarías ahora',
      '¿Qué ocurrió con "$subjectLabel"?',
      tz.TZDateTime.from(predictedStartAt, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: responsibilityId,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelVerification(String responsibilityId) async {
    await _plugin.cancel(responsibilityId.hashCode);
  }

  void _handleResponse(NotificationResponse response) {
    final id = response.payload;
    final action = response.actionId;
    if (id == null || action == null) return;
    onAction?.call(id, action);
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
  // la app esté en primer plano, en lugar de intentar escribir a
  // Firestore directamente desde este isolate.
}