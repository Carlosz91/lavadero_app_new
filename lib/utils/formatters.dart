import 'package:intl/intl.dart';

/// Formato de moneda (guaraníes) centralizado — un solo formato para toda la app.
final NumberFormat _gsFormat = NumberFormat.decimalPattern('es');
final NumberFormat _compactGsFormat = NumberFormat.compact(locale: 'es');

/// Formatea un monto como "Gs. 50.000".
String formatGs(num amount) => 'Gs. ${_gsFormat.format(amount.round())}';

/// Formatea cantidades grandes de forma compacta: "Gs. 1,2 M".
String formatGsCompact(num amount) => 'Gs. ${_compactGsFormat.format(amount)}';

/// Fecha corta para tarjetas: "22/10/2026".
String formatDate(dynamic date) {
  if (date == null || (date is String && date.isEmpty)) return '';
  try {
    final DateTime parsed;
    if (date is String) {
      parsed = DateTime.parse(date);
    } else if (date is DateTime) {
      parsed = date;
    } else {
      parsed = DateTime.parse(date.toString());
    }
    return DateFormat('dd/MM/yyyy').format(parsed);
  } catch (_) {
    return '';
  }
}

/// Validación de email compartida (una sola regla para todas las pantallas).
bool isValidEmail(String email) {
  final cleaned = email.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleaned);
}

/// Separador de miles sencillo para previews en tiempo real.
String thousandSep(int value) => _gsFormat.format(value);
