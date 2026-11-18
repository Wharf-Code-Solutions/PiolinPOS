import 'package:flutter_test/flutter_test.dart';
import 'package:piolinpos/core/ids.dart';
import 'package:piolinpos/data/models.dart';
import 'package:piolinpos/data/pos_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pruebas de integración del store sobre SQLite en memoria (sqflite_common_ffi).
/// Requieren libsqlite3 en la máquina (en Linux: `sudo apt install libsqlite3-dev`).
void main() {
  late PosStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = await PosStore.open(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
  });

  tearDown(() => store.close());

  Future<Product> addProduct(String name, int cents, {String categoryId = 'tacos', String? itemId}) async {
    final p = Product(id: newId(), name: name, priceCents: cents, categoryId: categoryId, inventoryItemId: itemId);
    await store.saveProduct(p);
    return p;
  }

  test('arranca con categorías base y sin datos de operación', () {
    expect(store.menuCategories, isNotEmpty);
    expect(store.activeExpenseCategories, isNotEmpty);
    expect(store.products, isEmpty);
    expect(store.orders, isEmpty);
    expect(store.hasOpenShift, isFalse);
  });

  test('no se pueden tomar pedidos sin turno', () async {
    final taco = await addProduct('Taco pastor', 1800);
    store.addToCart(taco);
    await expectLater(
      store.submitOrder(destination: OrderDestination.local, channel: OrderChannel.local),
      throwsA(isA<PosException>()),
    );
  });

  test('pedido, ronda nueva, promoción 2×1, cobro mixto e inventario', () async {
    await store.openNewShift(50000);
    final item = InventoryItem(id: newId(), name: 'Refresco 600 ml', categoryId: 'inv-bebidas', unit: InventoryUnit.pza);
    await store.saveInventoryItem(item, initialStockMilli: 24000);
    final taco = await addProduct('Taco pastor', 1800);
    final refresco = await addProduct('Refresco', 2000, categoryId: 'bebidas', itemId: item.id);
    await store.savePromotion(Promotion(
      id: newId(),
      name: '2×1 refrescos',
      type: PromotionType.buyXGetY,
      buyQty: 1,
      freeQty: 1,
      products: {refresco.id: 1},
    ));

    store
      ..addToCart(taco)
      ..addToCart(taco)
      ..setCustomerName('Carlos');
    final order = await store.submitOrder(destination: OrderDestination.local, channel: OrderChannel.whatsapp);
    expect(order.folio, 'A-001');
    expect(order.rounds.single.printStatus, PrintStatus.pendiente);

    // R1: segunda ronda en la misma cuenta.
    store
      ..startAddingTo(order)
      ..addToCart(refresco)
      ..addToCart(refresco);
    await store.submitOrder(destination: OrderDestination.local, channel: OrderChannel.local);
    expect(order.rounds.length, 2);
    expect(order.subtotalCents, 7600);

    final q = store.quote(order, discountBp: 1000);
    expect(q.promoDiscountCents, 2000);
    expect(q.totalCents, 5000);

    await store.payOrder(
      order,
      discountBp: 1000,
      discountReason: 'Cliente frecuente',
      payments: [
        Payment(id: newId(), method: PaymentMethod.transferencia, amountCents: 2000, createdAt: DateTime.now()),
        Payment(
          id: newId(),
          method: PaymentMethod.efectivo,
          amountCents: 3000,
          receivedCents: 5000,
          changeCents: 2000,
          createdAt: DateTime.now(),
        ),
      ],
    );
    expect(order.status, OrderStatus.cobrada);
    expect(order.totalCents, 5000);
    expect(store.inventoryItemById(item.id)!.stockMilli, 22000);

    final summary = store.shiftSummary!;
    expect(summary.cashSalesCents, 3000);
    expect(summary.transferSalesCents, 2000);
    expect(summary.expectedCashCents, 53000);

    // Persistencia: al recargar desde SQLite el pedido sigue cobrado.
    final reloaded = await store.repo.loadOrders('id = ?', [order.id]);
    expect(reloaded.single.status, OrderStatus.cobrada);
    expect(reloaded.single.payments.length, 2);
    expect(reloaded.single.appliedPromotions.single.discountCents, 2000);
  });

  test('descuento sin motivo se rechaza', () async {
    await store.openNewShift(0);
    final taco = await addProduct('Taco', 1800);
    store.addToCart(taco);
    final order = await store.submitOrder(destination: OrderDestination.llevar, channel: OrderChannel.local);
    await expectLater(
      store.payOrder(order, discountBp: 500, payments: const []),
      throwsA(isA<PosException>()),
    );
  });

  test('juntar y cancelar cuentas', () async {
    await store.openNewShift(0);
    final taco = await addProduct('Taco', 1800);
    store.addToCart(taco);
    final a = await store.submitOrder(destination: OrderDestination.local, channel: OrderChannel.local);
    store.addToCart(taco);
    store.addToCart(taco);
    final b = await store.submitOrder(destination: OrderDestination.local, channel: OrderChannel.local);
    expect(b.folio, 'A-002');

    await store.mergeOrders(target: a, source: b);
    expect(a.itemCount, 3);
    expect(b.status, OrderStatus.fusionada);
    expect(store.openOrders.length, 1);

    await store.cancelOrder(a, 'Cliente se retiró');
    expect(store.openOrders, isEmpty);
    final reloaded = await store.repo.loadOrders('id = ?', [a.id]);
    expect(reloaded.single.status, OrderStatus.cancelada);
  });

  test('gasto de caja y corte', () async {
    await store.openNewShift(20000);
    final cat = store.activeExpenseCategories.first;
    await store.recordExpense(categoryId: cat.id, amountCents: 5000, method: PaymentMethod.efectivo, paidFromRegister: true);
    await store.addCashMovement(CashMovementType.salida, 10000, 'Depósito al banco');
    expect(store.shiftSummary!.expectedCashCents, 5000);
    final closed = await store.closeCurrentShift(countedCashCents: 4500);
    expect(closed.differenceCents, -500);
    expect(store.hasOpenShift, isFalse);
  });

  test('conteo físico ajusta la diferencia', () async {
    final item = InventoryItem(id: newId(), name: 'Pastor', categoryId: 'inv-carnes', unit: InventoryUnit.kg, toleranceBp: 500);
    await store.saveInventoryItem(item, initialStockMilli: 10000);
    await store.applyStockCount({store.inventoryItemById(item.id)!: 9600});
    expect(store.inventoryItemById(item.id)!.stockMilli, 9600);
  });
}
