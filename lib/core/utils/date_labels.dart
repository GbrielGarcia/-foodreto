/// Fechas legibles en español sin depender de datos de localización.
abstract final class DateLabels {
  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// "septiembre 2026"
  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';

  /// "29 septiembre 2026"
  static String dayMonthYear(DateTime date) => '${date.day} ${monthYear(date)}';
}
