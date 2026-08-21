import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// IDs internos de las acciones de la notificación.
///
/// Estos valores no deben traducirse ni cambiarse.
/// La aplicación los utiliza para identificar qué acción eligió el usuario.
class VerificationAction {
  static const String starting = 'start_now';
  static const String alreadyStarted = 'already_started';
  static const String notYet = 'not_yet';
}

/// Callback ejecutado cuando el usuario selecciona una acción.
///
/// Parámetros:
/// - responsibilityId: ID de la responsabilidad.
/// - action: ID interno de la acción seleccionada.
typedef OnVerificationAction = void Function(
    String responsibilityId,
    String action,
    );

/// Servicio responsable de las notificaciones locales de verificación.
///
/// Durante el MVP existe una única notificación por responsabilidad:
///
/// "Dijiste que empezarías ahora. ¿Qué pasó con [responsabilidad]?"
///
/// Acciones:
/// - Empezar ahora.
/// - Ya empecé.
/// - Aún no.
class VerificationNotificationService {
  VerificationNotificationService._internal();

  static final VerificationNotificationService _instance =
  VerificationNotificationService._internal();

  factory VerificationNotificationService() {
    return _instance;
  }

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  OnVerificationAction? onAction;

  bool _initialized = false;

  /// Inicializa el servicio de notificaciones.
  ///
  /// Debe llamarse una sola vez durante el inicio de la aplicación.
  Future<void> init({
    required OnVerificationAction onAction,
  }) async {
    this.onAction = onAction;

    if (_initialized) {
      debugPrint(
        '[NOTIFICATION] El servicio ya estaba inicializado.',
      );
      return;
    }

    await _configureLocalTimeZone();

    const androidInitializationSettings =
    AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse:
      verificationNotificationBackgroundHandler,
    );

    _initialized = true;

    debugPrint(
      '[NOTIFICATION] Plugin inicializado correctamente.',
    );

    await _requestPermissions();

    await printDiagnostic(
      reason: 'después de inicializar el servicio',
    );
  }

  /// Inicializa la base de datos de zonas horarias y configura
  /// la zona horaria local del dispositivo.
  Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();

    try {
      final String deviceTimeZone =
      await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(deviceTimeZone),
      );

      debugPrint(
        '[NOTIFICATION] Zona horaria configurada: '
            '$deviceTimeZone',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] No se pudo configurar '
            'la zona horaria local: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      debugPrint(
        '[NOTIFICATION] Zona horaria activa: ${tz.local.name}',
      );
    }
  }

  /// Solicita los permisos necesarios para mostrar y programar
  /// notificaciones en Android.
  Future<void> _requestPermissions() async {
    if (!Platform.isAndroid) {
      return;
    }

    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      debugPrint(
        '[NOTIFICATION] No se encontró '
            'la implementación Android.',
      );
      return;
    }

    try {
      final notificationsGranted =
      await androidPlugin.requestNotificationsPermission();

      debugPrint(
        '[NOTIFICATION] Permiso de notificaciones: '
            '$notificationsGranted',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] Error solicitando '
            'el permiso de notificaciones: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    try {
      final exactAlarmGranted =
      await androidPlugin.requestExactAlarmsPermission();

      debugPrint(
        '[NOTIFICATION] Permiso de alarma exacta: '
            '$exactAlarmGranted',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] Error solicitando '
            'el permiso de alarma exacta: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }
  }

  /// Programa una notificación de verificación para el momento
  /// predicho por el estudiante.
  ///
  /// Si ya existe una notificación para la responsabilidad,
  /// la cancela antes de registrar la nueva.
  Future<void> scheduleVerification({
    required String responsibilityId,
    required String subjectLabel,
    required DateTime predictedStartAt,
  }) async {
    if (!_initialized) {
      throw StateError(
        'VerificationNotificationService debe inicializarse '
            'antes de programar una notificación.',
      );
    }

    final String cleanResponsibilityId =
    responsibilityId.trim();

    final String cleanSubjectLabel =
    subjectLabel.trim();

    final DateTime now = DateTime.now();

    debugPrint('');
    debugPrint('========== SCHEDULE VERIFICATION ==========');
    debugPrint(
      'responsibilityId: $cleanResponsibilityId',
    );
    debugPrint(
      'subjectLabel: $cleanSubjectLabel',
    );
    debugPrint(
      'DateTime.now(): ${now.toIso8601String()}',
    );
    debugPrint(
      'predictedStartAt recibido: '
          '${predictedStartAt.toIso8601String()}',
    );
    debugPrint(
      'predictedStartAt.isUtc: ${predictedStartAt.isUtc}',
    );
    debugPrint(
      'tz.local.name: ${tz.local.name}',
    );

    if (cleanResponsibilityId.isEmpty) {
      debugPrint(
        '[NOTIFICATION] No se programó: '
            'responsibilityId está vacío.',
      );
      debugPrint('===========================================');
      return;
    }

    if (cleanSubjectLabel.isEmpty) {
      debugPrint(
        '[NOTIFICATION] No se programó: '
            'subjectLabel está vacío.',
      );
      debugPrint('===========================================');
      return;
    }

    if (!predictedStartAt.isAfter(now)) {
      debugPrint(
        '[NOTIFICATION] No se programó porque '
            'predictedStartAt no está en el futuro.',
      );

      debugPrint(
        'Diferencia: '
            '${predictedStartAt.difference(now).inSeconds} segundos',
      );

      debugPrint('===========================================');
      return;
    }

    final tz.TZDateTime scheduledDate =
    tz.TZDateTime.from(
      predictedStartAt,
      tz.local,
    );

    final int secondsUntilNotification = scheduledDate
        .difference(
      tz.TZDateTime.now(tz.local),
    )
        .inSeconds;

    debugPrint(
      'Fecha convertida a tz.local: '
          '${scheduledDate.toIso8601String()}',
    );

    debugPrint(
      'La notificación debería ejecutarse dentro de: '
          '$secondsUntilNotification segundos',
    );

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'verification_channel',
      'Verificación de predicción',
      channelDescription:
      'Pregunta si comenzaste una responsabilidad '
          'en el momento previsto',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          VerificationAction.starting,
          'Empezar ahora',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          VerificationAction.alreadyStarted,
          'Ya empecé',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          VerificationAction.notYet,
          'Aún no',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(
      android: androidDetails,
    );

    final int notificationId =
    _notificationIdFor(cleanResponsibilityId);

    try {
      // Debe existir una sola notificación por responsabilidad.
      await _plugin.cancel(notificationId);

      debugPrint(
        '[NOTIFICATION] Notificación anterior cancelada, '
            'si existía. ID: $notificationId',
      );

      await _plugin.zonedSchedule(
        notificationId,
        'Dijiste que empezarías ahora',
        '¿Qué pasó con $cleanSubjectLabel?',
        scheduledDate,
        notificationDetails,
        androidScheduleMode:
        AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: cleanResponsibilityId,
      );

      debugPrint(
        '[NOTIFICATION] zonedSchedule completó '
            'sin excepción.',
      );

      debugPrint(
        '[NOTIFICATION] notificationId: $notificationId',
      );

      await printDiagnostic(
        reason: 'después de scheduleVerification',
        predictedStartAt: predictedStartAt,
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] Error programando '
            'la notificación: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    } finally {
      debugPrint('===========================================');
      debugPrint('');
    }
  }

  /// Cancela la notificación asociada a una responsabilidad.
  Future<void> cancelVerification(
      String responsibilityId,
      ) async {
    final String cleanResponsibilityId =
    responsibilityId.trim();

    if (cleanResponsibilityId.isEmpty) {
      debugPrint(
        '[NOTIFICATION] No se canceló: '
            'responsibilityId está vacío.',
      );
      return;
    }

    final int notificationId =
    _notificationIdFor(cleanResponsibilityId);

    await _plugin.cancel(notificationId);

    debugPrint(
      '[NOTIFICATION] Notificación cancelada. '
          'responsibilityId=$cleanResponsibilityId, '
          'notificationId=$notificationId',
    );
  }

  /// Cancela todas las notificaciones.
  ///
  /// Solo debe utilizarse durante pruebas internas.
  /// No debe ejecutarse automáticamente cuando inicia la aplicación.
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();

    final List<PendingNotificationRequest> pending =
    await _plugin.pendingNotificationRequests();

    debugPrint(
      '[NOTIFICATION] Todas las notificaciones '
          'fueron canceladas.',
    );

    debugPrint(
      '[NOTIFICATION] Pendientes restantes: '
          '${pending.length}',
    );
  }

  /// Muestra una notificación inmediata de diagnóstico.
  ///
  /// Permite comprobar que el canal puede mostrar notificaciones
  /// sin depender de AlarmManager.
  Future<void> showImmediateDiagnosticNotification() async {
    if (!_initialized) {
      throw StateError(
        'VerificationNotificationService debe inicializarse '
            'antes de mostrar una notificación.',
      );
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'verification_channel',
      'Verificación de predicción',
      channelDescription:
      'Pregunta si comenzaste una responsabilidad '
          'en el momento previsto',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(
      android: androidDetails,
    );

    try {
      await _plugin.show(
        999999,
        'Prueba inmediata',
        'El canal de notificaciones está funcionando.',
        notificationDetails,
        payload: 'diagnostic_immediate',
      );

      debugPrint(
        '[NOTIFICATION] La notificación inmediata '
            'se solicitó correctamente.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] Falló la notificación '
            'inmediata: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  /// Imprime el estado actual del sistema de notificaciones.
  Future<void> printDiagnostic({
    String? reason,
    DateTime? predictedStartAt,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint(
        '[NOTIFICATION] Diagnóstico omitido: '
            'la plataforma no es Android.',
      );
      return;
    }

    final androidPlugin =
    _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final DateTime now = DateTime.now();

    final tz.TZDateTime tzNow =
    tz.TZDateTime.now(tz.local);

    final List<PendingNotificationRequest> pending =
    await _plugin.pendingNotificationRequests();

    bool? notificationsEnabled;
    bool? canScheduleExact;

    try {
      notificationsEnabled =
      await androidPlugin?.areNotificationsEnabled();
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] No se pudo consultar '
            'areNotificationsEnabled: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    try {
      canScheduleExact =
      await androidPlugin
          ?.canScheduleExactNotifications();
    } catch (error, stackTrace) {
      debugPrint(
        '[NOTIFICATION] No se pudo consultar '
            'canScheduleExactNotifications: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );
    }

    debugPrint('');
    debugPrint(
      '========== NOTIFICATION DIAGNOSTIC ==========',
    );

    debugPrint(
      'Motivo: ${reason ?? "sin especificar"}',
    );

    debugPrint(
      'DateTime.now(): ${now.toIso8601String()}',
    );

    debugPrint(
      'DateTime.now().isUtc: ${now.isUtc}',
    );

    debugPrint(
      'tz.local.name: ${tz.local.name}',
    );

    debugPrint(
      'TZDateTime.now(): ${tzNow.toIso8601String()}',
    );

    debugPrint(
      'Predicción recibida: '
          '${predictedStartAt?.toIso8601String() ?? "no proporcionada"}',
    );

    if (predictedStartAt != null) {
      final tz.TZDateTime scheduledDate =
      tz.TZDateTime.from(
        predictedStartAt,
        tz.local,
      );

      debugPrint(
        'Predicción convertida a tz.local: '
            '${scheduledDate.toIso8601String()}',
      );

      debugPrint(
        'Diferencia desde ahora: '
            '${scheduledDate.difference(tzNow).inSeconds} segundos',
      );
    }

    debugPrint(
      'Notificaciones habilitadas: '
          '${notificationsEnabled ?? "desconocido"}',
    );

    debugPrint(
      'Puede programar alarmas exactas: '
          '${canScheduleExact ?? "desconocido"}',
    );

    debugPrint(
      'Notificaciones pendientes: ${pending.length}',
    );

    for (var index = 0; index < pending.length; index++) {
      final PendingNotificationRequest notification =
      pending[index];

      debugPrint(
        'Pendiente[$index] '
            'id=${notification.id}, '
            'title="${notification.title}", '
            'body="${notification.body}", '
            'payload="${notification.payload}"',
      );
    }

    debugPrint(
      '=============================================',
    );
    debugPrint('');
  }

  /// Procesa el toque sobre una acción de la notificación.
  ///
  /// Este método debe permanecer dentro de la clase.
  void _handleResponse(
      NotificationResponse response,
      ) {
    final String? responsibilityId =
    response.payload?.trim();

    final String? actionId =
    response.actionId?.trim();

    debugPrint('');
    debugPrint(
      '========== NOTIFICATION RESPONSE ==========',
    );

    debugPrint(
      'notificationId: ${response.id}',
    );

    debugPrint(
      'payload: $responsibilityId',
    );

    debugPrint(
      'actionId: $actionId',
    );

    debugPrint(
      'responseType: '
          '${response.notificationResponseType}',
    );

    debugPrint(
      '===========================================',
    );
    debugPrint('');

    if (responsibilityId == null ||
        responsibilityId.isEmpty) {
      debugPrint(
        '[NOTIFICATION] Respuesta ignorada: '
            'el payload está vacío.',
      );
      return;
    }

    // Android puede entregar actionId vacío cuando se toca
    // el cuerpo de la notificación en lugar de una acción.
    if (actionId == null || actionId.isEmpty) {
      debugPrint(
        '[NOTIFICATION] Se tocó el cuerpo '
            'de la notificación.',
      );
      return;
    }

    final bool isKnownAction =
        actionId == VerificationAction.starting ||
            actionId == VerificationAction.alreadyStarted ||
            actionId == VerificationAction.notYet;

    if (!isKnownAction) {
      debugPrint(
        '[NOTIFICATION] Acción desconocida: $actionId',
      );
      return;
    }

    final OnVerificationAction? callback = onAction;

    if (callback == null) {
      debugPrint(
        '[NOTIFICATION] La acción no se procesó porque '
            'onAction no está configurado.',
      );
      return;
    }

    callback(
      responsibilityId,
      actionId,
    );
  }

  /// Genera el mismo ID al programar y cancelar una notificación.
  ///
  /// La máscara evita que el resultado sea negativo.
  int _notificationIdFor(
      String responsibilityId,
      ) {
    return responsibilityId.hashCode & 0x7fffffff;
  }
}

/// Callback ejecutado por Android cuando una acción llega
/// mediante un isolate de background.
///
/// Debe permanecer fuera de VerificationNotificationService.
@pragma('vm:entry-point')
void verificationNotificationBackgroundHandler(
    NotificationResponse response,
    ) {
  debugPrint('');
  debugPrint(
    '======= BACKGROUND NOTIFICATION RESPONSE =======',
  );

  debugPrint(
    'notificationId: ${response.id}',
  );

  debugPrint(
    'actionId: ${response.actionId}',
  );

  debugPrint(
    'payload: ${response.payload}',
  );

  debugPrint(
    '================================================',
  );
  debugPrint('');

  // No escribir en Firestore desde este callback.
  //
  // Android puede ejecutarlo en un isolate donde Firebase
  // todavía no está inicializado.
  //
  // Durante el MVP, las acciones utilizan:
  //
  // showsUserInterface: true
  //
  // para abrir la aplicación y procesar las operaciones críticas
  // con la interfaz visible.
}