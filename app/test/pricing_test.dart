import 'package:flutter_test/flutter_test.dart';
import 'package:piolinpos/data/models.dart';
import 'package:piolinpos/domain/pricing.dart';

void main() {
  // Martes 17/11/2026 13:00
  final tuesday = DateTime(2026, 11, 17, 13, 0);

  Promotion promo2x1() => Promotion(
        id: 'p1',
        name: '2×1 refrescos',
        type: PromotionType.buyXGetY,
        buyQty: 1,
        freeQty: 1,
        products: {'refresco': 1},
      );

  group('descuento manual', () {
    test('redondea al peso', () {
      // $56 × 10 % = $5.60 → $6
      expect(manualDiscountCents(5600, 1000), 600);
      expect(manualDiscountCents(5600, 0), 0);
      expect(manualDiscountCents(0, 1000), 0);
    });

    test('nunca excede la base', () {
      expect(manualDiscountCents(1000, 10000), 1000);
    });
  });

  group('priceOrder', () {
    test('sin promociones ni descuento', () {
      final r = priceOrder(
        lines: const [PricedLine(productId: 'taco', unitCents: 1800, qty: 3)],
        promotions: const [],
        at: tuesday,
      );
      expect(r.subtotalCents, 5400);
      expect(r.promoDiscountCents, 0);
      expect(r.totalCents, 5400);
    });

    test('2×1 y descuento del 10 %', () {
      final r = priceOrder(
        lines: const [
          PricedLine(productId: 'taco', unitCents: 1800, qty: 2),
          PricedLine(productId: 'refresco', unitCents: 2000, qty: 2),
        ],
        promotions: [promo2x1()],
        at: tuesday,
        discountBp: 1000,
      );
      expect(r.subtotalCents, 7600);
      expect(r.promoDiscountCents, 2000);
      expect(r.appliedPromotions.single.timesApplied, 1);
      // ($76 − $20) = $56; 10 % = $5.60 → $6 → $50
      expect(r.discountCents, 600);
      expect(r.totalCents, 5000);
    });

    test('2×1 con número impar de piezas', () {
      final r = priceOrder(
        lines: const [PricedLine(productId: 'refresco', unitCents: 2000, qty: 3)],
        promotions: [promo2x1()],
        at: tuesday,
      );
      expect(r.promoDiscountCents, 2000);
      expect(r.totalCents, 4000);
    });

    test('porcentaje por producto', () {
      final promo = Promotion(
        id: 'p2',
        name: '20 % en gringas',
        type: PromotionType.percentOff,
        percentBp: 2000,
        products: {'gringa': 1},
      );
      final r = priceOrder(
        lines: const [
          PricedLine(productId: 'gringa', unitCents: 4500, qty: 2),
          PricedLine(productId: 'taco', unitCents: 1800, qty: 1),
        ],
        promotions: [promo],
        at: tuesday,
      );
      expect(r.promoDiscountCents, 1800);
      expect(r.totalCents, 9000 + 1800 - 1800);
    });

    test('combo a precio fijo', () {
      final promo = Promotion(
        id: 'p3',
        name: '3 pastor + refresco por \$60',
        type: PromotionType.fixedBundle,
        bundlePriceCents: 6000,
        products: {'taco': 3, 'refresco': 1},
      );
      final r = priceOrder(
        lines: const [
          PricedLine(productId: 'taco', unitCents: 1800, qty: 7),
          PricedLine(productId: 'refresco', unitCents: 2000, qty: 2),
        ],
        promotions: [promo],
        at: tuesday,
      );
      // Normal por combo: 3×18 + 20 = $74 → descuento $14 × 2 combos
      expect(r.appliedPromotions.single.timesApplied, 2);
      expect(r.promoDiscountCents, 2800);
    });

    test('cada pieza participa en una sola promoción', () {
      final pct = Promotion(
        id: 'p4',
        name: '50 % refrescos',
        type: PromotionType.percentOff,
        percentBp: 5000,
        products: {'refresco': 1},
      );
      final r = priceOrder(
        lines: const [PricedLine(productId: 'refresco', unitCents: 2000, qty: 2)],
        promotions: [promo2x1(), pct],
        at: tuesday,
      );
      expect(r.appliedPromotions.length, 1);
      expect(r.promoDiscountCents, 2000);
    });
  });

  group('vigencia', () {
    test('respeta días de la semana', () {
      final onlyTuesday = promo2x1()..weekdaysMask = 1 << 1;
      expect(promotionIsActiveAt(onlyTuesday, tuesday), isTrue);
      expect(promotionIsActiveAt(onlyTuesday, tuesday.add(const Duration(days: 1))), isFalse);
    });

    test('respeta fechas y horario', () {
      final p = promo2x1()
        ..startsOn = '2026-11-01'
        ..endsOn = '2026-11-30'
        ..startTime = '12:00'
        ..endTime = '14:00';
      expect(promotionIsActiveAt(p, tuesday), isTrue);
      expect(promotionIsActiveAt(p, DateTime(2026, 11, 17, 15, 0)), isFalse);
      expect(promotionIsActiveAt(p, DateTime(2026, 12, 1, 13, 0)), isFalse);
    });

    test('inactiva no aplica', () {
      final p = promo2x1()..active = false;
      final r = priceOrder(
        lines: const [PricedLine(productId: 'refresco', unitCents: 2000, qty: 2)],
        promotions: [p],
        at: tuesday,
      );
      expect(r.promoDiscountCents, 0);
    });
  });
}
