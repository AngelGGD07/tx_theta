import 'dart:async';
import 'package:flutter/material.dart';
import 'Responsibility.dart';
import 'ResponsibilityService.dart';

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
  Timer? _undoTimer;
  bool _showUndo = false;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  Future<void> _markStarted() async {
    await widget.service.markStarted(
      responsibilityId: widget.responsibility.id,
      actualStartAt: DateTime.now(),
      source: StartSource.manualLive,
    );
    setState(() => _showUndo = true);
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _showUndo = false);
    });
  }

  Future<void> _undo() async {
    _undoTimer?.cancel();
    await widget.service.undoStart(widget.responsibility.id);
    if (mounted) setState(() => _showUndo = false);
  }

  Future<void> _markStartedInThePast() async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Hoy, más temprano'),
              onTap: () => Navigator.pop(
                  ctx, DateTime(now.year, now.month, now.day, 9)),
            ),
            ListTile(
              title: const Text('Ayer'),
              onTap: () {
                final yesterday = now.subtract(const Duration(days: 1));
                Navigator.pop(ctx, DateTime(yesterday.year, yesterday.month,
                    yesterday.day, 19));
              },
            ),
            ListTile(
              title: const Text('Elegir fecha y hora'),
              onTap: () async {
                Navigator.pop(ctx);
                final date = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now.subtract(const Duration(days: 60)),
                  lastDate: now,
                );
                if (date == null) return;
                if (!mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                await widget.service.markStarted(
                  responsibilityId: widget.responsibility.id,
                  actualStartAt: DateTime(date.year, date.month, date.day,
                      time.hour, time.minute),
                  source: StartSource.manualRecalled,
                );
              },
            ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await widget.service.markStarted(
        responsibilityId: widget.responsibility.id,
        actualStartAt: choice,
        source: StartSource.manualRecalled,
      );
    }
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

            if (_showUndo)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _undo,
                  child: const Text('Deshacer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Confrontación individual: un hecho, no un patrón. Sin promedios,
  /// sin "detectamos" — eso queda prohibido hasta juntar más muestras.
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
      message = 'Empezaste prácticamente cuando lo habías previsto.';
    } else if (absHours < 24) {
      final h = absHours.round();
      message = late
          ? 'Comenzaste $h ${h == 1 ? 'hora' : 'horas'} después de lo previsto.'
          : 'Comenzaste $h ${h == 1 ? 'hora' : 'horas'} antes de lo previsto.';
    } else {
      final d = (absHours / 24).round();
      message = late
          ? 'Comenzaste $d ${d == 1 ? 'día' : 'días'} después de lo previsto.'
          : 'Comenzaste $d ${d == 1 ? 'día' : 'días'} antes de lo previsto.';
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