import 'package:flutter/material.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';
import 'main.dart';

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
    final r = widget.responsibility;
    final hasStarted = r.startedAt != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.subject ?? _typeLabel(r.type),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (r.predictedStartAt != null)
              Text(
                'Pensabas comenzar ${_relativeDay(r.predictedStartAt!)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            const SizedBox(height: 4),
            Text(
              'Entrega ${_relativeDay(r.dueAt)}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (hasStarted) ...[
              _buildConfrontation(r),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _markStarted,
                      child: const Text('Empecé a trabajar en esto'),
                    ),
                  ),
                  IconButton(
                    tooltip: '¿Empezaste antes y olvidaste registrarlo?',
                    icon: const Icon(Icons.history),
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

  Widget _buildConfrontation(Responsibility r) {
    if (r.predictedStartAt == null || r.startedAt == null) {
      return Text(
        'Empezaste ${_relativeDay(r.startedAt!)}.',
        style: const TextStyle(fontStyle: FontStyle.italic),
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(fontStyle: FontStyle.italic)),
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

  final now = DateTime.now();

  // 1. Esperamos la decisión del modal.
  final choice = await showModalBottomSheet<dynamic>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Hoy, más temprano'),
            onTap: () => Navigator.pop(ctx, DateTime(now.year, now.month, now.day, 9)),
          ),
          ListTile(
            title: const Text('Ayer'),
            onTap: () {
              final yesterday = now.subtract(const Duration(days: 1));
              Navigator.pop(ctx, DateTime(yesterday.year, yesterday.month, yesterday.day, 19));
            },
          ),
          ListTile(
            title: const Text('Elegir fecha y hora'),
            onTap: () => Navigator.pop(ctx, 'custom'), // Retornamos un flag
          ),
        ],
      ),
    ),
  );

  // Si el usuario cerró el modal tocando afuera, cancelamos.
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

    finalDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    // --- BLOQUEO B4: IMPEDIR HORAS FUTURAS ---
    if (finalDate.isAfter(DateTime.now())) {
      rootScaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('No puedes registrar un inicio en el futuro.'),
          ),
        );
      return; // Detenemos la función, no se guarda nada en Firestore.
    }
    // -----------------------------------------
  }

  // 3. Guardamos en base de datos y usamos la LLAVE GLOBAL blindada
  if (finalDate != null) {
    await service.markStarted(
      responsibilityId: responsibilityId,
      actualStartAt: finalDate,
      source: source,
    );

    // Obliga a que se dibuje el SnackBar después de que el modal haya desaparecido por completo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Inicio registrado'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'DESHACER',
            onPressed: () => service.undoStart(responsibilityId),
          ),
        ),
      );
    });
  }
}