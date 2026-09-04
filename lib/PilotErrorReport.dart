class PilotErrorReport {
  final String code;
  final String area;
  final String description;
  final String appVersion;
  final String platform;
  final DateTime createdAt;

  const PilotErrorReport({
    required this.code,
    required this.area,
    required this.description,
    required this.appVersion,
    required this.platform,
    required this.createdAt,
  });

  String toShareText() {
    final date = _formatDate(createdAt);

    return '''
BiPi · Reporte del piloto

Código: $code
Área: $area
Versión: $appVersion
Sistema: $platform
Fecha: $date

Descripción:
${description.trim()}
''';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];

    final hour = dt.hour == 0
        ? 12
        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'p.m.' : 'a.m.';

    return '${dt.day} ${months[dt.month - 1]}. ${dt.year}, '
        '$hour:$minute $period';
  }
}