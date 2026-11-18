import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/dates.dart';
import '../../core/ids.dart';
import '../models.dart';

int _b(bool v) => v ? 1 : 0;
bool _bool(Object? v) => (v as int? ?? 0) == 1;

/// Acceso a SQLite. Sin estado: el [PosStore] decide qué mantener en memoria.
class PosRepository {
  PosRepository(this.db);

  final Database db;

  // ===================================================================
  // Configuración
  // ===================================================================

  Future<Map<String, String>> loadSettings() async {
    final rows = await db.query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  Future<void> setSetting(String key, String value) =>
      db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> audit(DatabaseExecutor ex, String entity, String entityId, String action, [Map<String, Object?>? payload]) =>
      ex.insert('audit_log', {
        'id': newId(),
        'entity': entity,
        'entity_id': entityId,
        'action': action,
        'payload_json': payload == null ? null : jsonEncode(payload),
        'created_at': isoNow(),
      });

  // ===================================================================
  // Catálogo
  // ===================================================================

  Future<List<MenuCategory>> loadCategories() async {
    final rows = await db.query('categories', orderBy: 'sort_order, name');
    return [
      for (final r in rows)
        MenuCategory(
          id: r['id'] as String,
          name: r['name'] as String,
          iconKey: r['icon'] as String,
          kind: r['kind'] == 'inventario' ? CategoryKind.inventario : CategoryKind.menu,
          sortOrder: r['sort_order'] as int,
          active: _bool(r['active']),
        ),
    ];
  }

  Future<void> saveCategory(MenuCategory c) async {
    final now = isoNow();
    final values = {
      'name': c.name,
      'icon': c.iconKey,
      'kind': c.kind == CategoryKind.inventario ? 'inventario' : 'menu',
      'sort_order': c.sortOrder,
      'active': _b(c.active),
      'updated_at': now,
    };
    final n = await db.update('categories', values, where: 'id = ?', whereArgs: [c.id]);
    if (n == 0) await db.insert('categories', {...values, 'id': c.id, 'created_at': now});
  }

  Future<List<Product>> loadProducts() async {
    final rows = await db.query('products', orderBy: 'sort_order, name');
    final links = await db.query('product_modifier_groups', orderBy: 'sort_order');
    final groupsByProduct = <String, List<String>>{};
    for (final l in links) {
      groupsByProduct.putIfAbsent(l['product_id'] as String, () => []).add(l['group_id'] as String);
    }
    return [
      for (final r in rows)
        Product(
          id: r['id'] as String,
          categoryId: r['category_id'] as String,
          name: r['name'] as String,
          description: r['description'] as String,
          priceCents: r['price_cents'] as int,
          barcode: r['barcode'] as String?,
          icon: ProductIcon.fromName(r['icon'] as String?),
          notePlaceholder: r['note_placeholder'] as String,
          favorite: _bool(r['favorite']),
          available: _bool(r['available']),
          active: _bool(r['active']),
          inventoryItemId: r['inventory_item_id'] as String?,
          consumeQtyMilli: r['consume_qty_milli'] as int,
          sortOrder: r['sort_order'] as int,
          modifierGroupIds: groupsByProduct[r['id']] ?? [],
        ),
    ];
  }

  Future<void> saveProduct(Product p, {int? previousPriceCents}) async {
    await db.transaction((tx) async {
      final now = isoNow();
      final values = {
        'category_id': p.categoryId,
        'name': p.name,
        'description': p.description,
        'price_cents': p.priceCents,
        'barcode': p.barcode,
        'icon': p.icon.name,
        'note_placeholder': p.notePlaceholder,
        'favorite': _b(p.favorite),
        'available': _b(p.available),
        'active': _b(p.active),
        'inventory_item_id': p.inventoryItemId,
        'consume_qty_milli': p.consumeQtyMilli,
        'sort_order': p.sortOrder,
        'updated_at': now,
      };
      final n = await tx.update('products', values, where: 'id = ?', whereArgs: [p.id]);
      if (n == 0) {
        await tx.insert('products', {...values, 'id': p.id, 'created_at': now});
      } else if (previousPriceCents != null && previousPriceCents != p.priceCents) {
        await tx.insert('product_price_history', {
          'id': newId(),
          'product_id': p.id,
          'old_price_cents': previousPriceCents,
          'new_price_cents': p.priceCents,
          'changed_at': now,
        });
        await audit(tx, 'product', p.id, 'PRICE_CHANGE', {'old': previousPriceCents, 'new': p.priceCents});
      }
      await tx.delete('product_modifier_groups', where: 'product_id = ?', whereArgs: [p.id]);
      for (var i = 0; i < p.modifierGroupIds.length; i++) {
        await tx.insert('product_modifier_groups', {
          'product_id': p.id,
          'group_id': p.modifierGroupIds[i],
          'sort_order': i,
        });
      }
    });
  }

  Future<int> countPriceChangesSince(DateTime since) async {
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM product_price_history WHERE changed_at >= ?', [toIso(since)]);
    return (r.first['n'] as int?) ?? 0;
  }

  Future<List<ModifierGroup>> loadModifierGroups() async {
    final groups = await db.query('modifier_groups', orderBy: 'name');
    final mods = await db.query('modifiers', orderBy: 'sort_order, name');
    final byGroup = <String, List<Modifier>>{};
    for (final m in mods) {
      byGroup.putIfAbsent(m['group_id'] as String, () => []).add(Modifier(
            id: m['id'] as String,
            groupId: m['group_id'] as String,
            name: m['name'] as String,
            priceDeltaCents: m['price_delta_cents'] as int,
            isDefault: _bool(m['is_default']),
            sortOrder: m['sort_order'] as int,
            active: _bool(m['active']),
          ));
    }
    return [
      for (final g in groups)
        ModifierGroup(
          id: g['id'] as String,
          name: g['name'] as String,
          minSelect: g['min_select'] as int,
          maxSelect: g['max_select'] as int,
          active: _bool(g['active']),
          modifiers: byGroup[g['id']] ?? [],
        ),
    ];
  }

  Future<void> saveModifierGroup(ModifierGroup g) async {
    await db.transaction((tx) async {
      final now = isoNow();
      final values = {
        'name': g.name,
        'min_select': g.minSelect,
        'max_select': g.maxSelect,
        'active': _b(g.active),
        'updated_at': now,
      };
      final n = await tx.update('modifier_groups', values, where: 'id = ?', whereArgs: [g.id]);
      if (n == 0) await tx.insert('modifier_groups', {...values, 'id': g.id, 'created_at': now});
      for (var i = 0; i < g.modifiers.length; i++) {
        final m = g.modifiers[i]..sortOrder = i;
        final mv = {
          'group_id': g.id,
          'name': m.name,
          'price_delta_cents': m.priceDeltaCents,
          'is_default': _b(m.isDefault),
          'sort_order': m.sortOrder,
          'active': _b(m.active),
          'updated_at': now,
        };
        final mn = await tx.update('modifiers', mv, where: 'id = ?', whereArgs: [m.id]);
        if (mn == 0) await tx.insert('modifiers', {...mv, 'id': m.id, 'created_at': now});
      }
    });
  }

  Future<List<Promotion>> loadPromotions() async {
    final rows = await db.query('promotions', orderBy: 'created_at');
    final links = await db.query('promotion_products');
    final byPromo = <String, Map<String, int>>{};
    for (final l in links) {
      byPromo.putIfAbsent(l['promotion_id'] as String, () => {})[l['product_id'] as String] =
          l['required_qty'] as int;
    }
    return [
      for (final r in rows)
        Promotion(
          id: r['id'] as String,
          name: r['name'] as String,
          type: PromotionType.fromCode(r['type'] as String),
          percentBp: r['percent_bp'] as int?,
          bundlePriceCents: r['bundle_price_cents'] as int?,
          buyQty: r['buy_qty'] as int?,
          freeQty: r['free_qty'] as int?,
          startsOn: r['starts_on'] as String?,
          endsOn: r['ends_on'] as String?,
          weekdaysMask: r['weekdays_mask'] as int,
          startTime: r['start_time'] as String?,
          endTime: r['end_time'] as String?,
          active: _bool(r['active']),
          products: byPromo[r['id']] ?? {},
        ),
    ];
  }

  Future<void> savePromotion(Promotion p) async {
    await db.transaction((tx) async {
      final now = isoNow();
      final values = {
        'name': p.name,
        'type': p.type.code,
        'percent_bp': p.percentBp,
        'bundle_price_cents': p.bundlePriceCents,
        'buy_qty': p.buyQty,
        'free_qty': p.freeQty,
        'starts_on': p.startsOn,
        'ends_on': p.endsOn,
        'weekdays_mask': p.weekdaysMask,
        'start_time': p.startTime,
        'end_time': p.endTime,
        'active': _b(p.active),
        'updated_at': now,
      };
      final n = await tx.update('promotions', values, where: 'id = ?', whereArgs: [p.id]);
      if (n == 0) await tx.insert('promotions', {...values, 'id': p.id, 'created_at': now});
      await tx.delete('promotion_products', where: 'promotion_id = ?', whereArgs: [p.id]);
      for (final e in p.products.entries) {
        await tx.insert('promotion_products', {'promotion_id': p.id, 'product_id': e.key, 'required_qty': e.value});
      }
    });
  }

  // ===================================================================
  // Inventario y proveedores
  // ===================================================================

  Future<List<Supplier>> loadSuppliers() async {
    final rows = await db.query('suppliers', orderBy: 'name');
    return [
      for (final r in rows)
        Supplier(
          id: r['id'] as String,
          name: r['name'] as String,
          phone: r['phone'] as String?,
          notes: r['notes'] as String?,
          active: _bool(r['active']),
        ),
    ];
  }

  Future<void> saveSupplier(Supplier s) async {
    final now = isoNow();
    final values = {'name': s.name, 'phone': s.phone, 'notes': s.notes, 'active': _b(s.active), 'updated_at': now};
    final n = await db.update('suppliers', values, where: 'id = ?', whereArgs: [s.id]);
    if (n == 0) await db.insert('suppliers', {...values, 'id': s.id, 'created_at': now});
  }

  Future<List<InventoryItem>> loadInventoryItems() async {
    final rows = await db.query('inventory_items', orderBy: 'name');
    return [
      for (final r in rows)
        InventoryItem(
          id: r['id'] as String,
          name: r['name'] as String,
          categoryId: r['category_id'] as String,
          unit: InventoryUnit.fromCode(r['unit'] as String),
          barcode: r['barcode'] as String?,
          toleranceBp: r['tolerance_bp'] as int,
          minStockMilli: r['min_stock_milli'] as int,
          stockMilli: r['current_stock_milli'] as int,
          lastUnitCostCents: r['last_unit_cost_cents'] as int?,
          supplierId: r['default_supplier_id'] as String?,
          location: r['location'] as String,
          active: _bool(r['active']),
        ),
    ];
  }

  /// Guarda datos del insumo. El stock solo cambia con movimientos.
  Future<void> saveInventoryItem(InventoryItem i, {int initialStockMilli = 0}) async {
    await db.transaction((tx) async {
      final now = isoNow();
      final values = {
        'name': i.name,
        'category_id': i.categoryId,
        'unit': i.unit.code,
        'barcode': i.barcode,
        'tolerance_bp': i.toleranceBp,
        'min_stock_milli': i.minStockMilli,
        'last_unit_cost_cents': i.lastUnitCostCents,
        'default_supplier_id': i.supplierId,
        'location': i.location,
        'active': _b(i.active),
        'updated_at': now,
      };
      final n = await tx.update('inventory_items', values, where: 'id = ?', whereArgs: [i.id]);
      if (n == 0) {
        await tx.insert('inventory_items', {...values, 'id': i.id, 'current_stock_milli': 0, 'created_at': now});
        if (initialStockMilli != 0) {
          await _movement(tx, i.id, MovementType.initial, initialStockMilli, note: 'Alta del insumo');
        }
      }
    });
  }

  Future<void> _movement(
    DatabaseExecutor ex,
    String itemId,
    MovementType type,
    int qtyMilli, {
    String? note,
    int? unitCostCents,
    String? orderItemId,
    String? purchaseItemId,
    String? stockCountId,
  }) async {
    if (qtyMilli == 0) return;
    await ex.insert('inventory_movements', {
      'id': newId(),
      'inventory_item_id': itemId,
      'type': type.code,
      'qty_milli': qtyMilli,
      'unit_cost_cents': unitCostCents,
      'order_item_id': orderItemId,
      'purchase_item_id': purchaseItemId,
      'stock_count_id': stockCountId,
      'note': note,
      'created_at': isoNow(),
    });
  }

  Future<void> addMovement(String itemId, MovementType type, int qtyMilli, {String? note}) =>
      _movement(db, itemId, type, qtyMilli, note: note);

  Future<List<InventoryMovement>> loadMovements(String itemId, {int limit = 30}) async {
    final rows = await db.query('inventory_movements',
        where: 'inventory_item_id = ?', whereArgs: [itemId], orderBy: 'created_at DESC', limit: limit);
    return [
      for (final r in rows)
        InventoryMovement(
          id: r['id'] as String,
          itemId: itemId,
          type: MovementType.fromCode(r['type'] as String),
          qtyMilli: r['qty_milli'] as int,
          note: r['note'] as String?,
          createdAt: fromIso(r['created_at'] as String),
        ),
    ];
  }

  /// Conteo físico: genera ADJUSTMENT por la diferencia de cada insumo contado.
  Future<void> applyStockCount(Map<InventoryItem, int> counted, {String? notes}) async {
    await db.transaction((tx) async {
      final countId = newId();
      await tx.insert('stock_counts', {'id': countId, 'notes': notes, 'created_at': isoNow()});
      for (final e in counted.entries) {
        final item = e.key;
        final expected = item.stockMilli;
        final diff = e.value - expected;
        final tolerance = (expected.abs() * item.toleranceBp / 10000).round();
        await tx.insert('stock_count_lines', {
          'id': newId(),
          'stock_count_id': countId,
          'inventory_item_id': item.id,
          'expected_milli': expected,
          'counted_milli': e.value,
          'within_tolerance': _b(diff.abs() <= tolerance),
        });
        await _movement(tx, item.id, MovementType.adjustment, diff, note: 'Conteo físico', stockCountId: countId);
      }
    });
  }

  Future<List<ExpenseCategory>> loadExpenseCategories() async {
    final rows = await db.query('expense_categories', orderBy: 'kind, name');
    return [
      for (final r in rows)
        ExpenseCategory(
          id: r['id'] as String,
          name: r['name'] as String,
          kind: ExpenseKind.fromCode(r['kind'] as String),
          wasteBp: r['waste_bp'] as int,
          active: _bool(r['active']),
        ),
    ];
  }

  Future<void> saveExpenseCategory(ExpenseCategory c) async {
    final now = isoNow();
    final values = {'name': c.name, 'kind': c.kind.code, 'waste_bp': c.wasteBp, 'active': _b(c.active), 'updated_at': now};
    final n = await db.update('expense_categories', values, where: 'id = ?', whereArgs: [c.id]);
    if (n == 0) await db.insert('expense_categories', {...values, 'id': c.id, 'created_at': now});
  }

  Expense _expenseFrom(Map<String, Object?> r) => Expense(
        id: r['id'] as String,
        businessDate: r['business_date'] as String,
        shiftId: r['shift_id'] as String?,
        categoryId: r['category_id'] as String,
        supplierId: r['supplier_id'] as String?,
        amountCents: r['amount_cents'] as int,
        method: PaymentMethod.fromCode(r['payment_method'] as String),
        paidFromRegister: _bool(r['paid_from_register']),
        description: r['description'] as String,
        createdAt: fromIso(r['created_at'] as String),
      );

  Future<List<Expense>> loadExpenses({String? shiftId, String? fromDate, String? toDate, int? limit}) async {
    final where = <String>['deleted_at IS NULL'];
    final args = <Object?>[];
    if (shiftId != null) {
      where.add('shift_id = ?');
      args.add(shiftId);
    }
    if (fromDate != null) {
      where.add('business_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      where.add('business_date <= ?');
      args.add(toDate);
    }
    final rows = await db.query('expenses',
        where: where.join(' AND '), whereArgs: args, orderBy: 'created_at DESC', limit: limit);
    return rows.map(_expenseFrom).toList();
  }

  /// Gasto o compra. Las líneas con insumo generan un movimiento PURCHASE.
  Future<void> insertExpense(Expense e, {List<PurchaseLine> lines = const []}) async {
    await db.transaction((tx) async {
      await tx.insert('expenses', {
        'id': e.id,
        'business_date': e.businessDate,
        'shift_id': e.shiftId,
        'category_id': e.categoryId,
        'supplier_id': e.supplierId,
        'amount_cents': e.amountCents,
        'payment_method': e.method.code,
        'paid_from_register': _b(e.paidFromRegister),
        'description': e.description,
        'created_at': toIso(e.createdAt),
      });
      for (final l in lines) {
        final lineId = newId();
        await tx.insert('purchase_items', {
          'id': lineId,
          'expense_id': e.id,
          'inventory_item_id': l.inventoryItemId,
          'description': l.description,
          'qty_milli': l.qtyMilli,
          'total_cents': l.totalCents,
          'created_at': isoNow(),
        });
        if (l.inventoryItemId != null) {
          final unitCost = (l.totalCents * 1000 / l.qtyMilli).round();
          await _movement(tx, l.inventoryItemId!, MovementType.purchase, l.qtyMilli,
              unitCostCents: unitCost, purchaseItemId: lineId, note: e.description);
          await tx.update('inventory_items', {'last_unit_cost_cents': unitCost, 'updated_at': isoNow()},
              where: 'id = ?', whereArgs: [l.inventoryItemId]);
        }
      }
    });
  }

  Future<void> deleteExpense(String id) async {
    await db.update('expenses', {'deleted_at': isoNow()}, where: 'id = ?', whereArgs: [id]);
    await audit(db, 'expense', id, 'DELETE');
  }

  // ===================================================================
  // Turnos y caja
  // ===================================================================

  Shift _shiftFrom(Map<String, Object?> r) => Shift(
        id: r['id'] as String,
        businessDate: r['business_date'] as String,
        status: r['status'] == 'OPEN' ? ShiftStatus.abierto : ShiftStatus.cerrado,
        openingCashCents: r['opening_cash_cents'] as int,
        expectedCashCents: r['expected_cash_cents'] as int?,
        countedCashCents: r['counted_cash_cents'] as int?,
        differenceCents: r['difference_cents'] as int?,
        notes: r['notes'] as String?,
        openedAt: fromIso(r['opened_at'] as String),
        closedAt: fromIsoOrNull(r['closed_at']),
      );

  Future<Shift?> loadOpenShift() async {
    final rows = await db.query('shifts', where: "status = 'OPEN'", limit: 1);
    return rows.isEmpty ? null : _shiftFrom(rows.first);
  }

  Future<List<Shift>> loadRecentShifts({int limit = 15}) async {
    final rows = await db.query('shifts', orderBy: 'opened_at DESC', limit: limit);
    return rows.map(_shiftFrom).toList();
  }

  Future<void> insertShift(Shift s) => db.insert('shifts', {
        'id': s.id,
        'business_date': s.businessDate,
        'status': 'OPEN',
        'opening_cash_cents': s.openingCashCents,
        'opened_at': toIso(s.openedAt),
      });

  Future<void> closeShift(Shift s) => db.update(
        'shifts',
        {
          'status': 'CLOSED',
          'expected_cash_cents': s.expectedCashCents,
          'counted_cash_cents': s.countedCashCents,
          'difference_cents': s.differenceCents,
          'notes': s.notes,
          'closed_at': toIso(s.closedAt ?? DateTime.now()),
        },
        where: 'id = ?',
        whereArgs: [s.id],
      );

  Future<List<CashMovement>> loadCashMovements(String shiftId) async {
    final rows = await db.query('cash_movements', where: 'shift_id = ?', whereArgs: [shiftId], orderBy: 'created_at');
    return [
      for (final r in rows)
        CashMovement(
          id: r['id'] as String,
          shiftId: shiftId,
          type: r['type'] == 'IN' ? CashMovementType.entrada : CashMovementType.salida,
          amountCents: r['amount_cents'] as int,
          reason: r['reason'] as String,
          createdAt: fromIso(r['created_at'] as String),
        ),
    ];
  }

  Future<void> insertCashMovement(CashMovement m) => db.insert('cash_movements', {
        'id': m.id,
        'shift_id': m.shiftId,
        'type': m.type == CashMovementType.entrada ? 'IN' : 'OUT',
        'amount_cents': m.amountCents,
        'reason': m.reason,
        'created_at': toIso(m.createdAt),
      });

  // ===================================================================
  // Pedidos
  // ===================================================================

  Future<int> nextFolio(String businessDate) async {
    final r = await db.rawQuery('SELECT MAX(folio) AS m FROM orders WHERE business_date = ?', [businessDate]);
    return ((r.first['m'] as int?) ?? 0) + 1;
  }

  /// Carga pedidos completos (líneas, modificadores, rondas, pagos y promociones).
  Future<List<Order>> loadOrders(String where, List<Object?> args, {String orderBy = 'opened_at DESC'}) async {
    final rows = await db.query('orders', where: where, whereArgs: args, orderBy: orderBy);
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final ph = List.filled(ids.length, '?').join(',');

    final items = await db.rawQuery(
        "SELECT * FROM order_items WHERE order_id IN ($ph) AND status = 'ACTIVE' ORDER BY created_at", ids);
    final itemIds = items.map((r) => r['id'] as String).toList();
    final modsByItem = <String, List<SelectedModifier>>{};
    if (itemIds.isNotEmpty) {
      final mph = List.filled(itemIds.length, '?').join(',');
      final mods = await db.rawQuery('SELECT * FROM order_item_modifiers WHERE order_item_id IN ($mph)', itemIds);
      for (final m in mods) {
        modsByItem.putIfAbsent(m['order_item_id'] as String, () => []).add(SelectedModifier(
              modifierId: m['modifier_id'] as String,
              name: m['modifier_name'] as String,
              priceDeltaCents: m['price_delta_cents'] as int,
            ));
      }
    }
    final rounds = await db.rawQuery('SELECT * FROM order_rounds WHERE order_id IN ($ph) ORDER BY round_no', ids);
    final payments = await db.rawQuery('SELECT * FROM payments WHERE order_id IN ($ph) ORDER BY created_at', ids);
    final promos = await db.rawQuery('SELECT * FROM order_promotions WHERE order_id IN ($ph)', ids);

    final linesBy = <String, List<OrderLine>>{};
    for (final r in items) {
      linesBy.putIfAbsent(r['order_id'] as String, () => []).add(OrderLine(
            id: r['id'] as String,
            roundId: r['round_id'] as String,
            productId: r['product_id'] as String,
            name: r['product_name'] as String,
            unitPriceCents: r['unit_price_cents'] as int,
            modifiersCents: r['modifiers_cents'] as int,
            qty: r['qty'] as int,
            note: r['notes'] as String,
            modifiers: modsByItem[r['id']] ?? const [],
          ));
    }
    final roundsBy = <String, List<OrderRound>>{};
    for (final r in rounds) {
      roundsBy.putIfAbsent(r['order_id'] as String, () => []).add(OrderRound(
            id: r['id'] as String,
            roundNo: r['round_no'] as int,
            printStatus: PrintStatus.fromCode(r['print_status'] as String),
            createdAt: fromIso(r['created_at'] as String),
          ));
    }
    final paymentsBy = <String, List<Payment>>{};
    for (final r in payments) {
      paymentsBy.putIfAbsent(r['order_id'] as String, () => []).add(Payment(
            id: r['id'] as String,
            method: PaymentMethod.fromCode(r['method'] as String),
            amountCents: r['amount_cents'] as int,
            receivedCents: r['received_cents'] as int?,
            changeCents: r['change_cents'] as int?,
            reference: r['reference'] as String?,
            createdAt: fromIso(r['created_at'] as String),
          ));
    }
    final promosBy = <String, List<AppliedPromotion>>{};
    for (final r in promos) {
      promosBy.putIfAbsent(r['order_id'] as String, () => []).add(AppliedPromotion(
            promotionId: r['promotion_id'] as String,
            name: r['promotion_name'] as String,
            timesApplied: r['times_applied'] as int,
            discountCents: r['discount_cents'] as int,
          ));
    }

    return [
      for (final r in rows)
        Order(
          id: r['id'] as String,
          shiftId: r['shift_id'] as String,
          businessDate: r['business_date'] as String,
          folioNo: r['folio'] as int,
          customer: r['customer_name'] as String,
          channel: OrderChannel.fromCode(r['channel'] as String),
          destination: OrderDestination.fromCode(r['dining_option'] as String),
          status: OrderStatus.fromCode(r['status'] as String),
          createdAt: fromIso(r['opened_at'] as String),
          lines: linesBy[r['id']],
          rounds: roundsBy[r['id']],
          payments: paymentsBy[r['id']],
          appliedPromotions: promosBy[r['id']],
          discountBp: r['discount_bp'] as int,
          discountCents: r['discount_cents'] as int,
          discountReason: r['discount_reason'] as String?,
          promoDiscountCents: r['promo_discount_cents'] as int,
          totalCents: r['total_cents'] as int,
          paidAt: fromIsoOrNull(r['paid_at']),
          cancelledAt: fromIsoOrNull(r['cancelled_at']),
          cancelReason: r['cancel_reason'] as String?,
          mergedIntoId: r['merged_into_order_id'] as String?,
        ),
    ];
  }

  Future<void> _insertRound(DatabaseExecutor ex, String orderId, OrderRound round, List<OrderLine> lines) async {
    await ex.insert('order_rounds', {
      'id': round.id,
      'order_id': orderId,
      'round_no': round.roundNo,
      'print_status': round.printStatus.code,
      'created_at': toIso(round.createdAt),
    });
    for (final l in lines) {
      await ex.insert('order_items', {
        'id': l.id,
        'order_id': orderId,
        'round_id': round.id,
        'product_id': l.productId,
        'product_name': l.name,
        'unit_price_cents': l.unitPriceCents,
        'modifiers_cents': l.modifiersCents,
        'qty': l.qty,
        'notes': l.note,
        'created_at': toIso(round.createdAt),
      });
      for (final m in l.modifiers) {
        await ex.insert('order_item_modifiers', {
          'order_item_id': l.id,
          'modifier_id': m.modifierId,
          'modifier_name': m.name,
          'price_delta_cents': m.priceDeltaCents,
        });
      }
    }
    await ex.rawUpdate(
      'UPDATE orders SET subtotal_cents = (SELECT COALESCE(SUM((unit_price_cents + modifiers_cents) * qty), 0) '
      "FROM order_items WHERE order_id = ? AND status = 'ACTIVE'), updated_at = ? WHERE id = ?",
      [orderId, isoNow(), orderId],
    );
  }

  Future<void> insertOrder(Order o, OrderRound round, List<OrderLine> lines) async {
    await db.transaction((tx) async {
      await tx.insert('orders', {
        'id': o.id,
        'shift_id': o.shiftId,
        'business_date': o.businessDate,
        'folio': o.folioNo,
        'customer_name': o.customer,
        'channel': o.channel.code,
        'dining_option': o.destination.code,
        'status': 'OPEN',
        'opened_at': toIso(o.createdAt),
        'updated_at': isoNow(),
      });
      await _insertRound(tx, o.id, round, lines);
    });
  }

  /// R1: agrega una ronda nueva a una cuenta abierta.
  Future<void> addRound(String orderId, OrderRound round, List<OrderLine> lines) =>
      db.transaction((tx) => _insertRound(tx, orderId, round, lines));

  Future<void> updateOrderHeader(Order o) => db.update(
        'orders',
        {
          'customer_name': o.customer,
          'channel': o.channel.code,
          'dining_option': o.destination.code,
          'updated_at': isoNow(),
        },
        where: 'id = ?',
        whereArgs: [o.id],
      );

  Future<void> voidLine(String orderId, String lineId, String reason) async {
    await db.transaction((tx) async {
      await tx.update('order_items', {'status': 'VOIDED', 'void_reason': reason}, where: 'id = ?', whereArgs: [lineId]);
      await tx.rawUpdate(
        'UPDATE orders SET subtotal_cents = (SELECT COALESCE(SUM((unit_price_cents + modifiers_cents) * qty), 0) '
        "FROM order_items WHERE order_id = ? AND status = 'ACTIVE'), updated_at = ? WHERE id = ?",
        [orderId, isoNow(), orderId],
      );
      await audit(tx, 'order', orderId, 'VOID_ITEM', {'item': lineId, 'reason': reason});
    });
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await db.transaction((tx) async {
      final now = isoNow();
      await tx.update('orders', {'status': 'CANCELLED', 'cancel_reason': reason, 'cancelled_at': now, 'updated_at': now},
          where: 'id = ?', whereArgs: [orderId]);
      await audit(tx, 'order', orderId, 'CANCEL', {'reason': reason});
    });
  }

  /// R1: mueve las rondas y productos de [sourceId] a [targetId].
  Future<void> mergeOrders({required String targetId, required String sourceId}) async {
    await db.transaction((tx) async {
      final maxRow = await tx.rawQuery('SELECT COALESCE(MAX(round_no), 0) AS m FROM order_rounds WHERE order_id = ?', [targetId]);
      var next = (maxRow.first['m'] as int) + 1;
      final rounds = await tx.query('order_rounds', where: 'order_id = ?', whereArgs: [sourceId], orderBy: 'round_no');
      for (final r in rounds) {
        await tx.update('order_rounds', {'order_id': targetId, 'round_no': next++}, where: 'id = ?', whereArgs: [r['id']]);
      }
      await tx.update('order_items', {'order_id': targetId}, where: 'order_id = ?', whereArgs: [sourceId]);
      final now = isoNow();
      for (final id in [targetId, sourceId]) {
        await tx.rawUpdate(
          'UPDATE orders SET subtotal_cents = (SELECT COALESCE(SUM((unit_price_cents + modifiers_cents) * qty), 0) '
          "FROM order_items WHERE order_id = ? AND status = 'ACTIVE'), updated_at = ? WHERE id = ?",
          [id, now, id],
        );
      }
      await tx.update('orders', {'status': 'MERGED', 'merged_into_order_id': targetId, 'updated_at': now},
          where: 'id = ?', whereArgs: [sourceId]);
      await audit(tx, 'order', targetId, 'MERGE', {'source': sourceId});
    });
  }

  /// Cobro: congela totales, registra pagos, promociones y descuenta inventario.
  Future<void> payOrder({
    required Order order,
    required List<Payment> payments,
    required String shiftId,
    required Map<String, Product> productsById,
  }) async {
    await db.transaction((tx) async {
      final now = toIso(order.paidAt ?? DateTime.now());
      await tx.update(
        'orders',
        {
          'status': 'PAID',
          'subtotal_cents': order.subtotalCents,
          'promo_discount_cents': order.promoDiscountCents,
          'discount_bp': order.discountBp,
          'discount_cents': order.discountCents,
          'discount_reason': order.discountReason,
          'total_cents': order.totalCents,
          'paid_at': now,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );
      for (final p in payments) {
        await tx.insert('payments', {
          'id': p.id,
          'order_id': order.id,
          'shift_id': shiftId,
          'method': p.method.code,
          'amount_cents': p.amountCents,
          'received_cents': p.receivedCents,
          'change_cents': p.changeCents,
          'reference': p.reference,
          'created_at': toIso(p.createdAt),
        });
      }
      for (final a in order.appliedPromotions) {
        await tx.insert('order_promotions', {
          'id': newId(),
          'order_id': order.id,
          'promotion_id': a.promotionId,
          'promotion_name': a.name,
          'times_applied': a.timesApplied,
          'discount_cents': a.discountCents,
        });
      }
      for (final l in order.lines) {
        final product = productsById[l.productId];
        if (product == null || product.inventoryItemId == null) continue;
        await _movement(tx, product.inventoryItemId!, MovementType.sale, -(product.consumeQtyMilli * l.qty),
            orderItemId: l.id, note: order.folio);
      }
      if (order.discountBp > 0) {
        await audit(tx, 'order', order.id, 'DISCOUNT', {'bp': order.discountBp, 'reason': order.discountReason});
      }
    });
  }

  Future<void> markRoundsPrinted(List<String> roundIds, PrintStatus status) async {
    for (final id in roundIds) {
      await db.update('order_rounds', {'print_status': status.code}, where: 'id = ?', whereArgs: [id]);
    }
  }

  // ===================================================================
  // Reportes
  // ===================================================================

  /// Ventas cobradas por día operativo en el rango [from, to] (inclusive).
  Future<Map<String, int>> salesByDay(String from, String to) async {
    final rows = await db.rawQuery(
      "SELECT business_date, SUM(total_cents) AS s FROM orders WHERE status = 'PAID' "
      'AND business_date BETWEEN ? AND ? GROUP BY business_date',
      [from, to],
    );
    return {for (final r in rows) r['business_date'] as String: (r['s'] as int?) ?? 0};
  }

  Future<Map<String, int>> salesSummary(String from, String to) async {
    final o = await db.rawQuery(
      "SELECT COUNT(*) AS n, COALESCE(SUM(total_cents),0) AS s, COALESCE(SUM(promo_discount_cents + discount_cents),0) AS d, "
      "COUNT(DISTINCT business_date) AS days FROM orders WHERE status = 'PAID' AND business_date BETWEEN ? AND ?",
      [from, to],
    );
    final p = await db.rawQuery(
      'SELECT p.method AS m, COALESCE(SUM(p.amount_cents),0) AS s FROM payments p JOIN orders o ON o.id = p.order_id '
      "WHERE o.status = 'PAID' AND o.business_date BETWEEN ? AND ? GROUP BY p.method",
      [from, to],
    );
    final byMethod = {for (final r in p) r['m'] as String: (r['s'] as int?) ?? 0};
    return {
      'orders': (o.first['n'] as int?) ?? 0,
      'sales': (o.first['s'] as int?) ?? 0,
      'discounts': (o.first['d'] as int?) ?? 0,
      'days': (o.first['days'] as int?) ?? 0,
      'cash': byMethod['CASH'] ?? 0,
      'transfer': byMethod['TRANSFER'] ?? 0,
    };
  }

  Future<Map<ExpenseKind, int>> expensesByKind(String from, String to) async {
    final rows = await db.rawQuery(
      'SELECT c.kind AS k, COALESCE(SUM(e.amount_cents),0) AS s FROM expenses e '
      'JOIN expense_categories c ON c.id = e.category_id '
      'WHERE e.deleted_at IS NULL AND e.business_date BETWEEN ? AND ? GROUP BY c.kind',
      [from, to],
    );
    return {for (final r in rows) ExpenseKind.fromCode(r['k'] as String): (r['s'] as int?) ?? 0};
  }

  Future<List<DishStat>> dishStats(String from, String to) async {
    final rows = await db.rawQuery(
      'SELECT i.product_id AS id, MAX(i.product_name) AS name, SUM(i.qty) AS q, '
      'SUM((i.unit_price_cents + i.modifiers_cents) * i.qty) AS s FROM order_items i '
      "JOIN orders o ON o.id = i.order_id WHERE o.status = 'PAID' AND i.status = 'ACTIVE' "
      'AND o.business_date BETWEEN ? AND ? GROUP BY i.product_id ORDER BY q DESC, s DESC',
      [from, to],
    );
    return [
      for (final r in rows)
        DishStat(
          productId: r['id'] as String,
          name: r['name'] as String,
          qty: (r['q'] as int?) ?? 0,
          revenueCents: (r['s'] as int?) ?? 0,
        ),
    ];
  }

  /// Periodos 'YYYY-MM' con movimiento (ventas o gastos).
  Future<List<String>> periodsWithActivity() async {
    final rows = await db.rawQuery(
      "SELECT DISTINCT substr(business_date,1,7) AS p FROM orders WHERE status = 'PAID' "
      'UNION SELECT DISTINCT substr(business_date,1,7) FROM expenses WHERE deleted_at IS NULL ORDER BY p',
    );
    return rows.map((r) => r['p'] as String).toList();
  }

  MonthlyClosure _closureFrom(Map<String, Object?> r) {
    final detail = jsonDecode(r['detail_json'] as String) as Map<String, dynamic>;
    return MonthlyClosure(
      id: r['id'] as String,
      period: r['period'] as String,
      salesCents: r['sales_cents'] as int,
      ordersCount: r['orders_count'] as int,
      discountsCents: r['discounts_cents'] as int,
      cashSalesCents: r['cash_sales_cents'] as int,
      transferSalesCents: r['transfer_sales_cents'] as int,
      suppliesExpenseCents: r['supplies_expense_cents'] as int,
      operatingExpenseCents: r['operating_expense_cents'] as int,
      unforeseenExpenseCents: r['unforeseen_expense_cents'] as int,
      netCents: r['net_cents'] as int,
      salesDays: (detail['sales_days'] as int?) ?? 0,
      topProducts: [
        for (final t in (detail['top_products'] as List? ?? const []))
          DishStat(
            productId: t['id'] as String,
            name: t['name'] as String,
            qty: t['qty'] as int,
            revenueCents: t['revenue'] as int,
          ),
      ],
      dailySales: {
        for (final e in ((detail['daily_sales'] as Map?) ?? const {}).entries) e.key as String: e.value as int,
      },
      closedAt: fromIso(r['closed_at'] as String),
    );
  }

  Future<List<MonthlyClosure>> loadClosures() async {
    final rows = await db.query('monthly_closures', orderBy: 'period DESC');
    return rows.map(_closureFrom).toList();
  }

  /// Genera la foto inmutable de un mes (R11). No hace nada si ya existe.
  Future<MonthlyClosure?> closeMonth(String period) async {
    final exists = await db.query('monthly_closures', where: 'period = ?', whereArgs: [period]);
    if (exists.isNotEmpty) return _closureFrom(exists.first);
    final from = '$period-01';
    final to = '$period-31';
    final summary = await salesSummary(from, to);
    final expenses = await expensesByKind(from, to);
    final dishes = await dishStats(from, to);
    final daily = await salesByDay(from, to);
    final supplies = expenses[ExpenseKind.supplies] ?? 0;
    final operating = expenses[ExpenseKind.operating] ?? 0;
    final unforeseen = expenses[ExpenseKind.unforeseen] ?? 0;
    final net = summary['sales']! - supplies - operating - unforeseen;
    final row = {
      'id': newId(),
      'period': period,
      'sales_cents': summary['sales'],
      'orders_count': summary['orders'],
      'discounts_cents': summary['discounts'],
      'cash_sales_cents': summary['cash'],
      'transfer_sales_cents': summary['transfer'],
      'supplies_expense_cents': supplies,
      'operating_expense_cents': operating,
      'unforeseen_expense_cents': unforeseen,
      'net_cents': net,
      'detail_json': jsonEncode({
        'sales_days': summary['days'],
        'top_products': [
          for (final d in dishes.take(15)) {'id': d.productId, 'name': d.name, 'qty': d.qty, 'revenue': d.revenueCents},
        ],
        'daily_sales': daily,
      }),
      'closed_at': isoNow(),
    };
    await db.insert('monthly_closures', row);
    return _closureFrom(row);
  }

  /// Pedidos cobrados de un periodo para exportar a CSV.
  Future<List<Map<String, Object?>>> paidOrdersForExport(String period) => db.rawQuery(
        'SELECT o.business_date, o.folio, o.customer_name, o.channel, o.dining_option, o.subtotal_cents, '
        'o.promo_discount_cents, o.discount_cents, o.discount_reason, o.total_cents, o.paid_at, '
        "(SELECT GROUP_CONCAT(method || ':' || amount_cents, ' ') FROM payments p WHERE p.order_id = o.id) AS pagos "
        "FROM orders o WHERE o.status = 'PAID' AND substr(o.business_date,1,7) = ? ORDER BY o.business_date, o.folio",
        [period],
      );
}
