/// Montos en centavos (int) para evitar errores de punto flotante.
String formatMoney(int cents, {bool showSign = false}) {
  final negative = cents < 0;
  final abs = cents.abs();
  final pesos = abs ~/ 100;
  final cent = (abs % 100).toString().padLeft(2, '0');
  final digits = pesos.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final sign = negative ? '-' : (showSign ? '+' : '');
  return '$sign\$$buf.$cent';
}

/// Igual que [formatMoney] pero sin centavos (p. ej. "$12,480").
String formatMoneyShort(int cents) {
  final full = formatMoney(cents);
  return full.substring(0, full.length - 3);
}

/// Convierte texto capturado ("45", "45.5", "1,200.00") a centavos.
int? parseMoney(String text) {
  final clean = text.replaceAll(RegExp(r'[^0-9.]'), '');
  if (clean.isEmpty) return null;
  final value = double.tryParse(clean);
  if (value == null) return null;
  return (value * 100).round();
}

/// "18.00" para campos de edición.
String centsToInput(int cents) => (cents / 100).toStringAsFixed(2);
