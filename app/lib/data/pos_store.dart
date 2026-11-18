import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/ids.dart';
import '../domain/pricing.dart';
import '../domain/shift_cash.dart';
import 'db/app_database.dart';
import 'db/pos_repository.dart';
import 'models.dart';

part 'store/store_orders.dart';
part 'store/store_catalog.dart';
part 'store/store_inventory.dart';
part 'store/store_shift.dart';
part 'store/store_reports.dart';

/// Estado de la app respaldado por SQLite.
///
/// Mantiene en memoria el catálogo, el inventario y el turno abierto (lo que la UI
/// lee de forma síncrona) y escribe cada cambio en la base antes de notificar.
/// Los reportes históricos se consultan bajo demanda ([loadReports]).
class PosStore extends ChangeNotifier {
  PosStore._(this._db) : repo = PosRepository(_db);

  Database _db;
  PosRepository repo;

  static Future<PosStore> open({DatabaseFactory? factory, String? path}) async {
    final db = await openAppDatabase(factory: factory, path: path);
    final store = PosStore._(db);
    await store._loadAll();
    return store;
  }

  /// Copia consistente del archivo de la base (para respaldo).
  Future<File> exportDatabaseCopy() async {
    await _db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final tmp = await getTemporaryDirectory();
    return File(_db.path).copy(p.join(tmp.path, 'piolinpos_copia.db'));
  }

  /// Cierra la base, deja que [replace] sustituya el archivo y la vuelve a abrir.
  Future<void> replaceDatabase(Future<void> Function(String path) replace) async {
    final path = _db.path;
    await _db.close();
    try {
      await replace(path);
    } finally {
      _db = await openAppDatabase(path: path);
      repo = PosRepository(_db);
      _cart.clear();
      customerName = '';
      cartTargetOrderId = null;
      reports = null;
      await _loadAll();
    }
  }

  Future<void> close() => _db.close();

  // ---------------- Estado en memoria ----------------
  Map<String, String> settings = {};
  List<MenuCategory> categories = [];
  List<Product> products = [];
  List<ModifierGroup> modifierGroups = [];
  List<Promotion> promotions = [];
  List<Supplier> suppliers = [];
  List<InventoryItem> inventory = [];
  List<ExpenseCategory> expenseCategories = [];

  Shift? openShift;

  /// Pedidos del turno abierto y cuentas abiertas de cualquier turno.
  List<Order> orders = [];
  List<Expense> shiftExpenses = [];
  List<CashMovement> shiftMovements = [];

  int priceChangesToday = 0;
  ReportData? reports;
  bool loadingReports = false;

  // ---------------- Carrito ----------------
  final Map<String, CartLine> _cart = {};
  String customerName = '';

  /// Si no es null, el carrito se agrega como ronda nueva a esta cuenta (R1).
  String? cartTargetOrderId;

  /// Aumenta con cada cambio; útil para recargar consultas dependientes.
  int revision = 0;

  void _changed() {
    revision++;
    notifyListeners();
  }

  Future<void> _loadAll() async {
    settings = await repo.loadSettings();
    categories = await repo.loadCategories();
    products = await repo.loadProducts();
    modifierGroups = await repo.loadModifierGroups();
    promotions = await repo.loadPromotions();
    suppliers = await repo.loadSuppliers();
    inventory = await repo.loadInventoryItems();
    expenseCategories = await repo.loadExpenseCategories();
    final now = DateTime.now();
    priceChangesToday = await repo.countPriceChangesSince(DateTime(now.year, now.month, now.day));
    await _loadShiftState();
    _changed();
  }

  Future<void> _loadShiftState() async {
    openShift = await repo.loadOpenShift();
    final shift = openShift;
    if (shift == null) {
      orders = await repo.loadOrders("status = 'OPEN'", []);
      shiftExpenses = [];
      shiftMovements = [];
    } else {
      orders = await repo.loadOrders("shift_id = ? OR status = 'OPEN'", [shift.id]);
      shiftExpenses = await repo.loadExpenses(shiftId: shift.id);
      shiftMovements = await repo.loadCashMovements(shift.id);
    }
  }

  Future<void> _reloadInventory() async {
    inventory = await repo.loadInventoryItems();
  }

  // ---------------- Configuración ----------------
  String get businessName => settings['business_name'] ?? 'El Piolín';

  Future<void> setSetting(String key, String value) async {
    await repo.setSetting(key, value);
    settings[key] = value;
    _changed();
  }
}

/// Expone [PosStore] al árbol y reconstruye a los dependientes cuando cambia.
class StoreScope extends InheritedNotifier<PosStore> {
  const StoreScope({super.key, required PosStore store, required super.child}) : super(notifier: store);

  static PosStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'StoreScope no encontrado');
    return scope!.notifier!;
  }

  /// Acceso sin suscribirse (para callbacks).
  static PosStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<StoreScope>();
    return scope!.notifier!;
  }
}
