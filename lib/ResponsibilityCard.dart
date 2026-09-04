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
  bool _isSavingDates = false;
  bool _isDiscarding = false;

  String? _pendingCorrectionId;
  DateTime? _pendingNewDueAt;
  DateTime? _pendingNewPredictedStartAt;

  bool get _isBusy =>
      _isMarkingStarted || _isSavingDetails || _isSavingDates || _isDiscarding;

  DateTime _normalizeToMinute(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);

  Future<void> _markStarted() async {
    if (_isBusy) return;

    setState(() => _isMarkingStarted = true);

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
    } on DiscardedResponsibilityException {
      if (mounted) _showMessage('Esta observación ya fue descartada.');
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
      if (mounted) setState(() => _isMarkingStarted = false);
    }
  }

  Future<void> _markStartedInThePast() async {
    try {
      await widget.service
          .ensureResponsibilityActive(widget.responsibility.id);
    } on DiscardedResponsibilityException {
      if (mounted) _showMessage('Esta observación ya fue descartada.');
      return;
    }

    await showPastStartSelector(
      context,
      widget.responsibility.id,
      widget.service,
      StartSource.manualRecalled,
    );
  }

  Future<void> _openMoreActions() async {
    final canDiscard = widget.responsibility.status ==
        ResponsibilityStatus.pending &&
        widget.responsibility.startedAt == null;

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
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Corregir fechas'),
              onTap: () => Navigator.of(ctx).pop('edit_dates'),
            ),
            if (canDiscard)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Descartar observación'),
                onTap: () => Navigator.of(ctx).pop('discard'),
              ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (action == 'edit_details') {
      await _editDetails();
    } else if (action == 'edit_dates') {
      await _editDates();
    } else if (action == 'discard') {
      await _confirmDiscard();
    }
  }

  Future<void> _editDetails() async {
    final result = await showModalBottomSheet<_DetailsEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.50,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _DetailsEditorSheet(
              initialType: widget.responsibility.type,
              initialSubject: widget.responsibility.subject ?? '',
              initialDescription: widget.responsibility.description ?? '',
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() => _isSavingDetails = true);

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
        if (mounted) _showMessage('Detalles corregidos.');
        return;
      }

      try {
        await _notifications.cancelVerification(widget.responsibility.id);
        await _notifications.scheduleVerification(
          responsibilityId: widget.responsibility.id,
          subjectLabel: newLabel,
          predictedStartAt: predicted,
        );

        if (mounted) _showMessage('Detalles corregidos.');
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
      if (mounted) _showMessage('No se pudo corregir la responsabilidad.');
    } finally {
      if (mounted) setState(() => _isSavingDetails = false);
    }
  }

  Future<void> _editDates() async {
    final r = widget.responsibility;

    final canEditPrediction = r.status == ResponsibilityStatus.pending &&
        r.startedAt == null &&
        (r.predictedStartAt == null ||
            r.predictedStartAt!.isAfter(DateTime.now()));

    final result = await showModalBottomSheet<_DatesEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DatesEditorSheet(
        initialDueAt: r.dueAt,
        initialPredictedStartAt: r.predictedStartAt,
        canEditPrediction: canEditPrediction,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSavingDates = true);

    final normalizedNewDueAt = _normalizeToMinute(result.newDueAt);
    final normalizedNewPredictedStartAt = result.newPredictedStartAt != null
        ? _normalizeToMinute(result.newPredictedStartAt!)
        : null;

    final isSamePending = _pendingCorrectionId != null &&
        _pendingNewDueAt != null &&
        _pendingNewDueAt == normalizedNewDueAt &&
        _pendingNewPredictedStartAt == normalizedNewPredictedStartAt;

    final correctionId = isSamePending
        ? _pendingCorrectionId!
        : DateTime.now().microsecondsSinceEpoch.toString();

    _pendingCorrectionId = correctionId;
    _pendingNewDueAt = normalizedNewDueAt;
    _pendingNewPredictedStartAt = normalizedNewPredictedStartAt;

    try {
      final correctionResult = await widget.service.correctResponsibilityDates(
        responsibilityId: r.id,
        newDueAt: normalizedNewDueAt,
        newPredictedStartAt: normalizedNewPredictedStartAt,
        correctionId: correctionId,
      );

      if (!correctionResult.changed) {
        _pendingCorrectionId = null;
        _pendingNewDueAt = null;
        _pendingNewPredictedStartAt = null;
        if (mounted) _showMessage('No hubo cambios.');
        return;
      }

      if (correctionResult.predictionChanged) {
        try {
          await _notifications.cancelVerification(r.id);

          if (correctionResult.shouldScheduleNotification &&
              correctionResult.newPredictedStartAt != null) {
            final newLabel = r.subject?.trim().isNotEmpty == true
                ? r.subject!.trim()
                : _typeLabel(r.type);

            await _notifications.scheduleVerification(
              responsibilityId: r.id,
              subjectLabel: newLabel,
              predictedStartAt: correctionResult.newPredictedStartAt!,
            );
          }

          _pendingCorrectionId = null;
          _pendingNewDueAt = null;
          _pendingNewPredictedStartAt = null;

          if (mounted) _showMessage('Fechas corregidas.');
        } catch (e) {
          debugPrint('Update date notification error: $e');
          if (mounted) {
            _showMessage(
              'Las fechas fueron corregidas, pero no pudimos actualizar '
                  'el recordatorio. Inténtalo de nuevo.',
            );
          }
        }
      } else {
        _pendingCorrectionId = null;
        _pendingNewDueAt = null;
        _pendingNewPredictedStartAt = null;
        if (mounted) _showMessage('Fechas corregidas.');
      }
    } on DateCorrectionConflictException {
      if (mounted) {
        _showMessage(
            'No se pudo completar la corrección. Inténtalo nuevamente.');
      }
    } on StateError catch (e) {
      if (mounted) _showMessage(e.message.toString());
    } catch (e) {
      debugPrint('Date correction unexpected error: $e');
      if (mounted) _showMessage('No se pudo corregir las fechas.');
    } finally {
      if (mounted) setState(() => _isSavingDates = false);
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = AppPalette.of(context);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            '¿Descartar esta observación?',
            style: AppTypography.screenTitle(
              color: palette.textPrimary,
              size: 20,
            ),
          ),
          content: Text(
            'Desaparecerá de Inicio y dejarás de recibir su recordatorio. '
                'La evidencia ya registrada se conservará.',
            style: AppTypography.body(color: palette.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'CANCELAR',
                style: AppTypography.button(
                  color: palette.textPrimary,
                  size: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'DESCARTAR',
                style: AppTypography.button(
                  color: palette.destructive,
                  size: 14,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDiscarding = true);

    try {
      final result = await widget.service.discardResponsibility(
        responsibilityId: widget.responsibility.id,
      );

      if (result == DiscardResponsibilityResult.alreadyDiscarded) {
        if (mounted) _showMessage('La observación ya estaba descartada.');
        return;
      }

      try {
        await _notifications.cancelVerification(widget.responsibility.id);
        if (mounted) _showMessage('Observación descartada.');
      } catch (e) {
        debugPrint('Cancel notification error: $e');
        if (mounted) {
          _showMessage(
            'La observación fue descartada, pero no pudimos cancelar '
                'el recordatorio. Puedes ignorarlo si aparece.',
          );
        }
      }
    } on ResponsibilityHasStartedException {
      if (mounted) {
        _showMessage(
          'Esta observación ya contiene un inicio y no puede descartarse.',
        );
      }
    } on ResponsibilityHasEvidenceException {
      if (mounted) {
        _showMessage(
          'Esta observación ya contiene una respuesta y no puede descartarse.',
        );
      }
    } on DiscardedResponsibilityException {
      if (mounted) _showMessage('Esta observación ya fue descartada.');
    } catch (e) {
      debugPrint('Discard responsibility unexpected error: $e');
      if (mounted) {
        _showMessage(
          'No pudimos descartar la observación. Inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _isDiscarding = false);
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
    final description = r.description?.trim();

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
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      color: palette.textSecondary,
                      size: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (r.predictedStartAt != null)
                  Text(
                    'Inicio previsto: ${_compactDateTime(r.predictedStartAt!)}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      color: palette.textSecondary,
                      size: 14,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Entrega: ${_compactDateTime(r.dueAt)}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
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
                              : const Text('Empecé a trabajar'),
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

  String _compactDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = target.difference(today).inDays;

    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';
    final minute = dt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute $period';

    if (diff == 0) return 'hoy, $time';
    if (diff == 1) return 'mañana, $time';
    if (diff == -1) return 'ayer, $time';
    return '${dt.day} ${months[dt.month - 1]}., $time';
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
  final ScrollController scrollController;

  const _DetailsEditorSheet({
    required this.initialType,
    required this.initialSubject,
    required this.initialDescription,
    required this.scrollController,
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
        child: ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

class _DatesEditResult {
  final DateTime newDueAt;
  final DateTime? newPredictedStartAt;

  const _DatesEditResult({
    required this.newDueAt,
    required this.newPredictedStartAt,
  });
}

enum _PredictionChoice { today, tomorrow, pickDate, unknown }

class _DatesEditorSheet extends StatefulWidget {
  final DateTime initialDueAt;
  final DateTime? initialPredictedStartAt;
  final bool canEditPrediction;

  const _DatesEditorSheet({
    required this.initialDueAt,
    required this.initialPredictedStartAt,
    required this.canEditPrediction,
  });

  @override
  State<_DatesEditorSheet> createState() => _DatesEditorSheetState();
}

class _DatesEditorSheetState extends State<_DatesEditorSheet> {
  late DateTime _newDueAt;
  DateTime? _newPredictedStartAt;
  _PredictionChoice? _predictionChoice;

  @override
  void initState() {
    super.initState();
    _newDueAt = widget.initialDueAt;
    _newPredictedStartAt = widget.initialPredictedStartAt;
    _predictionChoice = _newPredictedStartAt == null
        ? _PredictionChoice.unknown
        : _PredictionChoice.pickDate;
  }

  DateTime? get _resolvedPredictedStart {
    if (!widget.canEditPrediction) return widget.initialPredictedStartAt;

    switch (_predictionChoice) {
      case _PredictionChoice.today:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 19);
      case _PredictionChoice.tomorrow:
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19);
      case _PredictionChoice.pickDate:
        return _newPredictedStartAt;
      case _PredictionChoice.unknown:
      case null:
        return null;
    }
  }

  bool get _todayChoiceEnabled {
    final now = DateTime.now();
    final todayAtSeven = DateTime(now.year, now.month, now.day, 19);
    return now.isBefore(todayAtSeven);
  }

  Future<void> _unfocusAndWait() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _pickNewDueDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 365));

    DateTime initialDate;

    final currentDue = _newDueAt;
    final candidate = DateTime(
      currentDue.year,
      currentDue.month,
      currentDue.day,
    );

    if (candidate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (candidate.isAfter(lastDate)) {
      initialDate = lastDate;
    } else {
      initialDate = candidate;
    }

    await _unfocusAndWait();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;

    await _unfocusAndWait();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_newDueAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _newDueAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickCustomPrediction() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final dueDate = _newDueAt;
    final lastDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (lastDate.isBefore(firstDate)) {
      _showMessage(
          'La fecha de entrega debe corregirse antes de elegir una predicción.');
      return;
    }

    DateTime initialDate;

    final currentPrediction = _newPredictedStartAt;
    if (currentPrediction != null) {
      final candidate = DateTime(
        currentPrediction.year,
        currentPrediction.month,
        currentPrediction.day,
      );

      if (candidate.isBefore(firstDate)) {
        initialDate = firstDate;
      } else if (candidate.isAfter(lastDate)) {
        initialDate = lastDate;
      } else {
        initialDate = candidate;
      }
    } else {
      initialDate = firstDate;
    }

    await _unfocusAndWait();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return;

    await _unfocusAndWait();
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _newPredictedStartAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _predictionChoice = _PredictionChoice.pickDate;
    });
  }

  void _showMessage(String message) {
    final palette = AppPalette.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppTypography.body(color: palette.surface)),
        backgroundColor: palette.textPrimary,
      ),
    );
  }

  void _save() {
    Navigator.of(context).pop(
      _DatesEditResult(
        newDueAt: _newDueAt,
        newPredictedStartAt: _resolvedPredictedStart,
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
                'Corregir fechas',
                style: AppTypography.screenTitle(
                  color: palette.textPrimary,
                  size: 20,
                ),
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
                onPressed: _pickNewDueDate,
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
                  _formatDateTime(_newDueAt),
                  style: AppTypography.body(color: palette.textPrimary),
                ),
              ),
              const SizedBox(height: 24),
              if (widget.canEditPrediction) ...[
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
                    Tooltip(
                      message: _todayChoiceEnabled
                          ? 'Hoy a las 7:00 p. m.'
                          : 'No disponible después de las 7:00 p. m.',
                      child: _buildDateChoiceChip(
                        label: 'Hoy',
                        selected: _predictionChoice == _PredictionChoice.today,
                        enabled: _todayChoiceEnabled,
                        onSelected: () => setState(() {
                          _predictionChoice = _PredictionChoice.today;
                        }),
                      ),
                    ),
                    _buildDateChoiceChip(
                      label: 'Mañana',
                      selected: _predictionChoice == _PredictionChoice.tomorrow,
                      onSelected: () => setState(() {
                        _predictionChoice = _PredictionChoice.tomorrow;
                      }),
                    ),
                    _buildDateChoiceChip(
                      label: _newPredictedStartAt != null &&
                          _predictionChoice == _PredictionChoice.pickDate
                          ? _formatDateTime(_newPredictedStartAt!)
                          : 'Elegir fecha',
                      selected: _predictionChoice == _PredictionChoice.pickDate,
                      onSelected: () => _pickCustomPrediction(),
                    ),
                    _buildDateChoiceChip(
                      label: 'Todavía no lo sé',
                      selected: _predictionChoice == _PredictionChoice.unknown,
                      onSelected: () => setState(() {
                        _predictionChoice = _PredictionChoice.unknown;
                      }),
                    ),
                  ],
                ),
              ] else ...[
                if (widget.initialPredictedStartAt != null) ...[
                  Text(
                    'Tu predicción actual',
                    style: AppTypography.label(
                      color: palette.textPrimary,
                      size: 15,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTime(widget.initialPredictedStartAt!),
                    style: AppTypography.body(
                      color: palette.textSecondary,
                      size: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Esta predicción ya forma parte de tu evidencia.',
                    style: AppTypography.body(
                      color: palette.textMuted,
                      size: 13,
                    ),
                  ),
                ] else ...[
                  Text(
                    'No hay predicción para esta responsabilidad.',
                    style: AppTypography.body(
                      color: palette.textMuted,
                      size: 13,
                    ),
                  ),
                ],
              ],
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

  Widget _buildDateChoiceChip({
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: enabled ? (_) => onSelected() : null,
      ),
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
}

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
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));

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