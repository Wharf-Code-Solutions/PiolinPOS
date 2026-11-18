const monthNames = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Día operativo local en formato 'YYYY-MM-DD'.
String businessDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Periodo mensual 'YYYY-MM'.
String periodOf(DateTime d) => '${d.year}-${_two(d.month)}';

String periodLabel(String period) {
  final parts = period.split('-');
  final month = int.parse(parts[1]);
  return '${monthNames[month - 1]} ${parts[0]}';
}

DateTime parseBusinessDate(String value) {
  final p = value.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// '18/11/2026 14:05'
String formatDateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

/// '14:05'
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatShortDate(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Instante ISO-8601 UTC para guardar en SQLite.
String isoNow() => DateTime.now().toUtc().toIso8601String();

String toIso(DateTime d) => d.toUtc().toIso8601String();

DateTime fromIso(String value) => DateTime.parse(value).toLocal();

DateTime? fromIsoOrNull(Object? value) => value == null ? null : fromIso(value as String);
