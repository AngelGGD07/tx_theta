import 'package:flutter/material.dart';
import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'VerificationNotificationService.dart';
import 'main.dart';
import 'AppColors.dart';

final Set<String> _loggedConfrontations = {};

class ResponsibilityCard extends StatefulWidget {
  final Responsibility responsibility;
  final ResponsibilityService service;

  const ResponsibilityCard({
    super.key,
    required this.responsibility,
    required this.service,
  });

  @override
  State<ResponsibilityCard> createState() => _ResponsibilityCardState();
}

class _ResponsibilityCardState extends State<ResponsibilityCard> {
  final _analytics = AnalyticsService();
  final _notifications = VerificationNotificationService();

  bool _isMarkingStarted = false;
  bool _isSavingDetails = false;

  bool get _isBusy => _isMarkingStarted || _isSavingDetails;

  Future<void> _markStarted() async {
    if (_isBusy) return;

    setState(() {
      _isMarkingStarted = true;
    });

    try {
      await widget.service.markStarted(
        responsibilityId: widget.responsibility.id,
        actualStartAt: DateTime.now(),
        source: StartSource.manualLive,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Inicio registrado'),
          duration: const Duration(seconds: 6),
          persist: false,
          action: SnackBarAction(
            label: 'DESHACER',
            onPressed: () async {
              await widget.service.undoStart(widget.responsibility.id);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error al registrar inicio: $e');
      if (!mounted) return;
      final palette = AppPalette.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar el inicio. Inténtalo nuevamente.',
            style: AppTypography.body(color: palette.onDestructive),
          ),
          backgroundColor: palette.destructive,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingStarted = false;
        });
      }
    }
  }

  Future<void> _markStartedInThePast() async {
    await showPastStartSelector(
      context,
      widget.responsibility.id,
      widget.service,
      StartSource.manualRecalled,
    );
  }

  Future<void> _openMoreActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppPalette.of(context).surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Corregir detalles'),
              onTap: () => Navigator.of(ctx).pop('edit_details'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit_details' && mounted) {
      await _editDetails();
    }
  }

  Future<void> _editDetails() async {
    final result = await showModalBottomSheet<_DetailsEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailsEditorSheet(
        initialType: widget.responsibility.type,
        initialSubject: widget.responsibility.subject ?? '',
        initialDescription: widget.responsibility.description ?? '',
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _isSavingDetails = true;
    });

    try {
      final oldSubject = widget.responsibility.subject?.trim();
      final oldLabel = (oldSubject != null && oldSubject.isNotEmpty)
          ? oldSubject
          : _typeLabel(widget.responsibility.type);

      final newSubject = result.subject?.trim();
      final newLabel = (newSubject != null && newSubject.isNotEmpty)
          ? newSubject
          : _typeLabel(result.type);

      await widget.service.updateResponsibilityDetails(
        responsibilityId: widget.responsibility.id,
        type: result.type,
        subject: result.subject,
        description: result.description,
      );

      final predicted = widget.responsibility.predictedStartAt;
      final shouldUpdateNotification = oldLabel != newLabel &&
          predicted != null &&
          predicted.isAfter(DateTime.now());

      if (!shouldUpdateNotification) {
        if (mounted) {
          _showMessage('Detalles corregidos.');
        }
        return;
      }

      try {
        await _notifications.cancelVerification(widget.responsibility.id);
        await _notifications.scheduleVerification(
          responsibilityId: widget.responsibility.id,
          subjectLabel: newLabel,
          predictedStartAt: predicted,
        );

        if (mounted) {
          _showMessage('Detalles corregidos.');
        }
      } catch (e) {
        debugPrint('Update notification error: $e');
        if (mounted) {
          _showMessage(
            'Los detalles fueron corregidos, pero no pudimos actualizar '
                'el texto del recordatorio.',
          );
        }
      }
    } catch (e) {
      debugPrint('Update details error: $e');
      if (mounted) {
        _showMessage('No se pudo corregir la responsabilidad.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDetails = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.body(color: palette.surface),
        ),
        backgroundColor: palette.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final r = widget.responsibility;
    final hasStarted = r.startedAt != null;

    if (hasStarted) {
      final confrontationKey = '${r.id}_${r.startedAt!.millisecondsSinceEpoch}';

      if (!_loggedConfrontations.contains(confrontationKey)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _loggedConfrontations.contains(confrontationKey)) {
            return;
          }

          _loggedConfrontations.add(confrontationKey);

          _analytics.logEvent(
            AnalyticsEvents.confrontationShown,
            parameters: {
              AnalyticsParams.responsibilityId: r.id,
              AnalyticsParams.startSource: r.startSource?.name,
            },
          );
        });
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Text(
                    r.subject ?? _typeLabel(r.type),
                    style: AppTypography.label(
                      color: palette.textPrimary,
                      size: 16,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                if (r.predictedStartAt != null)
                  Text(
                    'Pensabas comenzar ${_relativeDay(r.predictedStartAt!)}',
                    style: AppTypography.body(
                      color: palette.textSecondary,
                      size: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Entrega ${_relativeDay(r.dueAt)}',
                  style: AppTypography.body(
                    color: palette.textSecondary,
                    size: 14,
                  ),
                ),
                const SizedBox(height: 12),
                if (hasStarted) ...[
                  _buildConfrontation(palette, r),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _markStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primaryAction,
                            foregroundColor: palette.onPrimaryAction,
                            disabledBackgroundColor: palette.disabledBackground,
                            disabledForegroundColor: palette.disabledForeground,
                          ),
                          child: _isMarkingStarted
                              ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: palette.onPrimaryAction,
                            ),
                          )
                              : const Text('Empecé a trabajar en esto'),
                        ),
                      ),
                      IconButton(
                        tooltip: '¿Empezaste antes y olvidaste registrarlo?',
                        icon: const Icon(Icons.history),
                        color: palette.textMuted,
                        onPressed: _isBusy ? null : _markStartedInThePast,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            Positioned(
              top: -12,
              right: -8,
              child: IconButton(
                tooltip: 'Más acciones',
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                color: palette.textMuted,
                onPressed: _isBusy ? null : _openMoreActions,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfrontation(AppPalette palette, Responsibility r) {
    if (r.predictedStartAt == null || r.startedAt == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.confrontationBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.confrontationBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confrontationLabel('COMENZASTE', palette),
            const SizedBox(height: 4),
            _confrontationDate(_formatDateTime(r.startedAt!), palette),
          ],
        ),
      );
    }

    final deviationHours = r.startDeviationHours!;
    final absHours = deviationHours.abs();
    final late = deviationHours > 0;

    String resultText;
    if (absHours < 1) {
      resultText = 'Prácticamente a la hora prevista';
    } else if (absHours < 24) {
      final h = absHours.round();
      final unit = h == 1 ? 'hora' : 'horas';
      resultText = late ? '$h $unit después' : '$h $unit antes';
    } else {
      final d = (absHours / 24).round();
      final unit = d == 1 ? 'día' : 'días';
      resultText = late ? '$d $unit después' : '$d $unit antes';
    }

    final isRetrospective = r.startSource == StartSource.manualRecalled ||
        r.startSource == StartSource.reminderRecalled;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.confrontationBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.confrontationBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _confrontationLabel('PENSABAS COMENZAR', palette),
          const SizedBox(height: 4),
          _confrontationDate(
            _formatDateTime(r.predictedStartAt!),
            palette,
          ),
          const SizedBox(height: 12),
          _confrontationLabel('COMENZASTE', palette),
          const SizedBox(height: 4),
          _confrontationDate(
            _formatDateTime(r.startedAt!),
            palette,
          ),
          if (isRetrospective) ...[
            const SizedBox(height: 8),
            Text(
              'Según la fecha que recordaste',
              style: AppTypography.body(
                color: palette.textSecondary,
                size: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            resultText.toUpperCase(),
            style: AppTypography.confrontationValue(
              color: palette.confrontationText,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confrontationLabel(String text, AppPalette palette) {
    return Text(
      text,
      style: AppTypography.label(
        color: palette.textSecondary,
        size: 13,
      ).copyWith(fontWeight: FontWeight.w500),
    );
  }

  Widget _confrontationDate(String text, AppPalette palette) {
    return Text(
      text,
      style: AppTypography.body(
        color: palette.confrontationText,
        size: 16,
      ).copyWith(fontWeight: FontWeight.w600),
    );
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

  String _relativeDay(DateTime dt) {
    final now = DateTime.now();
    final diff = DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';
    final time = '$hour:${dt.minute.toString().padLeft(2, '0')} $period';

    if (diff == 0) return 'hoy a las $time';
    if (diff == 1) return 'mañana a las $time';
    if (diff == -1) return 'ayer a las $time';
    if (diff > 1) return 'en $diff días';
    return 'hace ${-diff} días';
  }
}

class _DetailsEditResult {
  final ResponsibilityType type;
  final String? subject;
  final String? description;

  const _DetailsEditResult({
    required this.type,
    required this.subject,
    required this.description,
  });
}

class _DetailsEditorSheet extends StatefulWidget {
  final ResponsibilityType initialType;
  final String initialSubject;
  final String initialDescription;

  const _DetailsEditorSheet({
    required this.initialType,
    required this.initialSubject,
    required this.initialDescription,
  });

  @override
  State<_DetailsEditorSheet> createState() => _DetailsEditorSheetState();
}

class _DetailsEditorSheetState extends State<_DetailsEditorSheet> {
  late ResponsibilityType _type;
  late final TextEditingController _subjectController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _subjectController = TextEditingController(text: widget.initialSubject);
    _descriptionController =
        TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final subject = _subjectController.text.trim();
    final description = _descriptionController.text.trim();

    Navigator.of(context).pop(
      _DetailsEditResult(
        type: _type,
        subject: subject.isEmpty ? null : subject,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: palette.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(
                    color: palette.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Corregir detalles',
                style: AppTypography.screenTitle(
                  color: palette.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 16),
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
                runSpacing: 8,
                children: ResponsibilityType.values.map((t) {
                  return ChoiceChip(
                    label: Text(
                      _typeLabel(t),
                      style: AppTypography.label(
                        color: _type == t
                            ? palette.onPrimaryAction
                            : palette.textPrimary,
                      ),
                    ),
                    selected: _type == t,
                    selectedColor: palette.primaryAction,
                    backgroundColor: palette.surface,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subjectController,
                maxLines: 1,
                textInputAction: TextInputAction.next,
                style: AppTypography.body(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Materia (opcional)',
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
                    borderSide:
                    BorderSide(color: palette.textPrimary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: AppTypography.body(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
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
                    borderSide:
                    BorderSide(color: palette.textPrimary, width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCELAR',
                      style: AppTypography.button(
                        color: palette.textPrimary,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _save,
                    child: Text(
                      'GUARDAR',
                      style: AppTypography.button(
                        color: palette.primaryAction,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}

// === FUNCIÓN GLOBAL PARA REUTILIZAR EL MODAL ===
Future<void> showPastStartSelector(
    BuildContext context,
    String responsibilityId,
    ResponsibilityService service,
    StartSource source,
    ) async {
  final palette = AppPalette.of(context);
  final now = DateTime.now();

  final choice = await showModalBottomSheet<dynamic>(
    context: context,
    backgroundColor: palette.surface,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'Hoy, más temprano',
              style: AppTypography.body(color: palette.textPrimary),
            ),
            onTap: () => Navigator.pop(
                ctx, DateTime(now.year, now.month, now.day, 9)),
          ),
          ListTile(
            title: Text(
              'Ayer',
              style: AppTypography.body(color: palette.textPrimary),
            ),
            onTap: () {
              final yesterday = now.subtract(const Duration(days: 1));
              Navigator.pop(ctx,
                  DateTime(yesterday.year, yesterday.month, yesterday.day, 19));
            },
          ),
          ListTile(
            title: Text(
              'Elegir fecha y hora',
              style: AppTypography.body(color: palette.textPrimary),
            ),
            onTap: () => Navigator.pop(ctx, 'custom'),
          ),
        ],
      ),
    ),
  );

  if (choice == null) return;
  if (!context.mounted) return;

  DateTime? finalDate;

  if (choice is DateTime) {
    finalDate = choice;
  } else if (choice == 'custom') {
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !context.mounted) return;

    finalDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (finalDate.isAfter(DateTime.now())) {
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No puedes registrar un inicio en el futuro.'),
          ),
        );
      return;
    }
  }

  if (finalDate != null) {
    await service.markStarted(
      responsibilityId: responsibilityId,
      actualStartAt: finalDate,
      source: source,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Inicio registrado'),
          duration: const Duration(seconds: 6),
          persist: false,
          action: SnackBarAction(
            label: 'DESHACER',
            onPressed: () => service.undoStart(responsibilityId),
          ),
        ),
      );
    });
  }
}