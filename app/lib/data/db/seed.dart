import 'package:sqflite/sqflite.dart';

import '../../core/dates.dart';

/// Datos base que se crean una sola vez con la base vacía: estructura de categorías y
/// configuración. No incluye productos, pedidos ni montos (se capturan en la app).
Future<void> seedBaseData(Database db) async {
  final now = isoNow();
  final batch = db.batch();

  const menu = [
    ('tacos', 'Tacos', 'fuego'),
    ('tortas', 'Tortas', 'torta'),
    ('antojitos', 'Antojitos', 'cubiertos'),
    ('bebidas', 'Bebidas', 'bebida'),
    ('abarrotes', 'Abarrotes', 'caja'),
  ];
  for (var i = 0; i < menu.length; i++) {
    final (id, name, icon) = menu[i];
    batch.insert('categories', {
      'id': id, 'name': name, 'icon': icon, 'kind': 'menu', 'sort_order': i,
      'active': 1, 'created_at': now, 'updated_at': now,
    });
  }

  const inventory = [
    ('inv-bebidas', 'Bebidas', 'bebida'),
    ('inv-carnes', 'Carnes', 'carne'),
    ('inv-pan', 'Pan y tortilla', 'torta'),
    ('inv-abarrotes', 'Abarrotes', 'canasta'),
  ];
  for (var i = 0; i < inventory.length; i++) {
    final (id, name, icon) = inventory[i];
    batch.insert('categories', {
      'id': id, 'name': name, 'icon': icon, 'kind': 'inventario', 'sort_order': i,
      'active': 1, 'created_at': now, 'updated_at': now,
    });
  }

  const expenseCategories = [
    ('exp-carnes', 'Carnes', 'SUPPLIES'),
    ('exp-refrescos', 'Refrescos', 'SUPPLIES'),
    ('exp-verdura', 'Verdura y tortilla', 'SUPPLIES'),
    ('exp-abarrotes', 'Abarrotes', 'SUPPLIES'),
    ('exp-gas', 'Gas', 'OPERATING'),
    ('exp-servicios', 'Luz, agua e internet', 'OPERATING'),
    ('exp-renta', 'Renta', 'OPERATING'),
    ('exp-mantenimiento', 'Mantenimiento', 'OPERATING'),
    ('exp-imprevistos', 'Imprevistos', 'UNFORESEEN'),
  ];
  for (final (id, name, kind) in expenseCategories) {
    batch.insert('expense_categories', {
      'id': id, 'name': name, 'kind': kind, 'waste_bp': 0, 'active': 1,
      'created_at': now, 'updated_at': now,
    });
  }

  batch.insert('settings', {'key': 'business_name', 'value': 'El Piolín'});
  await batch.commit(noResult: true);
}
