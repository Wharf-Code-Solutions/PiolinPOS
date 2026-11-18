part of '../pos_store.dart';

extension PosStoreInventory on PosStore {
  List<InventoryItem> get activeInventory => inventory.where((i) => i.active).toList();

  int get criticalCount => inventory.where((i) => i.active && i.isLow).length;

  List<InventoryItem> get lowStockItems => inventory.where((i) => i.active && i.isLow).toList();

  InventoryItem? inventoryItemById(String? id) {
    if (id == null) return null;
    for (final i in inventory) {
      if (i.id == id) return i;
    }
    return null;
  }

  InventoryItem? inventoryItemByBarcode(String code) {
    for (final i in inventory) {
      if (i.active && i.barcode == code) return i;
    }
    return null;
  }

  Supplier? supplierById(String? id) {
    if (id == null) return null;
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Supplier> get activeSuppliers => suppliers.where((s) => s.active).toList();

  ExpenseCategory? expenseCategoryById(String id) {
    for (final c in expenseCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<ExpenseCategory> get activeExpenseCategories => expenseCategories.where((c) => c.active).toList();

  Future<void> saveInventoryItem(InventoryItem item, {int initialStockMilli = 0}) async {
    if (item.barcode != null && item.barcode!.isNotEmpty) {
      final other = inventoryItemByBarcode(item.barcode!);
      if (other != null && other.id != item.id) {
        throw PosException('El código de barras ya está asignado a ${other.name}');
      }
    }
    await repo.saveInventoryItem(item, initialStockMilli: initialStockMilli);
    await _reloadInventory();
    _changed();
  }

  /// Ajuste manual (+/−) o merma; queda en el libro de movimientos.
  Future<void> adjustStock(InventoryItem item, int deltaMilli, {MovementType type = MovementType.adjustment, String? note}) async {
    if (deltaMilli == 0) return;
    await repo.addMovement(item.id, type, deltaMilli, note: note);
    await _reloadInventory();
    _changed();
  }

  /// Conteo físico: [counted] = insumo → cantidad contada en milésimas.
  Future<void> applyStockCount(Map<InventoryItem, int> counted, {String? notes}) async {
    if (counted.isEmpty) return;
    await repo.applyStockCount(counted, notes: notes);
    await _reloadInventory();
    _changed();
  }

  Future<void> saveSupplier(Supplier s) async {
    await repo.saveSupplier(s);
    if (!suppliers.any((e) => e.id == s.id)) suppliers.add(s);
    suppliers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _changed();
  }

  Future<void> saveExpenseCategory(ExpenseCategory c) async {
    await repo.saveExpenseCategory(c);
    if (!expenseCategories.any((e) => e.id == c.id)) expenseCategories.add(c);
    _changed();
  }

  /// Registra un gasto o una compra (con líneas de insumo opcionales).
  Future<Expense> recordExpense({
    required String categoryId,
    required int amountCents,
    required PaymentMethod method,
    required bool paidFromRegister,
    String description = '',
    String? supplierId,
    List<PurchaseLine> lines = const [],
  }) async {
    if (amountCents <= 0) throw const PosException('Captura un monto mayor a cero');
    final shift = openShift;
    if (paidFromRegister && shift == null) {
      throw const PosException('Para pagar desde la caja debe haber un turno abierto');
    }
    final now = DateTime.now();
    final expense = Expense(
      id: newId(),
      businessDate: shift?.businessDate ?? businessDate(now),
      shiftId: shift?.id,
      categoryId: categoryId,
      supplierId: supplierId,
      amountCents: amountCents,
      method: method,
      paidFromRegister: paidFromRegister,
      description: description.trim(),
      createdAt: now,
    );
    await repo.insertExpense(expense, lines: lines);
    if (shift != null) shiftExpenses.insert(0, expense);
    if (lines.any((l) => l.inventoryItemId != null)) await _reloadInventory();
    _changed();
    return expense;
  }

  Future<void> deleteExpense(Expense e) async {
    await repo.deleteExpense(e.id);
    shiftExpenses.removeWhere((x) => x.id == e.id);
    _changed();
  }
}
