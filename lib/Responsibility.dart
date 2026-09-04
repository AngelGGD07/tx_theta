import 'package:cloud_firestore/cloud_firestore.dart';

/// Fuente del dato de inicio: distingue calidad de la señal.
enum StartSource {
  manualLive,
  manualRecalled,
  reminderLive,
  reminderRecalled,
}

enum ResponsibilityStatus { pending, started, completed, submitted, discarded }

enum ResponsibilityType { exam, lab, project, homework, presentation }

class Responsibility {
  final String id;
  final String userId;
  final ResponsibilityType type;
  final String? subject;
  final String? description;

  final DateTime createdAt;
  final DateTime dueAt;

  final DateTime? predictedStartAt;
  final String predictionStatus;

  DateTime? startedAt;
  StartSource? startSource;

  DateTime? completedAt;
  DateTime? submittedAt;

  ResponsibilityStatus status;

  Responsibility({
    required this.id,
    required this.userId,
    required this.type,
    this.subject,
    this.description,
    required this.createdAt,
    required this.dueAt,
    this.predictedStartAt,
    this.predictionStatus = 'declared',
    this.startedAt,
    this.startSource,
    this.completedAt,
    this.submittedAt,
    this.status = ResponsibilityStatus.pending,
  });

  double? get startDeviationHours {
    if (predictedStartAt == null || startedAt == null) return null;
    return startedAt!.difference(predictedStartAt!).inMinutes / 60.0;
  }

  bool get isHighQualityStart =>
      startSource == StartSource.manualLive ||
          startSource == StartSource.reminderLive;

  factory Responsibility.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Responsibility(
      id: doc.id,
      userId: d['userId'],
      type: ResponsibilityType.values.byName(d['type']),
      subject: d['subject'],
      description: d['description'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      dueAt: (d['dueAt'] as Timestamp).toDate(),
      predictedStartAt: d['predictedStartAt'] != null
          ? (d['predictedStartAt'] as Timestamp).toDate()
          : null,
      predictionStatus: d['predictionStatus'] ?? 'declared',
      startedAt: d['startedAt'] != null
          ? (d['startedAt'] as Timestamp).toDate()
          : null,
      startSource: d['startSource'] != null
          ? StartSource.values.byName(d['startSource'])
          : null,
      completedAt: d['completedAt'] != null
          ? (d['completedAt'] as Timestamp).toDate()
          : null,
      submittedAt: d['submittedAt'] != null
          ? (d['submittedAt'] as Timestamp).toDate()
          : null,
      status: ResponsibilityStatus.values.byName(d['status']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'subject': subject,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueAt': Timestamp.fromDate(dueAt),
      'predictedStartAt': predictedStartAt != null
          ? Timestamp.fromDate(predictedStartAt!)
          : null,
      'predictionStatus': predictionStatus,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'startSource': startSource?.name,
      'completedAt':
      completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'submittedAt':
      submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'status': status.name,
    };
  }
}

class PredictionEvent {
  final String userId;
  final String responsibilityId;
  final DateTime predictedAt;
  final DateTime? predictedStartAt;
  final String response;
  final DateTime respondedAt;

  final String? eventId;
  final DateTime? previousDueAt;
  final DateTime? newDueAt;
  final DateTime? previousPredictedStartAt;
  final DateTime? newPredictedStartAt;
  final String? previousPredictionStatus;
  final String? newPredictionStatus;

  PredictionEvent({
    required this.userId,
    required this.responsibilityId,
    required this.predictedAt,
    this.predictedStartAt,
    required this.response,
    required this.respondedAt,
    this.eventId,
    this.previousDueAt,
    this.newDueAt,
    this.previousPredictedStartAt,
    this.newPredictedStartAt,
    this.previousPredictionStatus,
    this.newPredictionStatus,
  });

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'responsibilityId': responsibilityId,
      'predictedAt': Timestamp.fromDate(predictedAt),
      'predictedStartAt': predictedStartAt != null
          ? Timestamp.fromDate(predictedStartAt!)
          : null,
      'response': response,
      'respondedAt': Timestamp.fromDate(respondedAt),
    };

    if (eventId != null) {
      map['eventId'] = eventId;
    }

    if (response == 'prediction_corrected') {
      map['previousDueAt'] = previousDueAt != null
          ? Timestamp.fromDate(previousDueAt!)
          : null;
      map['newDueAt'] = newDueAt != null
          ? Timestamp.fromDate(newDueAt!)
          : null;
      map['previousPredictedStartAt'] = previousPredictedStartAt != null
          ? Timestamp.fromDate(previousPredictedStartAt!)
          : null;
      map['newPredictedStartAt'] = newPredictedStartAt != null
          ? Timestamp.fromDate(newPredictedStartAt!)
          : null;
      map['previousPredictionStatus'] = previousPredictionStatus;
      map['newPredictionStatus'] = newPredictionStatus;
    }

    return map;
  }
}

class NotificationEvent {
  final String userId;
  final String responsibilityId;
  final String type;
  final DateTime at;
  final String? actionSelected;

  NotificationEvent({
    required this.userId,
    required this.responsibilityId,
    required this.type,
    required this.at,
    this.actionSelected,
  });

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'responsibilityId': responsibilityId,
    'type': type,
    'at': Timestamp.fromDate(at),
    'actionSelected': actionSelected,
  };
}