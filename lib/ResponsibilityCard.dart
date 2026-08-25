import 'package:flutter/material.dart';
import 'AnalyticsService.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'main.dart';
import 'AppColors.dart';

// Set global en memoria para deduplicar la exposición de la confrontación
// durante el ciclo de vida de la aplicación.
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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _markStarted() async {
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
  }

  Future<void> _markStartedInThePast() async {
    await showPastStartSelector(
      context,
      widget.responsibility.id,
      widget.service,
      StartSource.manualRecalled,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.subject ?? _typeLabel(r.type),
              style: AppTypography.label(
                color: palette.textPrimary,
                size: 16,
              ).copyWith(fontWeight: FontWeight.w600),
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
                      onPressed: _markStarted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.deepBlue,
                      ),
                      child: const Text('Empecé a trabajar en esto'),
                    ),
                  ),
                  IconButton(
                    tooltip: '¿Empezaste antes y olvidaste registrarlo?',
                    icon: const Icon(Icons.history),
                    color: palette.textMuted,
                    onPressed: _markStartedInThePast,
                  ),
                ],
              ),
            ],
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
        child: Text(
          'Empezaste ${_relativeDay(r.startedAt!)}.',
          style: AppTypography.body(
            color: palette.confrontationText,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }
    final deviationHours = r.startDeviationHours!;
    final absHours = deviationHours.abs();
    final late = deviationHours > 0;

    String message;
    if (absHours < 1) {
      message = r.isHighQualityStart
          ? 'Empezaste prácticamente cuando lo habías previsto.'
          : 'Según la fecha que recordaste, empezaste aproximadamente cuando lo habías previsto.';
    } else if (absHours < 24) {
      final h = absHours.round();
      final unit = h == 1 ? 'hora' : 'horas';
      message = r.isHighQualityStart
          ? (late
          ? 'Comenzaste $h $unit después de lo previsto.'
          : 'Comenzaste $h $unit antes de lo previsto.')
          : (late
          ? 'Según la fecha que recordaste, comenzaste aproximadamente $h $unit después de lo previsto.'
          : 'Según la fecha que recordaste, comenzaste aproximadamente $h $unit antes de lo previsto.');
    } else {
      final d = (absHours / 24).round();
      final unit = d == 1 ? 'día' : 'días';
      message = r.isHighQualityStart
          ? (late
          ? 'Comenzaste $d $unit después de lo previsto.'
          : 'Comenzaste $d $unit antes de lo previsto.')
          : (late
          ? 'Según la fecha que recordaste, comenzaste aproximadamente $d $unit después de lo previsto.'
          : 'Según la fecha que recordaste, comenzaste aproximadamente $d $unit antes de lo previsto.');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.confrontationBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.confrontationBorder),
      ),
      child: Text(
        message,
        style: AppTypography.body(
          color: palette.confrontationText,
        ).copyWith(fontStyle: FontStyle.italic),
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

// === FUNCIÓN GLOBAL PARA REUTILIZAR EL MODAL ===
Future<void> showPastStartSelector(
    BuildContext context,
    String responsibilityId,
    ResponsibilityService service,
    StartSource source,
    ) async {
  final palette = AppPalette.of(context);
  final now = DateTime.now();

  // 1. Esperamos la decisión del modal.
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
            onTap: () => Navigator.pop(ctx, 'custom'), // Retornamos un flag
          ),
        ],
      ),
    ),
  );

  if (choice == null) return;

  DateTime? finalDate;

  // 2. Procesamos la decisión de forma lineal.
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
    if (time == null) return;

    finalDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // --- BLOQUEO B4: IMPEDIR HORAS FUTURAS ---
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

  // 3. Guardamos en base de datos y usamos la LLAVE GLOBAL blindada
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