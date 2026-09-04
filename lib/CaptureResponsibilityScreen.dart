import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'AppColors.dart';

enum _StartGuess {
  tomorrow,
  pickDate,
  unknown,
}

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
  DateTime? _tomorrowStartDate;

  bool _isSaving = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime? get _resolvedPredictedStart {
    switch (_startGuess) {
      case _StartGuess.tomorrow:
        return _tomorrowStartDate;
      case _StartGuess.pickDate:
        return _customStartDate;
      case _StartGuess.unknown:
      case null:
        return null;
    }
  }

  Future<void> _unfocusAndWait() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _pickDueDate() async {
    await _unfocusAndWait();
    if (!mounted) return;

    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    await _unfocusAndWait();
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt),
    );
    if (time == null || !mounted) return;

    final selectedDueAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selectedDueAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La entrega debe estar en el futuro.'),
        ),
      );
      return;
    }

    final existingPrediction = _resolvedPredictedStart;

    setState(() {
      _dueAt = selectedDueAt;
    });

    if (existingPrediction != null &&
        !existingPrediction.isBefore(_dueAt)) {
      setState(() {
        _startGuess = null;
        _tomorrowStartDate = null;
        _customStartDate = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cambiamos la entrega. Selecciona nuevamente cuándo crees que empezarás.',
          ),
        ),
      );
    }
  }

  Future<void> _pickTomorrowStartTime() async {
    await _unfocusAndWait();
    if (!mounted) return;

    final now = DateTime.now();
    final tomorrowDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    if (_dueAt.isBefore(tomorrowDate) ||
        _dueAt.isAtSameMomentAs(tomorrowDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La entrega ocurre antes de mañana. Usa Elegir fecha para seleccionar una hora anterior.',
          ),
        ),
      );
      return;
    }

    TimeOfDay initialTime;

    if (_tomorrowStartDate != null) {
      initialTime = TimeOfDay.fromDateTime(_tomorrowStartDate!);
    } else {
      final defaultTomorrowStart = DateTime(
        tomorrowDate.year,
        tomorrowDate.month,
        tomorrowDate.day,
        9,
        0,
      );

      if (defaultTomorrowStart.isBefore(_dueAt)) {
        initialTime = const TimeOfDay(hour: 9, minute: 0);
      } else {
        final suggested = _dueAt.subtract(const Duration(minutes: 1));

        final suggestedTomorrow = DateTime(
          tomorrowDate.year,
          tomorrowDate.month,
          tomorrowDate.day,
          suggested.hour,
          suggested.minute,
        );

        if (suggestedTomorrow.isAfter(now) &&
            suggestedTomorrow.isBefore(_dueAt)) {
          initialTime = TimeOfDay.fromDateTime(suggestedTomorrow);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay una hora válida para mañana. Usa Elegir fecha.',
              ),
            ),
          );
          return;
        }
      }
    }

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time == null || !mounted) return;

    final selectedStart = DateTime(
      tomorrowDate.year,
      tomorrowDate.month,
      tomorrowDate.day,
      time.hour,
      time.minute,
    );

    if (!selectedStart.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha y hora futuras.'),
        ),
      );
      return;
    }

    if (!selectedStart.isBefore(_dueAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La predicción debe ser anterior a la entrega.'),
        ),
      );
      return;
    }

    setState(() {
      _tomorrowStartDate = selectedStart;
      _startGuess = _StartGuess.tomorrow;
    });
  }

  Future<void> _pickCustomStartDate() async {
    await _unfocusAndWait();
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final dueDate = DateTime(
      _dueAt.year,
      _dueAt.month,
      _dueAt.day,
    );

    if (dueDate.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero elige una fecha de entrega futura.'),
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: dueDate,
    );
    if (date == null || !mounted) return;

    final selectedDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    TimeOfDay initialTime;

    if (_customStartDate != null &&
        DateTime(
          _customStartDate!.year,
          _customStartDate!.month,
          _customStartDate!.day,
        ) ==
            selectedDay) {
      initialTime = TimeOfDay.fromDateTime(_customStartDate!);
    } else if (selectedDay == today) {
      final suggested = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      ).add(const Duration(minutes: 2));

      DateTime? initialDateTime;

      if (suggested.day == today.day &&
          suggested.isAfter(now) &&
          suggested.isBefore(_dueAt)) {
        initialDateTime = suggested;
      } else {
        final lastPossibleStart = _dueAt.subtract(const Duration(minutes: 1));
        if (lastPossibleStart.day == today.day &&
            lastPossibleStart.isAfter(now) &&
            lastPossibleStart.isBefore(_dueAt)) {
          initialDateTime = lastPossibleStart;
        }
      }

      if (initialDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ya no queda una hora válida para hoy. Elige otra fecha.',
            ),
          ),
        );
        return;
      }

      initialTime = TimeOfDay.fromDateTime(initialDateTime);
    } else {
      initialTime = const TimeOfDay(hour: 9, minute: 0);
    }

    await _unfocusAndWait();
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time == null || !mounted) return;

    final selectedStart = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!selectedStart.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha y hora futuras.'),
        ),
      );
      return;
    }

    if (!selectedStart.isBefore(_dueAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La predicción debe ser anterior a la entrega.'),
        ),
      );
      return;
    }

    setState(() {
      _customStartDate = selectedStart;
      _startGuess = _StartGuess.pickDate;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    if (!_dueAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La entrega debe estar en el futuro.'),
        ),
      );
      return;
    }

    final predictedStart = _resolvedPredictedStart;

    if (predictedStart != null) {
      if (!predictedStart.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La predicción debe estar en el futuro.'),
          ),
        );
        return;
      }

      if (!predictedStart.isBefore(_dueAt)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La predicción debe ser anterior a la entrega.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
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
      debugPrint('Capture save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la responsabilidad.'),
          ),
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

  String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final displayName =
    FirebaseAuth.instance.currentUser?.displayName?.trim();
    final predictionTitle = (displayName != null && displayName.isNotEmpty)
        ? '$displayName, ¿cuándo crees que empezarás?'
        : '¿Cuándo crees que empezarás?';

    final tomorrowLabel = _tomorrowStartDate == null
        ? 'Mañana'
        : 'Mañana, ${_formatTimeOnly(_tomorrowStartDate!)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Nueva responsabilidad',
          style: AppTypography.screenTitle(
            color: palette.textPrimary,
            size: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('¿Qué te dejaron?', palette),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ResponsibilityType.values.map((t) {
                return _buildChoiceChip(
                  label: _typeLabel(t),
                  selected: _type == t,
                  onSelected: () => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('Contexto', palette),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 32),
            _buildSectionTitle(predictionTitle, palette),
            const SizedBox(height: 4),
            Text(
              'Elige una hora realista. La compararemos con la hora en que realmente empieces.',
              style: AppTypography.body(
                color: palette.textSecondary,
                size: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Podrás cambiarla antes de la hora elegida, siempre que aún no hayas respondido ni comenzado.',
              style: AppTypography.body(
                color: palette.textMuted,
                size: 13,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: tomorrowLabel,
                  selected: _startGuess == _StartGuess.tomorrow,
                  onSelected: () => _pickTomorrowStartTime(),
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
                backgroundColor: palette.primaryAction,
                foregroundColor: palette.onPrimaryAction,
                disabledBackgroundColor: palette.disabledBackground,
                disabledForegroundColor: palette.disabledForeground,
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Registrar',
                style: AppTypography.button(
                  color: palette.onPrimaryAction,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppPalette palette) {
    return Text(
      title,
      style: AppTypography.label(
        color: palette.textPrimary,
        size: 18,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    bool enabled = true,
  }) {
    final palette = AppPalette.of(context);

    return Semantics(
      enabled: enabled,
      button: true,
      label: label,
      child: ChoiceChip(
        label: Text(
          label,
          style: AppTypography.label(
            color: selected
                ? palette.onPrimaryAction
                : enabled
                ? palette.textPrimary
                : palette.textMuted,
          ),
        ),
        selected: selected,
        selectedColor: palette.primaryAction,
        backgroundColor: palette.surface,
        disabledColor: palette.surface,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        onSelected: enabled ? (_) => onSelected() : null,
      ),
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