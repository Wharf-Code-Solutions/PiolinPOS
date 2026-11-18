part of '../pos_store.dart';

/// Excepción de negocio con mensaje para mostrar al usuario.
class PosException implements Exception {
  const PosException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension PosStoreOrders on PosStore {
  // ---------------- Carrito ----------------
  List<CartLine> get cartLines => _cart.values.toList();
  int get cartCount => _cart.values.fold(0, (a, l) => a + l.qty);
  int get cartSubtotalCents => _cart.values.fold(0, (a, l) => a + l.subtotalCents);
  bool get cartIsEmpty => _cart.isEmpty;

  List<CartLine> cartLinesFor(String productId) => _cart.values.where((l) => l.product.id == productId).toList();
  int cartQtyFor(String productId) => cartLinesFor(productId).fold(0, (a, l) => a + l.qty);

  Order? get cartTargetOrder => cartTargetOrderId == null ? null : orderById(cartTargetOrderId!);

  static String _lineKey(Product p, List<SelectedModifier> modifiers) {
    final ids = modifiers.map((m) => m.modifierId).toList()..sort();
    return '${p.id}|${ids.join(',')}';
  }

  void addToCart(Product p, {List<SelectedModifier> modifiers = const []}) {
    if (!p.available || !p.active) return;
    final key = _lineKey(p, modifiers);
    _cart.update(key, (l) => l..qty += 1,
        ifAbsent: () => CartLine(key: key, product: p, modifiers: List.unmodifiable(modifiers)));
    _changed();
  }

  void incrementLine(String key) {
    final line = _cart[key];
    if (line == null) return;
    line.qty += 1;
    _changed();
  }

  void decrementLine(String key) {
    final line = _cart[key];
    if (line == null) return;
    line.qty -= 1;
    if (line.qty <= 0) _cart.remove(key);
    _changed();
  }

  /// Quita una pieza de la última línea agregada de ese producto.
  void removeFromCart(Product p) {
    final lines = cartLinesFor(p.id);
    if (lines.isEmpty) return;
    decrementLine(lines.last.key);
  }

  void setCartNote(String key, String note) {
    final line = _cart[key];
    if (line == null) return;
    line.note = note.trim();
    _changed();
  }

  void setCustomerName(String name) {
    customerName = name;
    _changed();
  }

  void clearCart() {
    _cart.clear();
    customerName = '';
    cartTargetOrderId = null;
    _changed();
  }

  /// R1: el siguiente pedido se agrega a [order] como ronda nueva.
  void startAddingTo(Order order) {
    _cart.clear();
    cartTargetOrderId = order.id;
    customerName = order.customer;
    _changed();
  }

  void stopAddingTo() {
    cartTargetOrderId = null;
    customerName = '';
    _changed();
  }

  /// Guarda el carrito como cuenta nueva o como ronda de una cuenta abierta.
  /// La ronda queda con impresión pendiente (impresora en espera).
  Future<Order> submitOrder({required OrderDestination destination, required OrderChannel channel}) async {
    final shift = openShift;
    if (shift == null) throw const PosException('Abre el turno antes de tomar pedidos');
    if (_cart.isEmpty) throw const PosException('El pedido está vacío');

    final now = DateTime.now();
    final target = cartTargetOrder;
    final round = OrderRound(
      id: newId(),
      roundNo: target == null ? 1 : (target.rounds.isEmpty ? 1 : target.rounds.last.roundNo + 1),
      createdAt: now,
    );
    final lines = [
      for (final l in _cart.values)
        OrderLine(
          id: newId(),
          roundId: round.id,
          productId: l.product.id,
          name: l.product.name,
          unitPriceCents: l.product.priceCents,
          modifiersCents: l.modifiersCents,
          qty: l.qty,
          note: l.note,
          modifiers: l.modifiers,
        ),
    ];

    final Order order;
    if (target != null && target.isOpen) {
      await repo.addRound(target.id, round, lines);
      target
        ..rounds.add(round)
        ..lines.addAll(lines);
      final name = customerName.trim();
      if (name.isNotEmpty && name != target.customer) {
        target.customer = name;
        await repo.updateOrderHeader(target);
      }
      order = target;
    } else {
      final folio = await repo.nextFolio(shift.businessDate);
      order = Order(
        id: newId(),
        shiftId: shift.id,
        businessDate: shift.businessDate,
        folioNo: folio,
        customer: customerName.trim().isEmpty ? 'Mostrador' : customerName.trim(),
        destination: destination,
        channel: channel,
        createdAt: now,
        rounds: [round],
        lines: lines,
      );
      await repo.insertOrder(order, round, lines);
      orders.insert(0, order);
    }
    _cart.clear();
    customerName = '';
    cartTargetOrderId = null;
    _changed();
    return order;
  }

  // ---------------- Cuentas ----------------
  List<Order> get openOrders => orders.where((o) => o.status == OrderStatus.abierta).toList();

  /// Cobradas en el turno abierto.
  List<Order> get paidOrders =>
      orders.where((o) => o.status == OrderStatus.cobrada && o.shiftId == openShift?.id).toList()
        ..sort((a, b) => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt));

  List<Order> get cancelledOrders =>
      orders.where((o) => o.status == OrderStatus.cancelada && o.shiftId == openShift?.id).toList();

  int get todayPaidCents => paidOrders.fold(0, (a, o) => a + o.totalCents);

  Order? orderById(String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Totales de una cuenta con las promociones vigentes y el descuento manual.
  PricingResult quote(Order order, {int discountBp = 0}) => priceOrder(
        lines: pricedLinesOf(order),
        promotions: promotions,
        at: DateTime.now(),
        discountBp: discountBp,
      );

  Future<void> updateOrderHeader(Order order, {String? customer, OrderDestination? destination, OrderChannel? channel}) async {
    if (customer != null && customer.trim().isNotEmpty) order.customer = customer.trim();
    if (destination != null) order.destination = destination;
    if (channel != null) order.channel = channel;
    await repo.updateOrderHeader(order);
    _changed();
  }

  /// Cobro (R3, R5): descuento con motivo y uno o dos pagos (mixto).
  Future<void> payOrder(
    Order order, {
    required List<Payment> payments,
    int discountBp = 0,
    String? discountReason,
  }) async {
    final shift = openShift;
    if (shift == null) throw const PosException('Abre el turno para cobrar');
    if (!order.isOpen) throw const PosException('La cuenta ya no está abierta');
    if (discountBp > 0 && (discountReason == null || discountReason.trim().isEmpty)) {
      throw const PosException('Indica el motivo del descuento');
    }
    final q = quote(order, discountBp: discountBp);
    final paid = payments.fold(0, (a, p) => a + p.amountCents);
    if (paid != q.totalCents) throw const PosException('Los pagos no cubren el total');

    order
      ..status = OrderStatus.cobrada
      ..discountBp = discountBp
      ..discountReason = discountBp > 0 ? discountReason!.trim() : null
      ..discountCents = q.discountCents
      ..promoDiscountCents = q.promoDiscountCents
      ..appliedPromotions = q.appliedPromotions
      ..totalCents = q.totalCents
      ..paidAt = DateTime.now();
    order.payments
      ..clear()
      ..addAll(payments);
    try {
      await repo.payOrder(
        order: order,
        payments: payments,
        shiftId: shift.id,
        productsById: {for (final p in products) p.id: p},
      );
    } catch (e) {
      // Revertir el estado en memoria si la base rechazó el cobro.
      await _loadShiftState();
      _changed();
      rethrow;
    }
    if (order.lines.any((l) => productById(l.productId)?.tracksInventory ?? false)) {
      await _reloadInventory();
      _autoMarkSoldOut();
    }
    _changed();
  }

  /// Productos ligados a un insumo agotado se marcan como no disponibles.
  void _autoMarkSoldOut() {
    final byId = {for (final i in inventory) i.id: i};
    for (final p in products) {
      final item = p.inventoryItemId == null ? null : byId[p.inventoryItemId];
      if (item != null && item.stockMilli < p.consumeQtyMilli && p.available) {
        p.available = false;
        repo.saveProduct(p);
      }
    }
  }

  Future<void> cancelOrder(Order order, String reason) async {
    if (!order.isOpen) throw const PosException('Solo se cancelan cuentas abiertas');
    if (reason.trim().isEmpty) throw const PosException('Indica el motivo de la cancelación');
    await repo.cancelOrder(order.id, reason.trim());
    order
      ..status = OrderStatus.cancelada
      ..cancelReason = reason.trim()
      ..cancelledAt = DateTime.now();
    if (cartTargetOrderId == order.id) cartTargetOrderId = null;
    _changed();
  }

  /// R1: junta dos cuentas abiertas de la misma persona.
  Future<void> mergeOrders({required Order target, required Order source}) async {
    if (!target.isOpen || !source.isOpen || target.id == source.id) {
      throw const PosException('Solo se pueden juntar dos cuentas abiertas distintas');
    }
    await repo.mergeOrders(targetId: target.id, sourceId: source.id);
    final base = target.rounds.isEmpty ? 0 : target.rounds.last.roundNo;
    for (var i = 0; i < source.rounds.length; i++) {
      final r = source.rounds[i];
      target.rounds.add(OrderRound(id: r.id, roundNo: base + i + 1, createdAt: r.createdAt, printStatus: r.printStatus));
    }
    target.lines.addAll(source.lines);
    source
      ..status = OrderStatus.fusionada
      ..mergedIntoId = target.id
      ..lines.clear()
      ..rounds.clear();
    _changed();
  }

  /// Quita un producto de una cuenta abierta (queda registrado con motivo).
  Future<void> voidLine(Order order, OrderLine line, String reason) async {
    if (!order.isOpen) throw const PosException('La cuenta ya no está abierta');
    if (reason.trim().isEmpty) throw const PosException('Indica el motivo');
    await repo.voidLine(order.id, line.id, reason.trim());
    order.lines.removeWhere((l) => l.id == line.id);
    _changed();
  }
}
