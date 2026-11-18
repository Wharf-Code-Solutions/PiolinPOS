part of '../pos_store.dart';

extension PosStoreCatalog on PosStore {
  List<MenuCategory> get menuCategories =>
      categories.where((c) => c.kind == CategoryKind.menu && c.active).toList();

  List<MenuCategory> get allMenuCategories => categories.where((c) => c.kind == CategoryKind.menu).toList();

  List<MenuCategory> get inventoryCategories =>
      categories.where((c) => c.kind == CategoryKind.inventario && c.active).toList();

  List<MenuCategory> get allInventoryCategories =>
      categories.where((c) => c.kind == CategoryKind.inventario).toList();

  MenuCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Product? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Product? productByBarcode(String code) {
    for (final p in products) {
      if (p.active && p.barcode == code) return p;
    }
    return null;
  }

  /// Productos activos (no dados de baja) de una categoría.
  List<Product> productsIn(String categoryId) =>
      products.where((p) => p.categoryId == categoryId && p.active).toList();

  List<Product> get activeProducts => products.where((p) => p.active).toList();

  int get unavailableCount => products.where((p) => p.active && !p.available).length;

  List<ModifierGroup> groupsFor(Product p) => [
        for (final id in p.modifierGroupIds)
          for (final g in modifierGroups)
            if (g.id == id && g.active) g,
      ];

  Future<void> saveCategory(MenuCategory c) async {
    await repo.saveCategory(c);
    if (!categories.any((e) => e.id == c.id)) categories.add(c);
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _changed();
  }

  Future<void> saveProduct(Product p) async {
    final existing = productById(p.id);
    if (p.barcode != null && p.barcode!.isNotEmpty) {
      final other = productByBarcode(p.barcode!);
      if (other != null && other.id != p.id) {
        throw PosException('El código de barras ya está asignado a ${other.name}');
      }
    }
    await repo.saveProduct(p);
    if (existing == null) products.add(p);
    _changed();
  }

  Future<void> updatePrice(Product p, int cents) async {
    if (cents <= 0 || cents == p.priceCents) return;
    final previous = p.priceCents;
    p.priceCents = cents;
    await repo.saveProduct(p, previousPriceCents: previous);
    priceChangesToday += 1;
    _changed();
  }

  Future<void> setAvailability(Product p, bool available) async {
    p.available = available;
    await repo.saveProduct(p);
    if (!available) _cart.removeWhere((_, l) => l.product.id == p.id);
    _changed();
  }

  /// Baja lógica: el producto deja de aparecer en el menú, conserva su historial.
  Future<void> deactivateProduct(Product p) async {
    p.active = false;
    await repo.saveProduct(p);
    _cart.removeWhere((_, l) => l.product.id == p.id);
    _changed();
  }

  Future<void> saveModifierGroup(ModifierGroup g) async {
    await repo.saveModifierGroup(g);
    if (!modifierGroups.any((e) => e.id == g.id)) modifierGroups.add(g);
    _changed();
  }

  Future<void> savePromotion(Promotion p) async {
    await repo.savePromotion(p);
    if (!promotions.any((e) => e.id == p.id)) promotions.add(p);
    _changed();
  }
}
