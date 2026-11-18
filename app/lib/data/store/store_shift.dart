part of '../pos_store.dart';

extension PosStoreShift on PosStore {
  bool get hasOpenShift => openShift != null;

  ShiftCashSummary? get shiftSummary {
    final shift = openShift;
    if (shift == null) return null;
    return summarizeShift(shift: shift, orders: orders, expenses: shiftExpenses, movements: shiftMovements);
  }

  Future<void> openNewShift(int openingCashCents) async {
    if (openShift != null) throw const PosException('Ya hay un turno abierto');
    if (openingCashCents < 0) throw const PosException('El fondo no puede ser negativo');
    final now = DateTime.now();
    final shift = Shift(
      id: newId(),
      businessDate: businessDate(now),
      openingCashCents: openingCashCents,
      openedAt: now,
    );
    await repo.insertShift(shift);
    await _loadShiftState();
    _changed();
  }

  Future<void> addCashMovement(CashMovementType type, int amountCents, String reason) async {
    final shift = openShift;
    if (shift == null) throw const PosException('No hay turno abierto');
    if (amountCents <= 0) throw const PosException('Captura un monto mayor a cero');
    if (reason.trim().isEmpty) throw const PosException('Indica el motivo');
    final m = CashMovement(
      id: newId(),
      shiftId: shift.id,
      type: type,
      amountCents: amountCents,
      reason: reason.trim(),
      createdAt: DateTime.now(),
    );
    await repo.insertCashMovement(m);
    shiftMovements.add(m);
    _changed();
  }

  /// Corte de caja. Las cuentas abiertas pasan al siguiente turno.
  Future<Shift> closeCurrentShift({required int countedCashCents, String? notes}) async {
    final shift = openShift;
    if (shift == null) throw const PosException('No hay turno abierto');
    final summary = shiftSummary!;
    shift
      ..status = ShiftStatus.cerrado
      ..expectedCashCents = summary.expectedCashCents
      ..countedCashCents = countedCashCents
      ..differenceCents = countedCashCents - summary.expectedCashCents
      ..notes = (notes == null || notes.trim().isEmpty) ? null : notes.trim()
      ..closedAt = DateTime.now();
    await repo.closeShift(shift);
    await _loadShiftState();
    _changed();
    return shift;
  }

  Future<List<Shift>> recentShifts() => repo.loadRecentShifts();
}
