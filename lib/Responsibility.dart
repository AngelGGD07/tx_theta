import 'package:cloud_firestore/cloud_firestore.dart';

/// Fuente del dato de inicio: distingue calidad de la señal.
enum StartSource {
  manualLive, // Tocó "Empecé" en el momento real.
  manualRecalled, // Registró un inicio pasado, de memoria.
  reminderLive, // Respondió "Estoy empezando" a la notificación.
  reminderRecalled, // Respondió "Ya había empezado" a la notificación.
}

enum ResponsibilityStatus { pending, started, completed, submitted }

enum ResponsibilityType { exam, lab, project, homework, presentation }

/// Una responsabilidad académica (tarea, examen, laboratorio, etc.)
/// Este modelo incluye TODOS los campos de la spec completa, aunque el MVP
/// solo use un subconjunto. Esto evita migraciones de esquema más adelante.
class Responsibility {
  final String id;
  final String userId;
  final ResponsibilityType type;
  final String? subject; // Materia (ej. "Física")
  final String? description;

  final DateTime createdAt;
  final DateTime dueAt;

  // --- Predicción declarada por el estudiante ---
  final DateTime? predictedStartAt; // null si eligió "todavía no lo sé"
  final String predictionStatus; // 'declared' | 'unknown'

  // --- Realidad observada ---
  DateTime? startedAt;
  StartSource? startSource;

  // Reservados para después del sprint de validación (no se usan aún).
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

  /// Diferencia entre lo previsto y lo real, en horas.
  /// Positivo = empezó después de lo previsto (procrastinó).
  /// Negativo = empezó antes de lo previsto.
  /// Null si no hay predicción o no ha empezado.
  double? get startDeviationHours {
    if (predictedStartAt == null || startedAt == null) return null;
    return startedAt!.difference(predictedStartAt!).inMinutes / 60.0;
  }

  /// true si el dato de inicio es de "alta calidad" (en vivo, no recordado).
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

/// Evento inmutable de predicción. NUNCA se sobrescribe — cada
/// reprogramación crea un nuevo registro. Esto es lo que permite,
/// más adelante, medir cuántas veces un estudiante negoció consigo mismo.
class PredictionEvent {
  final String responsibilityId;
  final DateTime predictedAt; // Cuándo se hizo esta predicción/respuesta.
  final DateTime? predictedStartAt; // Nueva fecha prevista (si aplica).
  final String response; // 'started' | 'not_started' | 'postponed'
  final DateTime respondedAt;

  PredictionEvent({
    required this.responsibilityId,
    required this.predictedAt,
    this.predictedStartAt,
    required this.response,
    required this.respondedAt,
  });

  Map<String, dynamic> toFirestore() => {
    'responsibilityId': responsibilityId,
    'predictedAt': Timestamp.fromDate(predictedAt),
    'predictedStartAt':
    predictedStartAt != null ? Timestamp.fromDate(predictedStartAt!) : null,
    'response': response,
    'respondedAt': Timestamp.fromDate(respondedAt),
  };
}

/// Eventos de la notificación de verificación, para no confundir
/// "no llegó la notificación" con "el usuario la ignoró".
class NotificationEvent {
  final String responsibilityId;
  final String type; // 'notification_scheduled' | 'notification_opened' | 'notification_action_selected'
  final DateTime at;
  final String? actionSelected;

  NotificationEvent({
    required this.responsibilityId,
    required this.type,
    required this.at,
    this.actionSelected,
  });

  Map<String, dynamic> toFirestore() => {
    'responsibilityId': responsibilityId,
    'type': type,
    'at': Timestamp.fromDate(at),
    'actionSelected': actionSelected,
  };
}