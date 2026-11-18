import '../data/models.dart';

/// Corte de caja de un turno.
class ShiftCashSummary {
  const ShiftCashSummary({
    required this.openingCashCents,
    required this.cashSalesCents,
    required this.transferSalesCents,
    required this.cashExpensesCents,
    required this.cashInCents,
    required this.cashOutCents,
    required this.ordersCount,
    required this.cancelledCount,
  });

  final int openingCashCents;
  final int cashSalesCents;
  final int transferSalesCents;

  /// Gastos pagados con efectivo de la caja.
  final int cashExpensesCents;
  final int cashInCents;
  final int cashOutCents;
  final int ordersCount;
  final int cancelledCount;

  int get totalSalesCents => cashSalesCents + transferSalesCents;
  int get expectedCashCents => openingCashCents + cashSalesCents - cashExpensesCents + cashInCents - cashOutCents;
}

ShiftCashSummary summarizeShift({
  required Shift shift,
  required Iterable<Order> orders,
  required Iterable<Expense> expenses,
  required Iterable<CashMovement> movements,
}) {
  var cash = 0;
  var transfer = 0;
  var count = 0;
  var cancelled = 0;
  for (final o in orders.where((o) => o.shiftId == shift.id)) {
    if (o.status == OrderStatus.cancelada) cancelled++;
    if (o.status != OrderStatus.cobrada) continue;
    count++;
    for (final p in o.payments) {
      if (p.method == PaymentMethod.efectivo) {
        cash += p.amountCents;
      } else {
        transfer += p.amountCents;
      }
    }
  }
  final cashExpenses = expenses
      .where((e) => e.shiftId == shift.id && e.paidFromRegister && e.method == PaymentMethod.efectivo)
      .fold(0, (a, e) => a + e.amountCents);
  var cashIn = 0;
  var cashOut = 0;
  for (final m in movements.where((m) => m.shiftId == shift.id)) {
    if (m.type == CashMovementType.entrada) {
      cashIn += m.amountCents;
    } else {
      cashOut += m.amountCents;
    }
  }
  return ShiftCashSummary(
    openingCashCents: shift.openingCashCents,
    cashSalesCents: cash,
    transferSalesCents: transfer,
    cashExpensesCents: cashExpenses,
    cashInCents: cashIn,
    cashOutCents: cashOut,
    ordersCount: count,
    cancelledCount: cancelled,
  );
}
