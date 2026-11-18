import 'package:flutter_test/flutter_test.dart';
import 'package:piolinpos/core/dates.dart';
import 'package:piolinpos/core/money.dart';

void main() {
  group('money', () {
    test('formatMoney', () {
      expect(formatMoney(8900), r'$89.00');
      expect(formatMoney(1248000), r'$12,480.00');
      expect(formatMoney(-2000), r'-$20.00');
      expect(formatMoney(500, showSign: true), r'+$5.00');
      expect(formatMoneyShort(1248000), r'$12,480');
    });

    test('parseMoney', () {
      expect(parseMoney('45'), 4500);
      expect(parseMoney('1,200.50'), 120050);
      expect(parseMoney(''), isNull);
    });
  });

  group('fechas', () {
    test('businessDate y periodo', () {
      final d = DateTime(2026, 3, 5, 23, 59);
      expect(businessDate(d), '2026-03-05');
      expect(periodOf(d), '2026-03');
      expect(periodLabel('2026-03'), 'Marzo 2026');
      expect(parseBusinessDate('2026-03-05'), DateTime(2026, 3, 5));
    });
  });
}
