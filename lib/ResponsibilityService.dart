import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Responsibility.dart';

/// Toda la lectura/escritura de responsabilidades y sus eventos.
/// Los eventos (prediction_events, notification_events) son de solo-append:
/// nunca se editan ni se borran, para conservar el historial completo.
class ResponsibilityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No hay usuario autenticado.');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _responsibilities =>
      _db.collection('responsibilities');

  CollectionReference<Map<String, dynamic>> get _predictionEvents =>
      _db.collection('prediction_events');

  CollectionReference<Map<String, dynamic>> get _notificationEvents =>
      _db.collection('notification_events');

  // ------------------------- CREAR -------------------------

  /// Crea una nueva responsabilidad. [predictedStartAt] puede ser null si
  /// el estudiante eligió "todavía no lo sé".
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
      predictionStatus: predictedStartAt != null ? 'declared' : 'unknown',
      status: ResponsibilityStatus.pending,
    ).toFirestore();

    final ref = await _responsibilities.add(data);
    final snap = await ref.get();
    return Responsibility.fromFirestore(snap);
  }

  // ------------------------- LEER -------------------------

  /// Stream de responsabilidades pendientes/iniciadas del usuario actual,
  /// ordenadas por fecha de entrega.
  Stream<List<Responsibility>> watchActiveResponsibilities() {
    return _responsibilities
        .where('userId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'started'])
        .orderBy('dueAt')
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => Responsibility.fromFirestore(d)).toList());
  }

  /// Todas las responsabilidades con inicio registrado, para calcular
  /// la confrontación individual. No agrega promedios todavía (eso queda
  /// prohibido para después del sprint de validación).
  Future<List<Responsibility>> getStartedResponsibilities() async {
    final snap = await _responsibilities
        .where('userId', isEqualTo: _uid)
        .where('startedAt', isNull: false)
        .orderBy('startedAt', descending: true)
        .get();
    return snap.docs.map((d) => Responsibility.fromFirestore(d)).toList();
  }

  // ------------------------- MARCAR INICIO -------------------------

  /// Registra el inicio real. [actualStartAt] es ahora para 'manual_live',
  /// o una fecha pasada elegida por el usuario para 'manual_recalled'.
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
  }

  /// Deshace un marcado de inicio (para el botón "Deshacer").
  Future<void> undoStart(String responsibilityId) async {
    await _responsibilities.doc(responsibilityId).update({
      'startedAt': null,
      'startSource': null,
      'status': ResponsibilityStatus.pending.name,
    });
  }

  /// Versión idempotente de markStarted. Si ya existe un inicio registrado,
  /// NO lo sobrescribe silenciosamente. Necesaria porque Android puede
  /// reenviar la acción de una notificación (reinicios, reintentos del
  /// sistema, doble toque por lag) — sin esto, cada reenvío generaría un
  /// segundo evento y contaminaría exactamente el dato que más importa.
  /// Usa una transacción para que la comprobación y la escritura sean
  /// atómicas (una lectura + escritura separadas dejarían una ventana de
  /// carrera entre el momento de leer y el de escribir).
  Future<void> markStartedIfNotAlready({
    required String responsibilityId,
    required DateTime actualStartAt,
    required StartSource source,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }
      final data = snap.data()!;
      if (data['startedAt'] != null) {
        // Ya hay un inicio registrado — no lo tocamos. Este es el caso
        // que evita la duplicación.
        return;
      }
      transaction.update(docRef, {
        'startedAt': Timestamp.fromDate(actualStartAt),
        'startSource': source.name,
        'status': ResponsibilityStatus.started.name,
      });
    });
  }

  // ------------------------- EVENTOS -------------------------

  /// Registra la respuesta a la notificación de verificación.
  /// response: 'started' | 'not_started' | 'postponed'
  Future<void> logPredictionEvent({
    required String responsibilityId,
    DateTime? newPredictedStartAt,
    required String response,
  }) async {
    final event = PredictionEvent(
      responsibilityId: responsibilityId,
      predictedAt: DateTime.now(),
      predictedStartAt: newPredictedStartAt,
      response: response,
      respondedAt: DateTime.now(),
    );
    await _predictionEvents.add(event.toFirestore());

    // Si el estudiante reprograma, actualizamos la predicción vigente en el
    // documento principal, pero el evento original queda conservado arriba.
    if (newPredictedStartAt != null) {
      await _responsibilities.doc(responsibilityId).update({
        'predictedStartAt': Timestamp.fromDate(newPredictedStartAt),
        'predictionStatus': 'declared',
      });
    }
  }

  Future<void> logNotificationEvent({
    required String responsibilityId,
    required String type, // scheduled | opened | action_selected
    String? actionSelected,
  }) async {
    final event = NotificationEvent(
      responsibilityId: responsibilityId,
      type: type,
      at: DateTime.now(),
      actionSelected: actionSelected,
    );
    await _notificationEvents.add(event.toFirestore());
  }
}