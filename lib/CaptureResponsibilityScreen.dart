import 'package:flutter/material.dart';
import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'AppColors.dart';

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
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nueva responsabilidad',
          style: AppTypography.screenTitle(color: palette.textPrimary, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Tipo ---
            Text(
              'Tipo',
              style: AppTypography.label(
                color: palette.textPrimary,
                size: 15,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ResponsibilityType.values.map((t) {
                return _buildChoiceChip(
                  label: _typeLabel(t),
                  selected: _type == t,
                  onSelected: () => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Materia / descripción ---
            _buildTextField(
              controller: _subjectController,
              label: 'Materia (opcional)',
              palette: palette,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _descriptionController,
              label: 'Descripción (opcional)',
              maxLines: 2,
              palette: palette,
            ),
            const SizedBox(height: 20),

            // --- Fecha de entrega ---
            Text(
              'Entrega',
              style: AppTypography.label(
                color: palette.textPrimary,
                size: 15,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDueDate,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.event),
              label: Text(
                _formatDateTime(_dueAt),
                style: AppTypography.body(color: palette.textPrimary),
              ),
            ),
            const SizedBox(height: 20),

            // --- Predicción de inicio ---
            Text(
              '¿Cuándo crees que empezarás?',
              style: AppTypography.label(
                color: palette.textPrimary,
                size: 15,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'Hoy',
                  selected: _startGuess == _StartGuess.today,
                  onSelected: () =>
                      setState(() => _startGuess = _StartGuess.today),
                ),
                _buildChoiceChip(
                  label: 'Mañana',
                  selected: _startGuess == _StartGuess.tomorrow,
                  onSelected: () =>
                      setState(() => _startGuess = _StartGuess.tomorrow),
                ),
                _buildChoiceChip(
                  label: _customStartDate != null
                      ? _formatDateTime(_customStartDate!)
                      : 'Elegir fecha',
                  selected: _startGuess == _StartGuess.pickDate,
                  onSelected: () => _pickCustomStartDate(),
                ),
                _buildChoiceChip(
                  label: 'Todavía no lo sé',
                  selected: _startGuess == _StartGuess.unknown,
                  onSelected: () =>
                      setState(() => _startGuess = _StartGuess.unknown),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _isSaving
                ? Center(
              child: CircularProgressIndicator(
                color: palette.textPrimary,
              ),
            )
                : ElevatedButton(
              onPressed: _startGuess == null ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.deepBlue,
                disabledBackgroundColor: palette.disabledBackground,
                disabledForegroundColor: palette.disabledForeground,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                'Guardar',
                style: AppTypography.button(
                  color: AppColors.deepBlue,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final palette = AppPalette.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.label(
          color: selected ? palette.onPrimaryAction : palette.textPrimary,
        ),
      ),
      selected: selected,
      selectedColor: palette.primaryAction,
      backgroundColor: palette.surface,
      side: BorderSide(color: palette.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required AppPalette palette,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppTypography.body(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.label(color: palette.textMuted),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.textPrimary, width: 1.4),
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