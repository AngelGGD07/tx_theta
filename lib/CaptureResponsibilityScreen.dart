import 'package:flutter/material.dart';
import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';

/// Predicción de inicio: opciones simples, tal como se definió en la spec.
/// "Todavía no lo sé" deja predictedStartAt = null explícitamente, nunca
/// se asume "hoy" por defecto.
enum _StartGuess { today, tomorrow, pickDate, unknown }

class CaptureResponsibilityScreen extends StatefulWidget {
  const CaptureResponsibilityScreen({super.key});

  @override
  State<CaptureResponsibilityScreen> createState() =>
      _CaptureResponsibilityScreenState();
}

class _CaptureResponsibilityScreenState
    extends State<CaptureResponsibilityScreen> {
  final _service = ResponsibilityService();
  final _notifications = VerificationNotificationService();
  final _analytics = AnalyticsService();

  ResponsibilityType _type = ResponsibilityType.homework;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _dueAt = DateTime.now().add(const Duration(days: 3));
  _StartGuess? _startGuess;
  DateTime? _customStartDate;

  bool _isSaving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime? get _resolvedPredictedStart {
    switch (_startGuess) {
      case _StartGuess.today:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 19); // 7pm por defecto
      case _StartGuess.tomorrow:
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        return DateTime(
            tomorrow.year, tomorrow.month, tomorrow.day, 19);
      case _StartGuess.pickDate:
        return _customStartDate;
      case _StartGuess.unknown:
      case null:
        return null;
    }
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickCustomStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: _dueAt,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      _customStartDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _startGuess = _StartGuess.pickDate;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final predictedStart = _resolvedPredictedStart;
      final responsibility = await _service.createResponsibility(
        type: _type,
        subject: _subjectController.text.trim().isEmpty
            ? null
            : _subjectController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueAt: _dueAt,
        predictedStartAt: predictedStart,
      );

      await _analytics.logEvent(
        AnalyticsEvents.responsibilityCreated,
        parameters: {
          AnalyticsParams.responsibilityId: responsibility.id,
          AnalyticsParams.responsibilityType: _type.name,
          // Convertimos el booleano a 1 o 0 como exige la convención
          AnalyticsParams.hasPrediction: predictedStart != null ? 1 : 0,
        },
      );

      await _analytics.logEvent(
        AnalyticsEvents.predictionCreated,
        parameters: {
          AnalyticsParams.responsibilityId: responsibility.id,
          AnalyticsParams.predictionStatus:
          predictedStart != null ? 'declared' : 'unknown',
        },
      );

      if (predictedStart != null) {
        final label = responsibility.subject ?? _typeLabel(_type);
        await _notifications.scheduleVerification(
          responsibilityId: responsibility.id,
          subjectLabel: label,
          predictedStartAt: predictedStart,
        );
        await _service.logNotificationEvent(
          responsibilityId: responsibility.id,
          type: 'notification_scheduled',
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _typeLabel(ResponsibilityType t) {
    switch (t) {
      case ResponsibilityType.exam:
        return 'Examen';
      case ResponsibilityType.lab:
        return 'Laboratorio';
      case ResponsibilityType.project:
        return 'Proyecto';
      case ResponsibilityType.homework:
        return 'Tarea';
      case ResponsibilityType.presentation:
        return 'Exposición';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva responsabilidad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Tipo ---
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ResponsibilityType.values.map((t) {
                final selected = _type == t;
                return ChoiceChip(
                  label: Text(_typeLabel(t)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Materia / descripción ---
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Materia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // --- Fecha de entrega ---
            const Text('Entrega',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event),
              label: Text(_formatDateTime(_dueAt)),
            ),
            const SizedBox(height: 20),

            // --- Predicción de inicio ---
            const Text('¿Cuándo crees que empezarás?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Hoy'),
                  selected: _startGuess == _StartGuess.today,
                  onSelected: (_) =>
                      setState(() => _startGuess = _StartGuess.today),
                ),
                ChoiceChip(
                  label: const Text('Mañana'),
                  selected: _startGuess == _StartGuess.tomorrow,
                  onSelected: (_) =>
                      setState(() => _startGuess = _StartGuess.tomorrow),
                ),
                ChoiceChip(
                  label: Text(_customStartDate != null
                      ? _formatDateTime(_customStartDate!)
                      : 'Elegir fecha'),
                  selected: _startGuess == _StartGuess.pickDate,
                  onSelected: (_) => _pickCustomStartDate(),
                ),
                ChoiceChip(
                  label: const Text('Todavía no lo sé'),
                  selected: _startGuess == _StartGuess.unknown,
                  onSelected: (_) =>
                      setState(() => _startGuess = _StartGuess.unknown),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _startGuess == null ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  final hour = dt.hour == 0
      ? 12
      : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${months[dt.month - 1]}, $hour:$minute $period';
}