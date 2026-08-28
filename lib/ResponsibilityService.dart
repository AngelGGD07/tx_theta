import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'VerificationNotificationService.dart' show VerificationAction;

class DiscardedResponsibilityException implements Exception {
  const DiscardedResponsibilityException();
}

class ResponsibilityHasStartedException implements Exception {
  const ResponsibilityHasStartedException();
}

class ResponsibilityHasEvidenceException implements Exception {
  const ResponsibilityHasEvidenceException();
}

enum DiscardResponsibilityResult { discarded, alreadyDiscarded }

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

  DateTime _normalizeToMinute(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

  bool _sameMinuteTimestamp(dynamic timestamp, DateTime expected) {
    if (timestamp is! Timestamp) return false;
    return _normalizeToMinute(timestamp.toDate()) == expected;
  }

  bool _sameMinuteNullableTimestamp(dynamic timestamp, DateTime? expected) {
    if (expected == null) return timestamp == null;
    return timestamp is Timestamp &&
        _normalizeToMinute(timestamp.toDate()) == expected;
  }

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

  Stream<List<Responsibility>> watchActiveResponsibilities() {
    return _responsibilities
        .where('userId', isEqualTo: _uid)
        .where('status', whereIn: ['pending', 'started'])
        .orderBy('dueAt')
        .snapshots()
        .map((snap) => snap.docs
        .map((document) => Responsibility.fromFirestore(document))
        .toList());
  }

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

  Future<void> ensureResponsibilityActive(String responsibilityId) async {
    final snap = await _responsibilities.doc(responsibilityId).get();

    if (!snap.exists) {
      throw StateError('Responsabilidad no encontrada: $responsibilityId');
    }

    final data = snap.data()!;

    if (data['userId'] != _uid) {
      throw StateError(
          'La responsabilidad no pertenece al usuario autenticado.');
    }

    if (data['status'] == ResponsibilityStatus.discarded.name) {
      throw const DiscardedResponsibilityException();
    }
  }

  Future<void> markStarted({
    required String responsibilityId,
    required DateTime actualStartAt,
    required StartSource source,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final data = snap.data()!;

      if (data['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      if (data['status'] == ResponsibilityStatus.discarded.name) {
        throw const DiscardedResponsibilityException();
      }

      if (data['startedAt'] != null) {
        return;
      }

      transaction.update(docRef, {
        'startedAt': Timestamp.fromDate(actualStartAt),
        'startSource': source.name,
        'status': ResponsibilityStatus.started.name,
      });
      didWrite = true;
    });

    if (!didWrite) return;

    await _logStartRegistered(responsibilityId, source);
  }

  Future<bool> markStartedIfNotAlready({
    required String responsibilityId,
    required DateTime actualStartAt,
    required StartSource source,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final data = snap.data()!;

      if (data['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      if (data['status'] == ResponsibilityStatus.discarded.name) {
        throw const DiscardedResponsibilityException();
      }

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

    if (!didWrite) {
      return false;
    }

    await _logStartRegistered(responsibilityId, source);
    return true;
  }

  Future<void> undoStart(String responsibilityId) async {
    final docRef = _responsibilities.doc(responsibilityId);
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final data = snap.data()!;

      if (data['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      if (data['status'] == ResponsibilityStatus.discarded.name) {
        throw const DiscardedResponsibilityException();
      }

      if (data['status'] != ResponsibilityStatus.started.name) {
        return;
      }

      transaction.update(docRef, {
        'startedAt': null,
        'startSource': null,
        'status': ResponsibilityStatus.pending.name,
      });
      didWrite = true;
    });

    if (!didWrite) return;

    await _analytics.logEvent(
      AnalyticsEvents.startUndone,
      parameters: {AnalyticsParams.responsibilityId: responsibilityId},
    );
  }

  Future<void> _logStartRegistered(
      String responsibilityId, StartSource source) async {
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

  Future<void> updateResponsibilityDetails({
    required String responsibilityId,
    required ResponsibilityType type,
    String? subject,
    String? description,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    final snap = await docRef.get();

    if (!snap.exists) {
      throw StateError('Responsabilidad no encontrada: $responsibilityId');
    }

    final data = snap.data()!;
    if (data['userId'] != _uid) {
      throw StateError(
          'La responsabilidad no pertenece al usuario autenticado.');
    }

    String? normalizedSubject;
    if (subject != null && subject.trim().isNotEmpty) {
      normalizedSubject = subject.trim();
    }

    String? normalizedDescription;
    if (description != null && description.trim().isNotEmpty) {
      normalizedDescription = description.trim();
    }

    await docRef.update({
      'type': type.name,
      'subject': normalizedSubject,
      'description': normalizedDescription,
    });
  }

  Future<CorrectDatesResult> correctResponsibilityDates({
    required String responsibilityId,
    required DateTime newDueAt,
    required DateTime? newPredictedStartAt,
    required String correctionId,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    final eventRef =
    _predictionEvents.doc('prediction_correction_$correctionId');

    final nowMinute = _normalizeToMinute(DateTime.now());
    final newDueAtMin = _normalizeToMinute(newDueAt);
    final newPredictedStartAtMin = newPredictedStartAt != null
        ? _normalizeToMinute(newPredictedStartAt)
        : null;

    return _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final data = snap.data()!;
      if (data['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      final oldDueAtMin =
      _normalizeToMinute((data['dueAt'] as Timestamp).toDate());
      final oldPredictedStartAt = data['predictedStartAt'] != null
          ? _normalizeToMinute(
          (data['predictedStartAt'] as Timestamp).toDate())
          : null;
      final oldPredictionStatus =
          data['predictionStatus'] as String? ?? 'declared';

      final newPredictionStatus =
      newPredictedStartAtMin != null ? 'declared' : 'unknown';

      final dueAtChanged = oldDueAtMin != newDueAtMin;
      final predictionChanged = oldPredictedStartAt != newPredictedStartAtMin ||
          oldPredictionStatus != newPredictionStatus;

      final existingEvent = await transaction.get(eventRef);

      if (existingEvent.exists) {
        final e = existingEvent.data()!;

        final requestMatchesNewValues = e['userId'] == _uid &&
            e['responsibilityId'] == responsibilityId &&
            e['eventId'] == eventRef.id &&
            _sameMinuteTimestamp(e['newDueAt'], newDueAtMin) &&
            _sameMinuteNullableTimestamp(
                e['newPredictedStartAt'], newPredictedStartAtMin) &&
            e['newPredictionStatus'] == newPredictionStatus;

        if (!requestMatchesNewValues) {
          throw DateCorrectionConflictException();
        }

        final currentDueAt =
        _normalizeToMinute((data['dueAt'] as Timestamp).toDate());
        final currentPredictedStartAt = data['predictedStartAt'] != null
            ? _normalizeToMinute(
            (data['predictedStartAt'] as Timestamp).toDate())
            : null;
        final currentPredictionStatus =
            data['predictionStatus'] as String? ?? 'declared';

        final responsibilityMatchesEvent = _sameMinuteTimestamp(
          e['newDueAt'],
          currentDueAt,
        ) &&
            _sameMinuteNullableTimestamp(
              e['newPredictedStartAt'],
              currentPredictedStartAt,
            ) &&
            currentPredictionStatus == e['newPredictionStatus'];

        if (!responsibilityMatchesEvent) {
          throw DateCorrectionConflictException();
        }

        final previousDueAt = _normalizeToMinute(
          (e['previousDueAt'] as Timestamp).toDate(),
        );

        final wasDueAtChanged = !_sameMinuteTimestamp(
          e['newDueAt'],
          previousDueAt,
        );

        final previousPredictedStartAt =
        e['previousPredictedStartAt'] is Timestamp
            ? _normalizeToMinute(
          (e['previousPredictedStartAt'] as Timestamp).toDate(),
        )
            : null;

        final wasPredictionChanged = !_sameMinuteNullableTimestamp(
          e['newPredictedStartAt'],
          previousPredictedStartAt,
        ) ||
            e['newPredictionStatus'] != e['previousPredictionStatus'];

        return CorrectDatesResult(
          changed: true,
          dueAtChanged: wasDueAtChanged,
          predictionChanged: wasPredictionChanged,
          newPredictedStartAt: newPredictedStartAtMin,
          shouldCancelNotification: wasPredictionChanged,
          shouldScheduleNotification:
          wasPredictionChanged && newPredictedStartAtMin != null,
        );
      }

      if (!dueAtChanged && !predictionChanged) {
        return CorrectDatesResult.noChange();
      }

      if (dueAtChanged && !predictionChanged) {
        if (!newDueAtMin.isAfter(nowMinute)) {
          throw StateError('La entrega debe estar en el futuro.');
        }

        if (oldPredictedStartAt != null &&
            !newDueAtMin.isAfter(oldPredictedStartAt)) {
          throw StateError(
              'La entrega debe ser posterior al momento en que piensas empezar.');
        }

        transaction.update(docRef, {
          'dueAt': Timestamp.fromDate(newDueAtMin),
        });

        return CorrectDatesResult(
          changed: true,
          dueAtChanged: true,
          predictionChanged: false,
          newPredictedStartAt: oldPredictedStartAt,
          shouldCancelNotification: false,
          shouldScheduleNotification: false,
        );
      }

      if (data['status'] != ResponsibilityStatus.pending.name) {
        throw StateError(
            'Solo se pueden corregir fechas de responsabilidades pendientes.');
      }

      if (data['startedAt'] != null) {
        throw StateError(
            'No se pueden corregir fechas después de registrar el inicio.');
      }

      if (oldPredictedStartAt != null &&
          !oldPredictedStartAt.isAfter(nowMinute)) {
        throw StateError(
            'Esta predicción ya forma parte de tu evidencia y no puede reemplazarse.');
      }

      final notYetRef = _predictionEvents.doc('not_yet_$responsibilityId');
      final notYetSnap = await transaction.get(notYetRef);

      if (notYetSnap.exists) {
        throw StateError(
            'Ya registraste lo que ocurrió con esta predicción. No puede reemplazarse.');
      }

      if (newPredictedStartAtMin != null) {
        if (!newPredictedStartAtMin.isAfter(nowMinute)) {
          throw StateError('La predicción debe estar en el futuro.');
        }
        if (!newPredictedStartAtMin.isBefore(newDueAtMin)) {
          throw StateError('La predicción debe ser anterior a la entrega.');
        }
      }

      final event = PredictionEvent(
        userId: _uid,
        responsibilityId: responsibilityId,
        predictedAt: DateTime.now(),
        predictedStartAt: newPredictedStartAtMin,
        response: 'prediction_corrected',
        respondedAt: DateTime.now(),
        eventId: eventRef.id,
        previousDueAt: oldDueAtMin,
        newDueAt: newDueAtMin,
        previousPredictedStartAt: oldPredictedStartAt,
        newPredictedStartAt: newPredictedStartAtMin,
        previousPredictionStatus: oldPredictionStatus,
        newPredictionStatus: newPredictionStatus,
      );

      transaction.set(eventRef, event.toFirestore());

      final updateMap = <String, dynamic>{};
      if (dueAtChanged) {
        updateMap['dueAt'] = Timestamp.fromDate(newDueAtMin);
      }
      updateMap['predictedStartAt'] = newPredictedStartAtMin != null
          ? Timestamp.fromDate(newPredictedStartAtMin)
          : null;
      updateMap['predictionStatus'] = newPredictionStatus;

      transaction.update(docRef, updateMap);

      return CorrectDatesResult(
        changed: true,
        dueAtChanged: dueAtChanged,
        predictionChanged: true,
        newPredictedStartAt: newPredictedStartAtMin,
        shouldCancelNotification: true,
        shouldScheduleNotification: newPredictedStartAtMin != null,
      );
    });
  }

  Future<DiscardResponsibilityResult> discardResponsibility({
    required String responsibilityId,
  }) async {
    final docRef = _responsibilities.doc(responsibilityId);
    final notYetRef = _predictionEvents.doc('not_yet_$responsibilityId');

    return _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);

      if (!snap.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final data = snap.data()!;

      if (data['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      final status = data['status'];
      final startedAt = data['startedAt'];

      if (status == ResponsibilityStatus.discarded.name) {
        return DiscardResponsibilityResult.alreadyDiscarded;
      }

      if (status != ResponsibilityStatus.pending.name ||
          startedAt != null) {
        throw const ResponsibilityHasStartedException();
      }

      final notYetSnap = await transaction.get(notYetRef);

      if (notYetSnap.exists) {
        throw const ResponsibilityHasEvidenceException();
      }

      transaction.update(docRef, {
        'status': ResponsibilityStatus.discarded.name,
      });

      return DiscardResponsibilityResult.discarded;
    });
  }

  Future<void> recordNotYetResponse({
    required String responsibilityId,
  }) async {
    final responsibilityRef = _responsibilities.doc(responsibilityId);
    final eventRef = _predictionEvents.doc('not_yet_$responsibilityId');
    var didWrite = false;

    await _db.runTransaction((transaction) async {
      final responsibilitySnapshot =
      await transaction.get(responsibilityRef);

      if (!responsibilitySnapshot.exists) {
        throw StateError('Responsabilidad no encontrada: $responsibilityId');
      }

      final responsibilityData = responsibilitySnapshot.data()!;

      if (responsibilityData['userId'] != _uid) {
        throw StateError(
            'La responsabilidad no pertenece al usuario autenticado.');
      }

      if (responsibilityData['status'] ==
          ResponsibilityStatus.discarded.name) {
        throw const DiscardedResponsibilityException();
      }

      final existingEvent = await transaction.get(eventRef);
      if (existingEvent.exists) {
        didWrite = false;
        return;
      }

      final createdAt = responsibilityData['createdAt'];
      final predictedStartAt = responsibilityData['predictedStartAt'];

      if (createdAt is! Timestamp) {
        throw StateError(
            'La responsabilidad no contiene un createdAt válido.');
      }
      if (predictedStartAt is! Timestamp) {
        throw StateError(
            'No se puede registrar not_yet sin una predicción declarada.');
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

    if (!didWrite) return;

    await _analytics.logEvent(
      AnalyticsEvents.notificationResponsePersisted,
      parameters: {
        AnalyticsParams.responsibilityId: responsibilityId,
        AnalyticsParams.actionId: VerificationAction.notYet,
      },
    );
  }

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

class CorrectDatesResult {
  final bool changed;
  final bool dueAtChanged;
  final bool predictionChanged;
  final DateTime? newPredictedStartAt;
  final bool shouldCancelNotification;
  final bool shouldScheduleNotification;

  const CorrectDatesResult({
    required this.changed,
    required this.dueAtChanged,
    required this.predictionChanged,
    this.newPredictedStartAt,
    required this.shouldCancelNotification,
    required this.shouldScheduleNotification,
  });

  factory CorrectDatesResult.noChange() => const CorrectDatesResult(
    changed: false,
    dueAtChanged: false,
    predictionChanged: false,
    shouldCancelNotification: false,
    shouldScheduleNotification: false,
  );
}

class DateCorrectionConflictException implements Exception {}