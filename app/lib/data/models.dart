import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Catálogo
// ---------------------------------------------------------------------------

/// Íconos disponibles para categorías (se guarda la clave en SQLite).
const categoryIconOptions = <String, IconData>{
  'fuego': Icons.local_fire_department,
  'bebida': Icons.local_drink,
  'cubiertos': Icons.flatware,
  'caja': Icons.inventory_2,
  'torta': Icons.lunch_dining,
  'cafe': Icons.local_cafe,
  'postre': Icons.icecream,
  'carne': Icons.kebab_dining,
  'canasta': Icons.shopping_basket,
  'estrella': Icons.star,
};

IconData categoryIcon(String key) => categoryIconOptions[key] ?? Icons.category;

enum CategoryKind { menu, inventario }

class MenuCategory {
  MenuCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    this.kind = CategoryKind.menu,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  String name;
  String iconKey;
  final CategoryKind kind;
  int sortOrder;
  bool active;

  IconData get icon => categoryIcon(iconKey);
}

/// Ícono que aparece en el teclado rápido de comandas.
enum ProductIcon {
  taco('Taco', Icons.lunch_dining),
  vaso('Vaso', Icons.local_cafe),
  botella('Botella', Icons.liquor),
  bolsa('Bolsa', Icons.shopping_bag),
  platillo('Platillo', Icons.ramen_dining);

  const ProductIcon(this.label, this.icon);

  final String label;
  final IconData icon;

  static ProductIcon fromName(String? name) =>
      ProductIcon.values.firstWhere((e) => e.name == name, orElse: () => ProductIcon.taco);
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.priceCents,
    required this.categoryId,
    this.description = '',
    this.available = true,
    this.active = true,
    this.favorite = false,
    this.barcode,
    this.icon = ProductIcon.taco,
    this.notePlaceholder = 'Nota',
    this.inventoryItemId,
    this.consumeQtyMilli = 1000,
    List<String>? modifierGroupIds,
    this.sortOrder = 0,
  }) : modifierGroupIds = modifierGroupIds ?? [];

  final String id;
  String name;
  String description;
  int priceCents;
  String categoryId;

  /// Disponible hoy (switch de "agotado").
  bool available;

  /// false = dado de baja del menú (borrado lógico).
  bool active;
  bool favorite;
  String? barcode;
  ProductIcon icon;
  String notePlaceholder;

  /// Insumo que se descuenta al cobrar (empaquetados) y cantidad por pieza vendida.
  String? inventoryItemId;
  int consumeQtyMilli;
  List<String> modifierGroupIds;
  int sortOrder;

  bool get tracksInventory => inventoryItemId != null;
}

class ModifierGroup {
  ModifierGroup({
    required this.id,
    required this.name,
    this.minSelect = 0,
    this.maxSelect = 1,
    this.active = true,
    List<Modifier>? modifiers,
  }) : modifiers = modifiers ?? [];

  final String id;
  String name;
  int minSelect;
  int maxSelect;
  bool active;
  final List<Modifier> modifiers;

  List<Modifier> get activeModifiers => modifiers.where((m) => m.active).toList();

  String get ruleLabel {
    if (minSelect == maxSelect) return 'Elige $minSelect';
    if (minSelect == 0) return 'Hasta $maxSelect (opcional)';
    return 'Elige de $minSelect a $maxSelect';
  }
}

class Modifier {
  Modifier({
    required this.id,
    required this.groupId,
    required this.name,
    this.priceDeltaCents = 0,
    this.isDefault = false,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final String groupId;
  String name;
  int priceDeltaCents;
  bool isDefault;
  int sortOrder;
  bool active;
}

/// Modificador elegido en una línea (snapshot de nombre y precio).
class SelectedModifier {
  const SelectedModifier({required this.modifierId, required this.name, required this.priceDeltaCents});

  final String modifierId;
  final String name;
  final int priceDeltaCents;
}

// ---------------------------------------------------------------------------
// Promociones (R4)
// ---------------------------------------------------------------------------

enum PromotionType {
  percentOff('PERCENT_OFF', '% de descuento'),
  fixedBundle('FIXED_PRICE_BUNDLE', 'Combo a precio fijo'),
  buyXGetY('BUY_X_GET_Y', 'Compra X y lleva Y');

  const PromotionType(this.code, this.label);

  final String code;
  final String label;

  static PromotionType fromCode(String code) => values.firstWhere((e) => e.code == code);
}

class Promotion {
  Promotion({
    required this.id,
    required this.name,
    required this.type,
    this.percentBp,
    this.bundlePriceCents,
    this.buyQty,
    this.freeQty,
    this.startsOn,
    this.endsOn,
    this.weekdaysMask = 127,
    this.startTime,
    this.endTime,
    this.active = true,
    Map<String, int>? products,
  }) : products = products ?? {};

  final String id;
  String name;
  PromotionType type;
  int? percentBp;
  int? bundlePriceCents;
  int? buyQty;
  int? freeQty;

  /// 'YYYY-MM-DD' (null = sin límite)
  String? startsOn;
  String? endsOn;

  /// bit0 = lunes … bit6 = domingo
  int weekdaysMask;

  /// 'HH:MM'
  String? startTime;
  String? endTime;
  bool active;

  /// productId → cantidad requerida (combos).
  final Map<String, int> products;
}

class AppliedPromotion {
  const AppliedPromotion({
    required this.promotionId,
    required this.name,
    required this.timesApplied,
    required this.discountCents,
  });

  final String promotionId;
  final String name;
  final int timesApplied;
  final int discountCents;
}

// ---------------------------------------------------------------------------
// Pedidos
// ---------------------------------------------------------------------------

class CartLine {
  CartLine({
    required this.key,
    required this.product,
    this.qty = 1,
    this.note = '',
    this.modifiers = const [],
  });

  /// Producto + combinación de modificadores.
  final String key;
  final Product product;
  int qty;
  String note;
  final List<SelectedModifier> modifiers;

  int get modifiersCents => modifiers.fold(0, (a, m) => a + m.priceDeltaCents);
  int get unitCents => product.priceCents + modifiersCents;
  int get subtotalCents => unitCents * qty;
  String get modifiersLabel => modifiers.map((m) => m.name).join(', ');
}

enum OrderDestination {
  local('DINE_IN', 'Comer en local', 'En salón', Icons.restaurant),
  llevar('TAKEOUT', 'Para llevar', 'Para llevar', Icons.shopping_bag);

  const OrderDestination(this.code, this.label, this.pill, this.icon);

  final String code;
  final String label;
  final String pill;
  final IconData icon;

  static OrderDestination fromCode(String code) => values.firstWhere((e) => e.code == code);
}

/// Canal por el que llegó el pedido (R6, solo etiqueta).
enum OrderChannel {
  local('LOCAL', 'En negocio', Icons.storefront),
  whatsapp('WHATSAPP', 'WhatsApp', Icons.chat);

  const OrderChannel(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;

  static OrderChannel fromCode(String code) => values.firstWhere((e) => e.code == code);
}

enum PaymentMethod {
  efectivo('CASH', 'Efectivo', Icons.payments),
  transferencia('TRANSFER', 'Transferencia', Icons.account_balance);

  const PaymentMethod(this.code, this.label, this.icon);

  final String code;
  final String label;
  final IconData icon;

  static PaymentMethod fromCode(String code) => values.firstWhere((e) => e.code == code);
}

enum OrderStatus {
  abierta('OPEN'),
  cobrada('PAID'),
  cancelada('CANCELLED'),
  fusionada('MERGED');

  const OrderStatus(this.code);

  final String code;

  static OrderStatus fromCode(String code) => values.firstWhere((e) => e.code == code);
}

enum PrintStatus {
  pendiente('PENDING'),
  impresa('PRINTED'),
  fallida('FAILED');

  const PrintStatus(this.code);

  final String code;

  static PrintStatus fromCode(String code) => values.firstWhere((e) => e.code == code);
}

class OrderRound {
  OrderRound({
    required this.id,
    required this.roundNo,
    required this.createdAt,
    this.printStatus = PrintStatus.pendiente,
  });

  final String id;
  final int roundNo;
  final DateTime createdAt;
  PrintStatus printStatus;
}

class OrderLine {
  OrderLine({
    required this.id,
    required this.roundId,
    required this.productId,
    required this.name,
    required this.unitPriceCents,
    required this.qty,
    this.modifiersCents = 0,
    this.note = '',
    this.modifiers = const [],
  });

  final String id;
  final String roundId;
  final String productId;
  final String name;
  final int unitPriceCents;
  final int modifiersCents;
  final int qty;
  final String note;
  final List<SelectedModifier> modifiers;

  int get unitCents => unitPriceCents + modifiersCents;
  int get subtotalCents => unitCents * qty;
  String get modifiersLabel => modifiers.map((m) => m.name).join(', ');
}

class Payment {
  const Payment({
    required this.id,
    required this.method,
    required this.amountCents,
    required this.createdAt,
    this.receivedCents,
    this.changeCents,
    this.reference,
  });

  final String id;
  final PaymentMethod method;

  /// Monto aplicado a la cuenta.
  final int amountCents;
  final int? receivedCents;
  final int? changeCents;
  final String? reference;
  final DateTime createdAt;
}

class Order {
  Order({
    required this.id,
    required this.shiftId,
    required this.businessDate,
    required this.folioNo,
    required this.customer,
    required this.destination,
    required this.createdAt,
    this.channel = OrderChannel.local,
    this.status = OrderStatus.abierta,
    List<OrderLine>? lines,
    List<OrderRound>? rounds,
    List<Payment>? payments,
    List<AppliedPromotion>? appliedPromotions,
    this.discountBp = 0,
    this.discountCents = 0,
    this.discountReason,
    this.promoDiscountCents = 0,
    this.totalCents = 0,
    this.paidAt,
    this.cancelledAt,
    this.cancelReason,
    this.mergedIntoId,
  })  : lines = lines ?? [],
        rounds = rounds ?? [],
        payments = payments ?? [],
        appliedPromotions = appliedPromotions ?? [];

  final String id;
  final String shiftId;
  final String businessDate;
  final int folioNo;
  String customer;
  OrderDestination destination;
  OrderChannel channel;
  final DateTime createdAt;
  OrderStatus status;
  final List<OrderLine> lines;
  final List<OrderRound> rounds;
  final List<Payment> payments;
  List<AppliedPromotion> appliedPromotions;
  int discountBp;
  int discountCents;
  String? discountReason;
  int promoDiscountCents;
  int totalCents;
  DateTime? paidAt;
  DateTime? cancelledAt;
  String? cancelReason;
  String? mergedIntoId;

  String get folio => 'A-${folioNo.toString().padLeft(3, '0')}';
  int get itemCount => lines.fold(0, (a, l) => a + l.qty);
  int get subtotalCents => lines.fold(0, (a, l) => a + l.subtotalCents);
  bool get isOpen => status == OrderStatus.abierta;
  int get totalPaidCents => status == OrderStatus.cobrada ? totalCents : 0;

  /// Método único de pago, o null si fue mixto / sin pagar.
  PaymentMethod? get paymentMethod {
    final methods = payments.map((p) => p.method).toSet();
    return methods.length == 1 ? methods.first : null;
  }

  bool get isMixedPayment => payments.map((p) => p.method).toSet().length > 1;
  int get pendingPrintRounds => rounds.where((r) => r.printStatus != PrintStatus.impresa).length;
}

// ---------------------------------------------------------------------------
// Inventario, proveedores y gastos
// ---------------------------------------------------------------------------

class Supplier {
  Supplier({required this.id, required this.name, this.phone, this.notes, this.active = true});

  final String id;
  String name;
  String? phone;
  String? notes;
  bool active;
}

enum InventoryUnit {
  pza('PZA', 'pza', 'piezas'),
  kg('KG', 'kg', 'kilos'),
  l('L', 'L', 'litros');

  const InventoryUnit(this.code, this.short, this.label);

  final String code;
  final String short;
  final String label;

  static InventoryUnit fromCode(String code) => values.firstWhere((e) => e.code == code);
}

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.unit,
    this.barcode,
    this.toleranceBp = 0,
    this.minStockMilli = 0,
    this.stockMilli = 0,
    this.lastUnitCostCents,
    this.supplierId,
    this.location = '',
    this.active = true,
  });

  final String id;
  String name;
  String categoryId;
  InventoryUnit unit;
  String? barcode;

  /// % de error aceptado en el conteo físico (R18), en puntos base.
  int toleranceBp;
  int minStockMilli;
  int stockMilli;
  int? lastUnitCostCents;
  String? supplierId;
  String location;
  bool active;

  double get quantity => stockMilli / 1000;
  double get minQuantity => minStockMilli / 1000;
  bool get isLow => minStockMilli > 0 && stockMilli <= minStockMilli;
}

enum MovementType {
  purchase('PURCHASE', 'Compra'),
  sale('SALE', 'Venta'),
  saleReversal('SALE_REVERSAL', 'Devolución'),
  adjustment('ADJUSTMENT', 'Ajuste'),
  waste('WASTE', 'Merma'),
  initial('INITIAL', 'Inicial');

  const MovementType(this.code, this.label);

  final String code;
  final String label;

  static MovementType fromCode(String code) => values.firstWhere((e) => e.code == code);
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.type,
    required this.qtyMilli,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String itemId;
  final MovementType type;
  final int qtyMilli;
  final String? note;
  final DateTime createdAt;
}

enum ExpenseKind {
  supplies('SUPPLIES', 'Insumos'),
  operating('OPERATING', 'Operativo'),
  unforeseen('UNFORESEEN', 'Imprevisto');

  const ExpenseKind(this.code, this.label);

  final String code;
  final String label;

  static ExpenseKind fromCode(String code) => values.firstWhere((e) => e.code == code);
}

class ExpenseCategory {
  ExpenseCategory({required this.id, required this.name, required this.kind, this.wasteBp = 0, this.active = true});

  final String id;
  String name;
  ExpenseKind kind;

  /// % de merma estimada para lo no inventariado (R18).
  int wasteBp;
  bool active;
}

class PurchaseLine {
  const PurchaseLine({
    required this.description,
    required this.qtyMilli,
    required this.totalCents,
    this.inventoryItemId,
  });

  final String description;
  final int qtyMilli;
  final int totalCents;
  final String? inventoryItemId;
}

class Expense {
  Expense({
    required this.id,
    required this.businessDate,
    required this.categoryId,
    required this.amountCents,
    required this.method,
    required this.createdAt,
    this.shiftId,
    this.supplierId,
    this.paidFromRegister = false,
    this.description = '',
  });

  final String id;
  final String businessDate;
  final String? shiftId;
  final String categoryId;
  final String? supplierId;
  final int amountCents;
  final PaymentMethod method;
  final bool paidFromRegister;
  final String description;
  final DateTime createdAt;
}

// ---------------------------------------------------------------------------
// Turno y caja
// ---------------------------------------------------------------------------

enum ShiftStatus { abierto, cerrado }

class Shift {
  Shift({
    required this.id,
    required this.businessDate,
    required this.openingCashCents,
    required this.openedAt,
    this.status = ShiftStatus.abierto,
    this.expectedCashCents,
    this.countedCashCents,
    this.differenceCents,
    this.notes,
    this.closedAt,
  });

  final String id;
  final String businessDate;
  final int openingCashCents;
  final DateTime openedAt;
  ShiftStatus status;
  int? expectedCashCents;
  int? countedCashCents;
  int? differenceCents;
  String? notes;
  DateTime? closedAt;

  bool get isOpen => status == ShiftStatus.abierto;
}

enum CashMovementType { entrada, salida }

class CashMovement {
  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.amountCents,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String shiftId;
  final CashMovementType type;
  final int amountCents;
  final String reason;
  final DateTime createdAt;

  int get signedCents => type == CashMovementType.entrada ? amountCents : -amountCents;
}

// ---------------------------------------------------------------------------
// Reportes
// ---------------------------------------------------------------------------

/// Unidades vendidas e ingreso de un producto en un periodo.
class DishStat {
  const DishStat({required this.productId, required this.name, required this.qty, required this.revenueCents});

  final String productId;
  final String name;
  final int qty;
  final int revenueCents;
}

class MonthlyClosure {
  const MonthlyClosure({
    required this.id,
    required this.period,
    required this.salesCents,
    required this.ordersCount,
    required this.discountsCents,
    required this.cashSalesCents,
    required this.transferSalesCents,
    required this.suppliesExpenseCents,
    required this.operatingExpenseCents,
    required this.unforeseenExpenseCents,
    required this.netCents,
    required this.salesDays,
    required this.topProducts,
    required this.dailySales,
    required this.closedAt,
  });

  final String id;

  /// 'YYYY-MM'
  final String period;
  final int salesCents;
  final int ordersCount;
  final int discountsCents;
  final int cashSalesCents;
  final int transferSalesCents;
  final int suppliesExpenseCents;
  final int operatingExpenseCents;
  final int unforeseenExpenseCents;
  final int netCents;
  final int salesDays;
  final List<DishStat> topProducts;

  /// business_date → ventas en centavos
  final Map<String, int> dailySales;
  final DateTime closedAt;

  int get totalExpensesCents => suppliesExpenseCents + operatingExpenseCents + unforeseenExpenseCents;
}
