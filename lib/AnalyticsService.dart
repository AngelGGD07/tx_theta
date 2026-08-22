import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Nombres de eventos de Firebase Analytics para el sprint de validación
/// de 14 días. Única fuente de verdad — ningún otro archivo debe escribir
/// un nombre de evento como string literal.
class AnalyticsEvents {
  AnalyticsEvents._();

  static const responsibilityCreated = 'responsibility_created';
  static const predictionCreated = 'prediction_created';
  static const notificationPermissionRequested =
      'notification_permission_requested';
  static const notificationPermissionGranted =
      'notification_permission_granted';
  static const notificationPermissionDenied =
      'notification_permission_denied';
  static const notificationScheduled = 'notification_scheduled';
  static const notificationCancelled = 'notification_cancelled';
  static const notificationOpened = 'notification_opened';
  static const notificationActionReceived = 'notification_action_received';
  static const notificationActionSelected = 'notification_action_selected';
  static const notificationResponsePersisted =
      'notification_response_persisted';
  static const startRegistered = 'start_registered';
  static const confrontationShown = 'confrontation_shown';
  static const startUndone = 'start_undone';
}

/// Nombres de parámetros. Única fuente de verdad — evita typos que
/// fragmenten sin querer una misma dimensión dentro de Firebase Analytics.
class AnalyticsParams {
  AnalyticsParams._();

  static const responsibilityId = 'responsibility_id';
  static const actionId = 'action_id';
  static const predictionStatus = 'prediction_status';
  static const startSource = 'start_source';
  static const responsibilityType = 'responsibility_type';
  static const hasPrediction = 'has_prediction';
  static const permissionType = 'permission_type';
}

/// Wrapper delgado sobre FirebaseAnalytics. Ningún otro archivo debe llamar
/// a FirebaseAnalytics.instance directamente — así, si alguna vez hace
/// falta un filtro global (por ejemplo, no enviar eventos en modo debug,
/// o migrar de proveedor), se cambia en un solo lugar.
///
/// No envía aquí, ni en ningún punto de la app, texto académico libre,
/// correo electrónico, nombre del estudiante ni fechas completas.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Asocia los eventos siguientes con el usuario autenticado.
  /// Seguro de llamar repetidamente — es una propiedad, no un evento.
  /// Pasa null al cerrar sesión para desasociar al usuario.
  Future<void> setUser(String? uid) async {
    try {
      await _analytics.setUserId(id: uid);
    } catch (e) {
      debugPrint('Analytics error (setUser): $e');
    }
  }

  /// Registra un evento, limpiando valores null — Analytics no los acepta
  /// como parámetro.
  ///
  /// Trade-off MVP: Conservamos el 'await'. Esto significa que la operación
  /// no es un "fire-and-forget" puro, ya que el hilo de ejecución espera
  /// a que Firebase Analytics procese la llamada local.
  /// Sin embargo, el try-catch interno garantiza que si Analytics lanza
  /// una excepción, esta es capturada y no rompe el flujo principal (ej. una
  /// escritura exitosa en Firestore).
  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    try {
      Map<String, Object>? cleanParams;
      if (parameters != null) {
        cleanParams = {};
        for (final entry in parameters.entries) {
          final value = entry.value;
          if (value != null) {
            cleanParams[entry.key] = value;
          }
        }
      }
      await _analytics.logEvent(name: name, parameters: cleanParams);
    } catch (e) {
      debugPrint('Analytics error (logEvent $name): $e');
    }
  }
}