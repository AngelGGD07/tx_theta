import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'VerificationNotificationService.dart' show VerificationAction;

/// Toda la lectura/escritura de responsabilidades y sus eventos.
///
/// Los eventos de predicción y notificación son de solo append:
/// nunca se editan ni se borran para conservar el historial conductual.
class ResponsibilityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AnalyticsService _analytics = AnalyticsService();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('No hay usuario autenticado.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _responsibilities =>
      _db.collection('responsibilities');

  CollectionReference<Map<String, dynamic>> get _predictionEvents =>
      _db.collection('prediction_events');

  CollectionReference<Map<String, dynamic>> get _notificationEvents =>
      _db.collection('notification_events');

  // ------------------------- CREAR -------------------------

  /// Crea una nueva responsabilidad.
  ///
  /// [predictedStartAt] puede ser null si el estudiante eligió
  /// "Todavía no lo sé".
  Future<Responsibility> createResponsibility({
    required ResponsibilityType type,
    String? subject,
    String? description,
    required DateTime dueAt,
    DateTime? predictedStartAt,
  }) async {
    final now = DateTime.now();

    final data = Responsibility(
      id: '',
      userId: _uid,
      type: type,
      subject: subject,
      description: description,
      createdAt: now,
      dueAt: dueAt,
      predictedStartAt: predictedStartAt,
      predictionStatus:
      predictedStartAt != null ? 'declared' : 'unknown',
      status: ResponsibilityStatus.pending,
    ).toFirestore();

    final ref = await _responsibilities.add(data);
    final snap = await ref.get();

    return Responsibility.fromFirestore(snap);
  }

  // ------------------------- LEER -------------------------

  /// Stream de responsabilidades pendientes o iniciadas del usuario actual,
  /// ordenadas por fecha de entrega.
  Stream<List<Responsibility>> watchActiveResponsibilities() {
    return _responsibilities
        .where('userId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'started'])
        .orderBy('dueAt')
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((document) => Responsibility.fromFirestore(document))
          .toList(),
    );
  }

  /// Devuelve las responsabilidades que tienen un inicio registrado.
  ///
  /// No calcula promedios ni afirma patrones durante el MVP.
  Future<List<Responsibility>> getStartedResponsibilities() async {
    final snap = await _responsibilities
        .where('userId', isEqualTo: _uid)
        .where('startedAt', isNull: false)
        .orderBy('startedAt', descending: true)
        .get();

    return snap.docs
        .map((document) => Responsibility.fromFirestore(document))
        .toList();
  }

  // ------------------------- MARCAR INICIO -------------------------

  /// Registra el inicio real de una responsabilidad.
  ///
  /// [actualStartAt] representa el momento actual para manualLive o una
  /// fecha pasada recordada para manualRecalled o reminderRecalled.
  Future<void> markStarted({
    required String responsibilityId,
    required DateTime actualStartAt,
    required StartSource source,
  }) async {
    await _responsibilities.doc(responsibilityId).update({
      'startedAt': Timestamp.fromDate(actualStartAt),
      'startSource': source.name,
      'status': ResponsibilityStatus.started.name,
    });

    await _logStartRegistered(responsibilityId, source);
  }

  /// Deshace un inicio registrado accidentalmente.
  Future<void> undoStart(String responsibilityId) async {
    await _responsibilities.doc(responsibilityId).update({
      'startedAt': null,
      'startSource': null,
      'status': ResponsibilityStatus.pending.name,
    });

    await _analytics.logEvent(
      AnalyticsEvents.startUndone,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
      },
    );
  }

  /// Registra el inicio solamente si la responsabilidad todavía no tiene uno.
  ///
  /// La transacción evita que Android, un reinicio o un doble toque
  /// sobrescriban silenciosamente el inicio real.
  Future<void> markStartedIfNotAlready({
    required String responsibilityId,
    required DateTime actualStartAt,
    required StartSource source,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError(
          'Responsabilidad no encontrada: $responsibilityId',
        );
      }

      final data = snap.data()!;

      if (data['startedAt'] != null) {
        didWrite = false;
        return;
      }

      transaction.update(docRef, {
        'startedAt': Timestamp.fromDate(actualStartAt),
        'startSource': source.name,
        'status': ResponsibilityStatus.started.name,
      });
      didWrite = true;
    });

    // Solo se dispara analytics si esta llamada fue la que realmente
    // escribió. Si la transacción se reintenta por contención, el valor
    // final de didWrite refleja únicamente el resultado del último
    // intento — no se duplica el evento por reintentos internos.
    if (!didWrite) return;

    await _logStartRegistered(responsibilityId, source);
  }

  /// Registra start_registered siempre, y notification_response_persisted
  /// adicionalmente cuando el origen del inicio fue una notificación
  /// (reminderLive o reminderRecalled) — nunca para orígenes manuales.
  Future<void> _logStartRegistered(
      String responsibilityId,
      StartSource source,
      ) async {
    await _analytics.logEvent(
      AnalyticsEvents.startRegistered,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.startSource: source.name,
      },
    );

    final notificationActionId = switch (source) {
      StartSource.reminderLive => VerificationAction.starting,
      StartSource.reminderRecalled => VerificationAction.alreadyStarted,
      StartSource.manualLive || StartSource.manualRecalled => null,
    };

    if (notificationActionId == null) return;

    await _analytics.logEvent(
      AnalyticsEvents.notificationResponsePersisted,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.actionId: notificationActionId,
        AnalyticsParams.startSource: source.name,
      },
    );
  }

  // ------------------------- EVENTOS DE PREDICCIÓN -------------------------

  /// Registra una respuesta o una nueva predicción.
  ///
  /// Este método se mantiene para los flujos existentes. Si se proporciona
  /// [newPredictedStartAt], también actualiza la predicción vigente.
  Future<void> logPredictionEvent({
    required String responsibilityId,
    DateTime? newPredictedStartAt,
    required String response,
  }) async {
    final now = DateTime.now();

    final event = PredictionEvent(
      userId: _uid,
      responsibilityId: responsibilityId,
      predictedAt: now,
      predictedStartAt: newPredictedStartAt,
      response: response,
      respondedAt: now,
    );

    await _predictionEvents.add(event.toFirestore());

    if (newPredictedStartAt != null) {
      await _responsibilities.doc(responsibilityId).update({
        'predictedStartAt': Timestamp.fromDate(newPredictedStartAt),
        'predictionStatus': 'declared',
      });
    }
  }

  /// Registra que el estudiante respondió "Todavía no" a la notificación.
  ///
  /// No modifica la responsabilidad principal:
  /// - no establece startedAt;
  /// - no establece startSource;
  /// - no cambia status;
  /// - no borra predictedStartAt;
  /// - no crea una nueva predicción.
  ///
  /// El documento del evento utiliza un ID determinista para que el arranque
  /// en frío, un reinicio o una entrega repetida no creen eventos duplicados.
  Future<void> recordNotYetResponse({
    required String responsibilityId,
  }) async {
    final responsibilityRef = _responsibilities.doc(responsibilityId);
    final eventRef = _predictionEvents.doc(
      'not_yet_$responsibilityId',
    );
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final responsibilitySnapshot =
      await transaction.get(responsibilityRef);

      if (!responsibilitySnapshot.exists) {
        throw StateError(
          'Responsabilidad no encontrada: $responsibilityId',
        );
      }

      final responsibilityData = responsibilitySnapshot.data()!;

      if (responsibilityData['userId'] != _uid) {
        throw StateError(
          'La responsabilidad no pertenece al usuario autenticado.',
        );
      }

      final existingEvent = await transaction.get(eventRef);

      if (existingEvent.exists) {
        didWrite = false;
        return;
      }

      final createdAt = responsibilityData['createdAt'];
      final predictedStartAt =
      responsibilityData['predictedStartAt'];

      if (createdAt is! Timestamp) {
        throw StateError(
          'La responsabilidad no contiene un createdAt válido.',
        );
      }

      if (predictedStartAt is! Timestamp) {
        throw StateError(
          'No se puede registrar not_yet sin una predicción declarada.',
        );
      }

      transaction.set(eventRef, {
        'eventId': eventRef.id,
        'userId': _uid,
        'responsibilityId': responsibilityId,
        'predictedAt': createdAt,
        'predictedStartAt': predictedStartAt,
        'response': 'not_started',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      didWrite = true;
    });

    // El guard de idempotencia (existingEvent.exists) es justo lo que evita
    // que un reintento o una entrega repetida de la notificación dupliquen
    // este evento en Analytics.
    if (!didWrite) return;

    await _analytics.logEvent(
      AnalyticsEvents.notificationResponsePersisted,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.actionId: VerificationAction.notYet,
      },
    );
  }

  // ------------------------- EVENTOS DE NOTIFICACIÓN -------------------------

  Future<void> logNotificationEvent({
    required String responsibilityId,
    required String type,
    String? actionSelected,
  }) async {
    final event = NotificationEvent(
      userId: _uid,
      responsibilityId: responsibilityId,
      type: type,
      at: DateTime.now(),
      actionSelected: actionSelected,
    );

    await _notificationEvents.add(event.toFirestore());
  }
}