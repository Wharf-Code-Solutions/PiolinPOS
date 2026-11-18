import '../data/models.dart';

/// Línea mínima para calcular totales (independiente de Flutter y SQLite).
class PricedLine {
  const PricedLine({required this.productId, required this.unitCents, required this.qty});

  final String productId;

  /// Precio unitario incluyendo modificadores.
  final int unitCents;
  final int qty;
}

class PricingResult {
  const PricingResult({
    required this.subtotalCents,
    required this.promoDiscountCents,
    required this.appliedPromotions,
    required this.discountCents,
    required this.totalCents,
  });

  final int subtotalCents;
  final int promoDiscountCents;
  final List<AppliedPromotion> appliedPromotions;
  final int discountCents;
  final int totalCents;
}

/// ¿La promoción está vigente en [at]?
bool promotionIsActiveAt(Promotion p, DateTime at) {
  if (!p.active) return false;
  final day = _dateKey(at);
  if (p.startsOn != null && day.compareTo(p.startsOn!) < 0) return false;
  if (p.endsOn != null && day.compareTo(p.endsOn!) > 0) return false;
  final bit = 1 << (at.weekday - 1);
  if (p.weekdaysMask & bit == 0) return false;
  final hhmm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  if (p.startTime != null && hhmm.compareTo(p.startTime!) < 0) return false;
  if (p.endTime != null && hhmm.compareTo(p.endTime!) > 0) return false;
  return true;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Descuento manual (R3) redondeado al peso, igual que en caja.
int manualDiscountCents(int baseCents, int discountBp) {
  if (discountBp <= 0 || baseCents <= 0) return 0;
  final cents = (baseCents * discountBp / 10000 / 100).round() * 100;
  return cents > baseCents ? baseCents : cents;
}

/// Calcula subtotal, promociones automáticas, descuento manual y total.
///
/// Las promociones se aplican en orden y cada pieza solo participa en una.
PricingResult priceOrder({
  required List<PricedLine> lines,
  required List<Promotion> promotions,
  required DateTime at,
  int discountBp = 0,
}) {
  final subtotal = lines.fold(0, (a, l) => a + l.unitCents * l.qty);

  // Piezas restantes por producto, con su precio unitario más bajo.
  final remaining = <String, int>{};
  final cheapest = <String, int>{};
  final grossByProduct = <String, int>{};
  final qtyByProduct = <String, int>{};
  for (final l in lines) {
    if (l.qty <= 0) continue;
    remaining[l.productId] = (remaining[l.productId] ?? 0) + l.qty;
    qtyByProduct[l.productId] = (qtyByProduct[l.productId] ?? 0) + l.qty;
    grossByProduct[l.productId] = (grossByProduct[l.productId] ?? 0) + l.unitCents * l.qty;
    final c = cheapest[l.productId];
    if (c == null || l.unitCents < c) cheapest[l.productId] = l.unitCents;
  }
  int avgUnit(String id) => (grossByProduct[id]! / qtyByProduct[id]!).round();

  final applied = <AppliedPromotion>[];
  for (final promo in promotions) {
    if (!promotionIsActiveAt(promo, at) || promo.products.isEmpty) continue;
    var discount = 0;
    var times = 0;
    switch (promo.type) {
      case PromotionType.buyXGetY:
        final buy = promo.buyQty ?? 0;
        final free = promo.freeQty ?? 0;
        if (buy <= 0 || free <= 0) break;
        for (final id in promo.products.keys) {
          final qty = remaining[id] ?? 0;
          final groups = qty ~/ (buy + free);
          if (groups == 0) continue;
          discount += groups * free * cheapest[id]!;
          times += groups;
          remaining[id] = qty - groups * (buy + free);
        }
      case PromotionType.percentOff:
        final bp = promo.percentBp ?? 0;
        if (bp <= 0) break;
        for (final id in promo.products.keys) {
          final qty = remaining[id] ?? 0;
          if (qty == 0) continue;
          discount += (avgUnit(id) * qty * bp / 10000).round();
          times += qty;
          remaining[id] = 0;
        }
      case PromotionType.fixedBundle:
        final price = promo.bundlePriceCents;
        if (price == null) break;
        var possible = -1;
        for (final entry in promo.products.entries) {
          final have = remaining[entry.key] ?? 0;
          final n = have ~/ entry.value;
          possible = possible < 0 ? n : (n < possible ? n : possible);
        }
        if (possible <= 0) break;
        final normal = promo.products.entries.fold(0, (a, e) => a + e.value * cheapest[e.key]!);
        if (normal <= price) break;
        discount = possible * (normal - price);
        times = possible;
        for (final entry in promo.products.entries) {
          remaining[entry.key] = remaining[entry.key]! - possible * entry.value;
        }
    }
    if (discount > 0) {
      applied.add(AppliedPromotion(
        promotionId: promo.id,
        name: promo.name,
        timesApplied: times,
        discountCents: discount,
      ));
    }
  }

  var promoDiscount = applied.fold(0, (a, p) => a + p.discountCents);
  if (promoDiscount > subtotal) promoDiscount = subtotal;
  final base = subtotal - promoDiscount;
  final discount = manualDiscountCents(base, discountBp);
  return PricingResult(
    subtotalCents: subtotal,
    promoDiscountCents: promoDiscount,
    appliedPromotions: applied,
    discountCents: discount,
    totalCents: base - discount,
  );
}

List<PricedLine> pricedLinesOf(Order order) => [
      for (final l in order.lines) PricedLine(productId: l.productId, unitCents: l.unitCents, qty: l.qty),
    ];
